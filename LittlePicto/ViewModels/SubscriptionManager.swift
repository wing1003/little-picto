import Foundation
import StoreKit
import FirebaseAuth
import FirebaseFirestore

/// Central place for handling in‑app subscriptions using StoreKit 2 and syncing state to Firestore.
///
/// Responsibilities:
/// - Load available subscription products from the App Store.
/// - Purchase and restore subscriptions.
/// - Determine premium entitlement using `Transaction.currentEntitlements`.
/// - Mirror the current entitlement into Firestore at `users/{uid}/subscriptionStatus`.
///
/// This class is designed to be created once at app launch and injected as an `@EnvironmentObject`.
@MainActor
final class SubscriptionManager: ObservableObject {
    /// All available subscription products fetched from the App Store.
    @Published private(set) var products: [Product] = []

    /// Flag indicating whether the current user has any active premium subscription entitlement.
    @Published private(set) var isPremium: Bool = false

    /// Optional human‑readable error to surface in the UI (e.g. on the paywall).
    @Published var errorMessage: String?

    /// Product identifiers configured in App Store Connect.
    private let productIDs: Set<String> = [
        "premium_monthly",
        "premium_yearly"
    ]

    private let db = Firestore.firestore()

    init() {
        // On creation, we:
        // 1. Load products from the App Store.
        // 2. Refresh entitlements and reconcile with Firestore.
        Task {
            await loadProducts()
            await refreshEntitlementsAndSync()
        }
    }

    // MARK: - Public API

    /// Loads products from the App Store using StoreKit 2.
    func loadProducts() async {
        do {
            let storeProducts = try await Product.products(for: Array(productIDs))
            // Sort into a stable order (e.g. monthly before yearly).
            products = storeProducts.sorted { $0.id < $1.id }
        } catch {
            errorMessage = "Unable to load subscription products: \(error.localizedDescription)"
        }
    }

    /// Starts a purchase flow for the provided product.
    ///
    /// - Important:
    /// This method:
    /// - Calls `product.purchase()`.
    /// - Verifies the resulting transaction.
    /// - Updates `isPremium` based on `Transaction.currentEntitlements`.
    /// - Writes `"premium"` to Firestore for the signed‑in user.
    ///
    /// If you later add a secure backend, this is where you would forward the
    /// transaction to your server for App Store receipt validation **before**
    /// unlocking features locally.
    func purchase(_ product: Product) async {
        errorMessage = nil

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verificationResult):
                // Verify the transaction using StoreKit's built‑in cryptographic verification.
                guard case .verified(let transaction) = verificationResult else {
                    errorMessage = "Unable to verify purchase."
                    return
                }

                // Here is a good place to forward `transaction` to a server for
                // additional validation before granting access, if you add one later.

                // Finish the transaction to indicate that your app has successfully
                // delivered the content to the user.
                await transaction.finish()

                // After a successful purchase, re‑calculate entitlements and sync.
                await refreshEntitlementsAndSync()

            case .pending:
                // The user has started the purchase flow but not yet completed.
                break

            case .userCancelled:
                // User cancelled; no action needed.
                break

            @unknown default:
                break
            }
        } catch {
            errorMessage = "Purchase failed: \(error.localizedDescription)"
        }
    }

    /// Restores purchases for the current App Store account.
    ///
    /// Call this when the user taps "Restore Purchases" on the paywall.
    func restorePurchases() async {
        errorMessage = nil

        do {
            // Restoring is done implicitly via `Transaction.currentEntitlements` in StoreKit 2.
            // We simply re‑evaluate current entitlements and sync them to Firestore.
            await refreshEntitlementsAndSync()
        } catch {
            errorMessage = "Restore failed: \(error.localizedDescription)"
        }
    }

    /// Forces a refresh of StoreKit entitlements and reconciles them with Firestore.
    ///
    /// Call this on app launch (we already do this in `init`), or whenever the auth user
    /// changes and you want to re‑sync subscription state.
    func refreshEntitlementsAndSync() async {
        // 1. Check StoreKit entitlements on device.
        let hasLocalPremium = await hasActivePremiumEntitlement()

        // 2. Read the server copy from Firestore.
        let firestoreStatus = await fetchSubscriptionStatusFromFirestore()
        let firestorePremium = firestoreStatus == "premium"

        // 3. Reconcile:
        //    - If StoreKit says premium, we trust it and overwrite Firestore.
        //    - If StoreKit has no premium and Firestore says premium, we downgrade to free.
        let finalIsPremium: Bool
        if hasLocalPremium {
            finalIsPremium = true
            await syncSubscriptionStatusToFirestore(isPremium: true)
        } else {
            finalIsPremium = false
            await syncSubscriptionStatusToFirestore(isPremium: false)
        }

        isPremium = finalIsPremium
    }

    // MARK: - StoreKit Entitlements

    /// Returns true if `Transaction.currentEntitlements` contains any active premium subscription.
    ///
    /// StoreKit 2 exposes the user's current entitlements as an async sequence.
    /// We iterate through it and check for any verified, non‑revoked transactions
    /// matching our known premium product IDs.
    private func hasActivePremiumEntitlement() async -> Bool {
        var hasPremium = false

        for await entitlement in Transaction.currentEntitlements {
            guard case .verified(let transaction) = entitlement else {
                continue // Ignore unverified transactions.
            }

            guard productIDs.contains(transaction.productID) else {
                continue
            }

            // Transaction is for one of our subscription products and is currently active.
            if transaction.revocationDate == nil && !transaction.isUpgraded {
                hasPremium = true
            }
        }

        return hasPremium
    }

    // MARK: - Firestore Sync

    /// Writes the subscription status to Firestore for the current user.
    ///
    /// Path: `users/{uid}/subscriptionStatus = "premium" | "free"`.
    ///
    /// - Note:
    /// If no user is signed in yet, this method does nothing; `isPremium` is still tracked
    /// locally via StoreKit so that UI can react immediately once auth completes.
    private func syncSubscriptionStatusToFirestore(isPremium: Bool) async {
        guard let user = Auth.auth().currentUser else {
            return
        }

        let status = isPremium ? "premium" : "free"

        do {
            try await db.collection("users")
                .document(user.uid)
                .setData(["subscriptionStatus": status], merge: true)
        } catch {
            // In production you might want to log this to your telemetry system.
            errorMessage = "Failed to sync subscription status: \(error.localizedDescription)"
        }
    }

    /// Reads the subscription status from Firestore for the current user, if present.
    ///
    /// This allows us to:
    /// - Reflect server‑side changes (e.g. upgrades or refunds handled by backend).
    /// - Show the last known state quickly on launch, before StoreKit finishes checking.
    private func fetchSubscriptionStatusFromFirestore() async -> String {
        guard let user = Auth.auth().currentUser else {
            return "free"
        }

        do {
            let snapshot = try await db.collection("users")
                .document(user.uid)
                .getDocument()

            if let data = snapshot.data(),
               let status = data["subscriptionStatus"] as? String {
                return status
            }
        } catch {
            // Swallow Firestore errors here and fall back to "free" —
            // StoreKit remains the source of truth for actual entitlements.
            errorMessage = "Failed to read subscription status: \(error.localizedDescription)"
        }

        return "free"
    }
}


