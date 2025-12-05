import Foundation
import FirebaseAuth
import Combine

// MARK: - Alert Configuration

struct QuotaAlert: Identifiable {
    enum PrimaryAction {
        case showPaywall
        case retrySnapPhoto
        case requireSignIn
        case none
    }
    
    let id = UUID()
    let title: String
    let message: String
    let primaryButton: String
    let secondaryButton: String?
    let primaryAction: PrimaryAction
    
    init(
        title: String,
        message: String,
        primaryButton: String,
        secondaryButton: String? = nil,
        primaryAction: PrimaryAction = .none
    ) {
        self.title = title
        self.message = message
        self.primaryButton = primaryButton
        self.secondaryButton = secondaryButton
        self.primaryAction = primaryAction
    }
    
    static func quotaExceeded(tier: SubscriptionTier) -> QuotaAlert {
        let tierName = tier == .monthly ? "Monthly" : "Yearly"
        return QuotaAlert(
            title: "Monthly Limit Reached",
            message: "You've used all \(tier.monthlyQuota) detections for this month with your \(tierName) plan. Your quota will reset next month.",
            primaryButton: "OK",
            secondaryButton: "Upgrade Plan",
            primaryAction: .showPaywall
        )
    }
    
    static func mustSubscribe(remaining: Int? = nil) -> QuotaAlert {
        QuotaAlert(
            title: "Subscription Required",
            message: "Subscribe to unlock unlimited photo detections and premium features.",
            primaryButton: "Subscribe Now",
            secondaryButton: "Cancel",
            primaryAction: .showPaywall
        )
    }
    
    static func connectionError() -> QuotaAlert {
        QuotaAlert(
            title: "Connection Error",
            message: "We couldn't verify your subscription. Please check your internet connection and try again.",
            primaryButton: "Retry",
            secondaryButton: "Cancel",
            primaryAction: .retrySnapPhoto
        )
    }
    
    static func authenticationRequired() -> QuotaAlert {
        QuotaAlert(
            title: "Sign In Required",
            message: "Please sign in to use photo detection features.",
            primaryButton: "Sign In",
            secondaryButton: "Cancel",
            primaryAction: .requireSignIn
        )
    }
}

// MARK: - View State

enum SnapPhotoViewState: Equatable {
    case idle
    case checking
    case readyToSnap
    case error(String)
}

// MARK: - SnapPhotoViewModel

