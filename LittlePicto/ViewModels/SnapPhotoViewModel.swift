import Foundation
import FirebaseAuth

/// ViewModel that coordinates subscription + quota for the Snap Photo flow.
@MainActor
final class SnapPhotoViewModel: ObservableObject {
    @Published var showPaywall: Bool = false
    @Published var quotaAlertMessage: String?
    @Published var navigateToCamera: Bool = false

    private let subscriptionManager: SubscriptionManager
    private let quotaManager = QuotaManager()

    init(subscriptionManager: SubscriptionManager) {
        self.subscriptionManager = subscriptionManager
    }

    /// Called when the user taps "Snap a photo".
    ///
    /// The UI should:
    /// - Observe `navigateToCamera` to push `SnapPhotoView`.
    /// - Observe `showPaywall` to present the subscription screen.
    func snapPhoto() {
        Task {
            // Ensure there is a signed-in user.
            guard Auth.auth().currentUser != nil else {
                // Not signed in → treat as free user and show paywall.
                showPaywall = true
                return
            }

            // 1. Refresh entitlements and sync to Firestore.
            await subscriptionManager.refreshSubscriptionStatusFromStoreKitAndSync()
            let status = subscriptionManager.subscriptionStatus

            // 2. Ask quota manager whether we can proceed.
            do {
                let result = try await quotaManager.checkAndConsumeQuota(for: status)

                switch result {
                case .allowed:
                    // User has enough credits this month → go to camera.
                    quotaAlertMessage = nil
                    navigateToCamera = true

                case .mustSubscribe:
                    // Free user: no quota. Go straight to paywall.
                    quotaAlertMessage = nil
                    showPaywall = true

                case .quotaExceeded:
                    // Paid user but out of credits for this month.
                    quotaAlertMessage = "You reached your monthly limit."
                    showPaywall = true
                }
            } catch {
                // On error, be safe and send user to paywall rather than allowing free usage.
                quotaAlertMessage = "We couldn't verify your subscription. Please check your connection."
                showPaywall = true
            }
        }
    }

    /// Call this after navigating to camera so we don't keep auto-triggering navigation.
    func consumeCameraNavigation() {
        navigateToCamera = false
    }
}
