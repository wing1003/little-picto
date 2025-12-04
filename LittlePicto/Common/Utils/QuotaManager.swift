import Foundation
import FirebaseAuth
import FirebaseFirestore

// MARK: - Quota Check Result

enum QuotaCheckResult: Equatable {
    case allowed(remaining: Int)  // May proceed with detection + remaining quota
    case mustSubscribe            // User is free: show paywall
    case quotaExceeded            // Subscriber but out of credits this month
    
    var canProceed: Bool {
        if case .allowed = self { return true }
        return false
    }
}

// MARK: - Quota Manager Errors

enum QuotaManagerError: LocalizedError {
    case userNotAuthenticated
    case firestoreReadFailed(Error)
    case firestoreWriteFailed(Error)
    case invalidData
    
    var errorDescription: String? {
        switch self {
        case .userNotAuthenticated:
            return "User is not authenticated"
        case .firestoreReadFailed(let error):
            return "Failed to read quota data: \(error.localizedDescription)"
        case .firestoreWriteFailed(let error):
            return "Failed to update quota data: \(error.localizedDescription)"
        case .invalidData:
            return "Invalid quota data in database"
        }
    }
}

// MARK: - User Quota Data Model

struct UserQuotaData: Codable {
    var subscriptionTier: String
    var monthlyQuotaUsed: Int
    var lastQuotaReset: Timestamp
    var createdAt: Timestamp?
    var lastUpdatedAt: Timestamp?
    
    enum CodingKeys: String, CodingKey {
        case subscriptionTier = "subscriptionStatus"
        case monthlyQuotaUsed
        case lastQuotaReset
        case createdAt
        case lastUpdatedAt
    }
}

// MARK: - Quota Manager

