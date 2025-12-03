import Foundation
import StoreKit
import FirebaseAuth
import FirebaseFirestore

/// User subscription tiers mirrored in Firestore.
enum SubscriptionStatus: String, Codable {
    case free
    case monthly
    case yearly
}

/// Main manager for loading StoreKit products, purchasing, restoring,
/// checking entitlements, and syncing subscription status to Firestore.
///
/// This is the **final merged version** combining your two versions.
@MainActor
final class SubscriptionManager: ObservableObject {
    
    // MARK: - Published Properties
    
    /// Products fetched from App Store Connect.
    @Published private(set) var products: [Product] = []

    /// Current tier derived from StoreKit entitlements.
    @Published private(set) var subscriptionStatus: SubscriptionStatus = .free

    /// Error surfaced to UI.
    @Published var errorMessage: String?

    // MARK: - Product IDs

    private let monthlyID = "com.varink.littlepicto.premium_monthly"
    private let yearlyID  = "com.varink.littlepicto.premium_yearly"
    private var productIDs: [String] { [monthlyID, yearlyID] }

    private let db = Firestore.firestore()

    // MARK: - Init

    init() {
        Task {
            await loadProducts()
            await refreshSubscriptionStatusFromStoreKitAndSync()
        }
    }

    // MARK: - Convenience

    var isPremium: Bool {
        switch subscriptionStatus {
        case .free:        return false
        case .monthly,
             .yearly:     return true
        }
    }

    // MARK: - Load Products

    func loadProducts() async {
        do {
            let storeProducts = try await Product.products(for: productIDs)
            products = storeProducts.sorted { $0.id < $1.id }
            print("Loaded products:", products.map { $0.id })
        } catch {
            errorMessage = "Failed to load products: \(error.localizedDescription)"
        }
    }

    // MARK: - Purchase

    func purchase(_ product: Product) async {
        errorMessage = nil
        
        do {
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                guard case .verified(let transaction) = verification else {
                    errorMessage = "Transaction could not be verified."
                    return
                }

                await transaction.finish()
                await refreshSubscriptionStatusFromStoreKitAndSync()

            case .pending:
                break
            case .userCancelled:
                break
            @unknown default:
                break
            }
        } catch {
            errorMessage = "Purchase failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Restore Purchases

    func restorePurchases() async {
        await refreshSubscriptionStatusFromStoreKitAndSync()
    }

    // MARK: - Determine Subscription Status (StoreKit)

    private func determineSubscriptionStatusFromEntitlements() async -> SubscriptionStatus {
        var hasMonthly = false
        var hasYearly  = false

        for await entitlement in Transaction.currentEntitlements {
            guard case .verified(let transaction) = entitlement else { continue }

            // Ignore expired
            if let exp = transaction.expirationDate, exp < Date() {
                continue
            }

            switch transaction.productID {
            case monthlyID: hasMonthly = true
            case yearlyID:  hasYearly  = true
            default: break
            }
        }

        if hasYearly { return .yearly }
        if hasMonthly { return .monthly }
        return .free
    }

    // MARK: - Main: Sync

    /// Refresh StoreKit entitlements and sync result → Firestore.
    func refreshSubscriptionStatusFromStoreKitAndSync() async {
        guard let user = Auth.auth().currentUser else {
            subscriptionStatus = .free
            return
        }

        // 1) Determine tier from StoreKit
        let tier = await determineSubscriptionStatusFromEntitlements()
        subscriptionStatus = tier

        // 2) Sync to Firestore
        do {
            try await db.collection("users")
                .document(user.uid)
                .setData(["subscriptionStatus": tier.rawValue], merge: true)
        } catch {
            errorMessage = "Failed to sync with Firestore: \(error.localizedDescription)"
        }
    }

    // MARK: - Read from Firestore (Optional)

    func loadSubscriptionStatusFromFirestoreIfAvailable() async {
        guard let user = Auth.auth().currentUser else {
            subscriptionStatus = .free
            return
        }

        do {
            let snap = try await db.collection("users")
                .document(user.uid)
                .getDocument()

            guard let raw = snap.data()?["subscriptionStatus"] as? String,
                  let status = SubscriptionStatus(rawValue: raw) else { return }

            subscriptionStatus = status

        } catch {
            errorMessage = "Failed to load Firestore subscription: \(error.localizedDescription)"
        }
    }
}