@MainActor
final class SnapPhotoViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var viewState: SnapPhotoViewState = .idle
    @Published var showPaywall: Bool = false
    @Published var navigateToCamera: Bool = false
    @Published var currentAlert: QuotaAlert?
    @Published var quotaInfo: QuotaInfo?
    
    // MARK: - Private Properties
    
    private let subscriptionManager: SubscriptionManager
    private let quotaManager = QuotaManager()
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init(subscriptionManager: SubscriptionManager = .shared) {
        self.subscriptionManager = subscriptionManager
        observeSubscriptionChanges()
    }
    
    // MARK: - Public API
    
    /// Called when the user taps "Snap a photo".
    func snapPhoto() {
        Task {
            await handleSnapPhotoRequest()
        }
    }
    
    /// Call after navigating to camera to reset navigation state
    func didNavigateToCamera() {
        navigateToCamera = false
    }
    
    /// Call after dismissing paywall
    func didDismissPaywall() {
        showPaywall = false
    }
    
    /// Refresh quota information for display
    func refreshQuotaInfo() {
        Task {
            await updateQuotaInfo()
        }
    }
    
    /// Handle alert button actions
    func handleAlertAction(_ alert: QuotaAlert, isPrimary: Bool) {
        currentAlert = nil
        
        guard isPrimary else { return }
        
        switch alert.primaryAction {
        case .showPaywall:
            // Present paywall after the alert dismisses to avoid presentation conflicts.
            DispatchQueue.main.async { [weak self] in
                self?.showPaywall = true
            }
            
        case .retrySnapPhoto:
            snapPhoto()
            
        case .requireSignIn:
            handleSignInRequired()
            
        case .none:
            break
        }
    }
    
    // MARK: - Private Methods
    
    private func handleSnapPhotoRequest() async {
        // Validate authentication
        guard let user = Auth.auth().currentUser else {
            currentAlert = .authenticationRequired()
            return
        }
        
        viewState = .checking
        
        do {
            // 1. Update subscription status from StoreKit
            await subscriptionManager.updatePremiumStatus()
            let tier = subscriptionManager.currentSubscriptionTier
            
            // 2. Check and consume quota
            let result = try await quotaManager.checkQuotaStatus(for: tier)
            
            // 3. Handle result
            await handleQuotaResult(result, tier: tier)
            
        } catch let error as QuotaManagerError {
            handleQuotaError(error)
        } catch {
            handleUnexpectedError(error)
        }
    }
    
    private func handleQuotaResult(_ result: QuotaCheckResult, tier: SubscriptionTier) async {
        switch result {
        case .allowed(let remaining):
            // Success - proceed to camera
            quotaInfo = QuotaInfo(
                tier: tier,
                used: tier.monthlyQuota - remaining,
                remaining: remaining,
                limit: tier.monthlyQuota
            )
            viewState = .readyToSnap
            navigateToCamera = true
            
        case .mustSubscribe:
            // Free user - show paywall
            currentAlert = .mustSubscribe()
            viewState = .idle
            
        case .quotaExceeded:
            // Paid user but quota exceeded
            await updateQuotaInfo()
            currentAlert = .quotaExceeded(tier: tier)
            viewState = .idle
        }
    }
    
    private func handleQuotaError(_ error: QuotaManagerError) {
        switch error {
        case .userNotAuthenticated:
            currentAlert = .authenticationRequired()
            
        case .firestoreReadFailed, .firestoreWriteFailed:
            currentAlert = .connectionError()
            
        case .invalidData:
            currentAlert = QuotaAlert(
                title: "Data Error",
                message: "There was an issue with your account data. Please contact support.",
                primaryButton: "OK",
                secondaryButton: nil
            )
        }
        
        viewState = .error(error.localizedDescription ?? "Unknown error")
    }
    
    private func handleUnexpectedError(_ error: Error) {
        currentAlert = .connectionError()
        viewState = .error(error.localizedDescription)
    }
    
    private func updateQuotaInfo() async {
        let tier = subscriptionManager.currentSubscriptionTier
        
        guard tier != .free else {
            quotaInfo = nil
            return
        }
        
        do {
            let (used, limit, remaining) = try await quotaManager.getCurrentQuota(for: tier)
            quotaInfo = QuotaInfo(
                tier: tier,
                used: used,
                remaining: remaining,
                limit: limit
            )
        } catch {
            print("Failed to fetch quota info: \(error.localizedDescription)")
        }
    }
    
    private func observeSubscriptionChanges() {
        // Observe subscription status changes
        subscriptionManager.$isPremium
            .dropFirst()
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    await self?.updateQuotaInfo()
                }
            }
            .store(in: &cancellables)
        
        subscriptionManager.$currentSubscriptionTier
            .dropFirst()
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    await self?.updateQuotaInfo()
                }
            }
            .store(in: &cancellables)
    }
    
    private func handleSignInRequired() {
        // Implement your sign-in flow here
        // This could trigger a notification, navigation, or delegate call
        // depending on your app's architecture
        NotificationCenter.default.post(name: .userNeedsToSignIn, object: nil)
    }
}

// MARK: - Supporting Types

struct QuotaInfo {
    let tier: SubscriptionTier
    let used: Int
    let remaining: Int
    let limit: Int
    
    var percentageUsed: Double {
        guard limit > 0 else { return 0 }
        return Double(used) / Double(limit)
    }
    
    var displayText: String {
        "\(remaining) of \(limit) detections remaining this month"
    }
    
    var isNearLimit: Bool {
        percentageUsed >= 0.8
    }
    
    var isAtLimit: Bool {
        remaining == 0
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let userNeedsToSignIn = Notification.Name("userNeedsToSignIn")
}

// MARK: - Preview Helper

#if DEBUG
extension SnapPhotoViewModel {
    static var preview: SnapPhotoViewModel {
        SnapPhotoViewModel(subscriptionManager: .shared)
    }
    
    static var previewWithQuota: SnapPhotoViewModel {
        let vm = SnapPhotoViewModel(subscriptionManager: .shared)
        vm.quotaInfo = QuotaInfo(
            tier: .monthly,
            used: 85,
            remaining: 35,
            limit: 120
        )
        return vm
    }
}
#endif
