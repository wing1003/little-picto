import Foundation
import FirebaseAuth
import FirebaseFirestore

/// Result of checking & updating photo detection quota.
enum QuotaCheckResult {
    case allowed          // May proceed with detection
    case mustSubscribe    // User is free: show paywall
    case quotaExceeded    // Subscriber but out of credits this month
}

/// Handles monthly quota logic in Firestore:
/// - Reads `/users/{uid}`
/// - Resets `monthlyQuotaUsed` on new calendar month
/// - Applies per-tier limits
/// - Writes updated `monthlyQuotaUsed` and `lastQuotaReset`
actor QuotaManager {
    private let db = Firestore.firestore()
    private let calendar = Calendar.current

    /// Main entry point called after the user taps "Snap a photo".
    ///
    /// - Parameters:
    ///   - status: subscription tier from `SubscriptionManager`
    /// - Returns:
    ///   - `.allowed`        → proceed with detection
    ///   - `.mustSubscribe`  → free user (no quota)
    ///   - `.quotaExceeded`  → paid user but monthly quota exhausted
    func checkAndConsumeQuota(for status: SubscriptionStatus) async throws -> QuotaCheckResult {
        guard let user = Auth.auth().currentUser else {
            return .mustSubscribe
        }

        // Free users have no quota at all.
        guard status != .free else {
            try await ensureUserDocumentExists(for: user, status: .free)
            return .mustSubscribe
        }

        // Determine monthly allowance.
        let monthlyLimit: Int
        switch status {
        case .monthly:
            monthlyLimit = 120
        case .yearly:
            monthlyLimit = 150
        case .free:
            monthlyLimit = 0 // Already handled above
        }

        let docRef = db.collection("users").document(user.uid)
        let snapshot = try await docRef.getDocument()

        var data = snapshot.data() ?? [:]
        let now = Date()

        // Read existing fields (if any)
        let used = (data["monthlyQuotaUsed"] as? Int) ?? 0
        let lastReset = (data["lastQuotaReset"] as? Timestamp)?.dateValue()

        // Reset if new month
        let (newUsed, newLastReset) = resetIfNeeded(used: used, lastReset: lastReset, now: now)

        // Check limit
        if newUsed >= monthlyLimit {
            // Persist the reset (if any) even though we’re out of quota
            data["monthlyQuotaUsed"] = newUsed
            data["lastQuotaReset"] = Timestamp(date: newLastReset)
            data["subscriptionStatus"] = status.rawValue
            try await docRef.setData(data, merge: true)
            return .quotaExceeded
        }

        // We can consume one credit.
        data["monthlyQuotaUsed"] = newUsed + 1
        data["lastQuotaReset"] = Timestamp(date: newLastReset)
        data["subscriptionStatus"] = status.rawValue
        try await docRef.setData(data, merge: true)

        return .allowed
    }

    // MARK: - Helpers

    private func resetIfNeeded(used: Int, lastReset: Date?, now: Date) -> (Int, Date) {
        guard let lastReset else {
            // First time: start fresh this month.
            return (0, now)
        }

        let lastComponents = calendar.dateComponents([.year, .month], from: lastReset)
        let currentComponents = calendar.dateComponents([.year, .month], from: now)

        if lastComponents.year != currentComponents.year || lastComponents.month != currentComponents.month {
            // New month → reset quota.
            return (0, now)
        } else {
            // Same month → keep current count.
            return (used, lastReset)
        }
    }

    private func ensureUserDocumentExists(for user: User, status: SubscriptionStatus) async throws {
        let docRef = db.collection("users").document(user.uid)
        let snapshot = try await docRef.getDocument()
        guard snapshot.exists == false else { return }

        try await docRef.setData([
            "subscriptionStatus": status.rawValue,
            "monthlyQuotaUsed": 0,
            "lastQuotaReset": Timestamp(date: Date())
        ], merge: true)
    }
}
