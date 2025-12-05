import Foundation
import StoreKit
import SwiftUI

// MARK: - Product Configuration
enum SubscriptionProductID: String, CaseIterable {
    case monthlyPremium = "com.varink.littlepicto.premium_monthly"
    case yearlyPremium = "com.varink.littlepicto.premium_yearly"
    
    var displayName: String {
        switch self {
        case .monthlyPremium: return "Monthly Premium"
        case .yearlyPremium: return "Yearly Premium"
        }
    }
    
    var mockPrice: String {
        switch self {
        case .monthlyPremium: return "$4.99"
        case .yearlyPremium: return "$19.99"
        }
    }
}

// MARK: - Subscription Tier Configuration
enum SubscriptionTier {
    case free
    case monthly
    case yearly
    
    var monthlyQuota: Int {
        switch self {
        case .free: return 0
        case .monthly: return 120
        case .yearly: return 150
        }
    }
}

// MARK: - Mock Product Model
struct ProductModel: Identifiable {
    let id: String
    let displayName: String
    let description: String
    let price: String
    let subscriptionPeriod: String
}

// MARK: - Custom Errors
enum SubscriptionError: LocalizedError {
    case productsNotFound
    case loadingFailed(Error)
    case purchaseFailed(Error)
    case restoreFailed(Error)
    case verificationFailed
    
    var errorDescription: String? {
        switch self {
        case .productsNotFound:
            return "No products available"
        case .loadingFailed(let error):
            return "Unable to load products: \(error.localizedDescription)"
        case .purchaseFailed(let error):
            return "Purchase failed: \(error.localizedDescription)"
        case .restoreFailed(let error):
            return "Restore failed: \(error.localizedDescription)"
        case .verificationFailed:
            return "Transaction verification failed"
        }
    }
}