actor QuotaManager {
    
    // MARK: - Properties
    
    private let db = Firestore.firestore()
    private let calendar = Calendar.current
    private let collectionName = "users"
    
    // Cache to avoid unnecessary Firestore reads
    private var cachedQuotaData: [String: (data: UserQuotaData, fetchedAt: Date)] = [:]
    private let cacheValidityDuration: TimeInterval = 60 // 1 minute
    
    // MARK: - Public API
    
    /// Main entry point called before the user performs a quota-limited action.
    ///
    /// - Parameter tier: subscription tier from `SubscriptionManager`
    /// - Returns: QuotaCheckResult indicating whether the action can proceed
    /// - Throws: QuotaManagerError if authentication or Firestore operations fail
    func checkAndConsumeQuota(for tier: SubscriptionTier) async throws -> QuotaCheckResult {
        guard let user = Auth.auth().currentUser else {
            throw QuotaManagerError.userNotAuthenticated
        }
        
        // Free users have no quota at all
        if tier == .free {
            try await ensureUserDocumentExists(for: user, tier: tier)
            return .mustSubscribe
        }
        
        let monthlyLimit = tier.monthlyQuota
        let docRef = db.collection(collectionName).document(user.uid)
        
        // Fetch current quota data
        var quotaData = try await fetchQuotaData(for: user.uid, docRef: docRef)
        let now = Date()
        
        // Reset if new month
        let didReset = resetQuotaIfNeeded(&quotaData, now: now)
        
        // Check if quota exceeded
        if quotaData.monthlyQuotaUsed >= monthlyLimit {
            // Persist the reset if it occurred
            if didReset {
                quotaData.lastUpdatedAt = Timestamp(date: now)
                try await saveQuotaData(quotaData, to: docRef, userId: user.uid)
            }
            return .quotaExceeded
        }
        
        // Consume one credit
        quotaData.monthlyQuotaUsed += 1
        quotaData.subscriptionTier = tier.firestoreValue
        quotaData.lastUpdatedAt = Timestamp(date: now)
        
        try await saveQuotaData(quotaData, to: docRef, userId: user.uid)
        
        let remaining = monthlyLimit - quotaData.monthlyQuotaUsed
        return .allowed(remaining: remaining)
    }
    
    /// Get current quota status without consuming a credit
    func getCurrentQuota(for tier: SubscriptionTier) async throws -> (used: Int, limit: Int, remaining: Int) {
        guard let user = Auth.auth().currentUser else {
            throw QuotaManagerError.userNotAuthenticated
        }
        
        if tier == .free {
            return (used: 0, limit: 0, remaining: 0)
        }
        
        let docRef = db.collection(collectionName).document(user.uid)
        var quotaData = try await fetchQuotaData(for: user.uid, docRef: docRef)
        
        // Reset if needed but don't persist yet
        _ = resetQuotaIfNeeded(&quotaData, now: Date())
        
        let limit = tier.monthlyQuota
        let remaining = max(0, limit - quotaData.monthlyQuotaUsed)
        
        return (used: quotaData.monthlyQuotaUsed, limit: limit, remaining: remaining)
    }
    
    /// Manually reset quota (admin/testing purposes)
    func resetQuota() async throws {
        guard let user = Auth.auth().currentUser else {
            throw QuotaManagerError.userNotAuthenticated
        }
        
        let docRef = db.collection(collectionName).document(user.uid)
        let now = Date()
        
        let resetData: [String: Any] = [
            "monthlyQuotaUsed": 0,
            "lastQuotaReset": Timestamp(date: now),
            "lastUpdatedAt": Timestamp(date: now)
        ]
        
        do {
            try await docRef.updateData(resetData)
            invalidateCache(for: user.uid)
        } catch {
            throw QuotaManagerError.firestoreWriteFailed(error)
        }
    }
    
    // MARK: - Private Helpers
    
    private func fetchQuotaData(for userId: String, docRef: DocumentReference) async throws -> UserQuotaData {
        // Check cache first
        if let cached = cachedQuotaData[userId],
           Date().timeIntervalSince(cached.fetchedAt) < cacheValidityDuration {
            return cached.data
        }
        
        // Fetch from Firestore
        do {
            let snapshot = try await docRef.getDocument()
            
            guard snapshot.exists else {
                // Document doesn't exist, create default
                let newData = UserQuotaData(
                    subscriptionTier: SubscriptionTier.free.firestoreValue,
                    monthlyQuotaUsed: 0,
                    lastQuotaReset: Timestamp(date: Date()),
                    createdAt: Timestamp(date: Date()),
                    lastUpdatedAt: Timestamp(date: Date())
                )
                return newData
            }
            
            guard let data = snapshot.data() else {
                throw QuotaManagerError.invalidData
            }
            
            let quotaData = try parseQuotaData(from: data)
            
            // Cache the result
            cachedQuotaData[userId] = (quotaData, Date())
            
            return quotaData
            
        } catch let error as QuotaManagerError {
            throw error
        } catch {
            throw QuotaManagerError.firestoreReadFailed(error)
        }
    }
    
    private func parseQuotaData(from data: [String: Any]) throws -> UserQuotaData {
        let tier = (data["subscriptionStatus"] as? String) ?? SubscriptionTier.free.firestoreValue
        let used = (data["monthlyQuotaUsed"] as? Int) ?? 0
        let lastReset = (data["lastQuotaReset"] as? Timestamp) ?? Timestamp(date: Date())
        let createdAt = data["createdAt"] as? Timestamp
        let lastUpdatedAt = data["lastUpdatedAt"] as? Timestamp
        
        return UserQuotaData(
            subscriptionTier: tier,
            monthlyQuotaUsed: used,
            lastQuotaReset: lastReset,
            createdAt: createdAt,
            lastUpdatedAt: lastUpdatedAt
        )
    }
    
    private func saveQuotaData(_ data: UserQuotaData, to docRef: DocumentReference, userId: String) async throws {
        do {
            let dict: [String: Any] = [
                "subscriptionStatus": data.subscriptionTier,
                "monthlyQuotaUsed": data.monthlyQuotaUsed,
                "lastQuotaReset": data.lastQuotaReset,
                "lastUpdatedAt": data.lastUpdatedAt ?? Timestamp(date: Date()),
                "createdAt": data.createdAt ?? Timestamp(date: Date())
            ]
            
            try await docRef.setData(dict, merge: true)
            
            // Update cache
            cachedQuotaData[userId] = (data, Date())
            
        } catch {
            throw QuotaManagerError.firestoreWriteFailed(error)
        }
    }
    
    @discardableResult
    private func resetQuotaIfNeeded(_ data: inout UserQuotaData, now: Date) -> Bool {
        let lastReset = data.lastQuotaReset.dateValue()
        
        let lastComponents = calendar.dateComponents([.year, .month], from: lastReset)
        let currentComponents = calendar.dateComponents([.year, .month], from: now)
        
        let isDifferentMonth = lastComponents.year != currentComponents.year ||
                               lastComponents.month != currentComponents.month
        
        if isDifferentMonth {
            data.monthlyQuotaUsed = 0
            data.lastQuotaReset = Timestamp(date: now)
            return true
        }
        
        return false
    }
    
    private func ensureUserDocumentExists(for user: User, tier: SubscriptionTier) async throws {
        let docRef = db.collection(collectionName).document(user.uid)
        
        do {
            let snapshot = try await docRef.getDocument()
            
            guard !snapshot.exists else { return }
            
            let now = Date()
            let initialData: [String: Any] = [
                "subscriptionStatus": tier.firestoreValue,
                "monthlyQuotaUsed": 0,
                "lastQuotaReset": Timestamp(date: now),
                "createdAt": Timestamp(date: now),
                "lastUpdatedAt": Timestamp(date: now)
            ]
            
            try await docRef.setData(initialData, merge: true)
            
        } catch {
            throw QuotaManagerError.firestoreWriteFailed(error)
        }
    }
    
    private func invalidateCache(for userId: String) {
        cachedQuotaData.removeValue(forKey: userId)
    }
    
    /// Clear all cached quota data
    func clearCache() {
        cachedQuotaData.removeAll()
    }
}

// MARK: - SubscriptionTier Extension

extension SubscriptionTier {
    var firestoreValue: String {
        switch self {
        case .free: return "free"
        case .monthly: return "monthly"
        case .yearly: return "yearly"
        }
    }
    
    init(firestoreValue: String) {
        switch firestoreValue.lowercased() {
        case "monthly": self = .monthly
        case "yearly": self = .yearly
        default: self = .free
        }
    }
}