// MARK: - Subscription Manager
@MainActor
class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()
    
    // MARK: - Published Properties
    @Published private(set) var products: [Product] = []
    @Published private(set) var mockProducts: [ProductModel] = []
    @Published private(set) var isPremium = false
    @Published private(set) var currentSubscriptionTier: SubscriptionTier = .free
    @Published var errorMessage: String?
    
    // MARK: - Usage Tracking
    @AppStorage("monthlyUsageCount") private var monthlyUsageCount: Int = 0
    @AppStorage("currentUsageMonth") private var currentUsageMonth: Int = 0
    @AppStorage("lastSubscriptionCheck") private var lastSubscriptionCheck: TimeInterval = 0
    
    // MARK: - Private Properties
    private var entitlementUpdateTask: Task<Void, Never>?
    private let productIDs = SubscriptionProductID.allCases.map(\.rawValue)
    
    private init() {}
    
    deinit {
        entitlementUpdateTask?.cancel()
    }
    
    // MARK: - Public API
    
    /// Initialize the subscription manager - call once at app launch
    func initialize() async {
        await loadProducts()
        startListeningForEntitlementUpdates()
        await updatePremiumStatus()
    }
    
    /// Check if user can perform an action based on their quota
    func canPerformAction() -> Bool {
        return remainingQuota() > 0
    }
    
    /// Get the current subscription tier
    func currentTier() -> SubscriptionTier {
        return currentSubscriptionTier
    }
    
    // MARK: - Product Loading
    
    func loadProducts() async {
        do {
            let storeProducts = try await Product.products(for: productIDs)
            print("storeProducts: \(storeProducts)")
            
            guard !storeProducts.isEmpty else {
                loadMockProducts()
                return
            }
            
            // Sort products: monthly first, then yearly
            products = storeProducts.sorted { p1, p2 in
                guard let period1 = p1.subscription?.subscriptionPeriod.unit,
                      let period2 = p2.subscription?.subscriptionPeriod.unit else {
                    return false
                }
                return period1 == .month && period2 == .year
            }
            
        } catch {
            loadMockProducts()
            errorMessage = SubscriptionError.loadingFailed(error).errorDescription
        }
    }
    
    private func loadMockProducts() {
        mockProducts = SubscriptionProductID.allCases.map { productID in
            ProductModel(
                id: productID.rawValue,
                displayName: productID.displayName,
                description: productID == .monthlyPremium ? "Unlock all features" : "Save 30% with annual plan",
                price: productID.mockPrice,
                subscriptionPeriod: productID == .monthlyPremium ? "1 month" : "1 year"
            )
        }
    }
    
    // MARK: - Purchase Flow
    
    func purchase(_ product: Product) async -> Bool {
        do {
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                guard let transaction = checkVerified(verification) else {
                    return false
                }
                
                await updatePremiumStatus()
                await transaction.finish()
                return true
                
            case .userCancelled:
                return false
                
            case .pending:
                errorMessage = "Purchase is pending approval"
                return false
                
            @unknown default:
                return false
            }
            
        } catch {
            errorMessage = SubscriptionError.purchaseFailed(error).errorDescription
            return false
        }
    }
    
    func restorePurchases() async -> Bool {
        do {
            try await AppStore.sync()
            await updatePremiumStatus()
            
            if isPremium {
                errorMessage = nil
                return true
            } else {
                errorMessage = "No active subscriptions found"
                return false
            }
            
        } catch {
            errorMessage = SubscriptionError.restoreFailed(error).errorDescription
            return false
        }
    }
    
    // MARK: - Entitlement Management
    
    func updatePremiumStatus() async {
        let status = await fetchCurrentEntitlementStatus()
        isPremium = status?.state == .subscribed
        currentSubscriptionTier = await fetchSubscriptionTier()
        lastSubscriptionCheck = Date().timeIntervalSince1970
    }
    
    private func startListeningForEntitlementUpdates() {
        entitlementUpdateTask?.cancel()
        
        entitlementUpdateTask = Task { [weak self] in
            guard let self = self else { return }
            
            for await status in AppStore.entitlementUpdates {
                guard !Task.isCancelled else { break }
                await self.handleEntitlementUpdate(status)
            }
        }
    }
    
    private func handleEntitlementUpdate(_ status: Product.SubscriptionInfo.Status) async {
        isPremium = status.state == .subscribed
        currentSubscriptionTier = await fetchSubscriptionTier()
        lastSubscriptionCheck = Date().timeIntervalSince1970
    }
    
    private func fetchCurrentEntitlementStatus() async -> Product.SubscriptionInfo.Status? {
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productType == .autoRenewable,
               let status = await transaction.subscriptionStatus {
                return status
            }
        }
        return nil
    }
    
    private func fetchActiveProductID() async -> String? {
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productType == .autoRenewable {
                return transaction.productID
            }
        }
        return nil
    }
    
    // MARK: - Usage Tracking
    
    func recordSnapUsage() {
        resetUsageIfNewMonth()
        monthlyUsageCount += 1
    }
    
    func remainingQuota() -> Int {
        resetUsageIfNewMonth()
        let tier = currentTier()
        return max(0, tier.monthlyQuota - monthlyUsageCount)
    }
    
    func usageProgress() -> Double {
        let tier = currentTier()
        guard tier.monthlyQuota > 0 else { return 1.0 }
        return Double(monthlyUsageCount) / Double(tier.monthlyQuota)
    }
    
    private func resetUsageIfNewMonth() {
        let currentMonth = Calendar.current.component(.month, from: Date())
        
        if currentMonth != currentUsageMonth {
            currentUsageMonth = currentMonth
            monthlyUsageCount = 0
        }
    }
    
    private func determineSubscriptionTier() -> SubscriptionTier {
        // Need to fetch this asynchronously, so we'll use a different approach
        // This method should be called from an async context
        return .free
    }
    
    // Better approach: async version
    func fetchSubscriptionTier() async -> SubscriptionTier {
        guard isPremium else { return .free }
        
        // Check active subscription product ID
        if let productID = await fetchActiveProductID() {
            if productID.contains("monthly") {
                return .monthly
            } else if productID.contains("yearly") {
                return .yearly
            }
        }
        
        return .free
    }
    
    // MARK: - Helper Methods
    
    private func checkVerified<T>(_ result: VerificationResult<T>) -> T? {
        switch result {
        case .unverified:
            errorMessage = SubscriptionError.verificationFailed.errorDescription
            return nil
        case .verified(let safe):
            return safe
        }
    }
}

// MARK: - AppStore Extensions

extension AppStore {
    static var entitlementUpdates: AsyncStream<Product.SubscriptionInfo.Status> {
        AsyncStream { continuation in
            let task = Task.detached {
                for await result in Transaction.updates {
                    guard !Task.isCancelled else {
                        continuation.finish()
                        return
                    }
                    
                    if case .verified(let transaction) = result,
                       transaction.productType == .autoRenewable,
                       let status = await transaction.subscriptionStatus {
                        continuation.yield(status)
                    }
                }
            }
            
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
}
