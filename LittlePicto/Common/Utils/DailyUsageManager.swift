import Foundation

final class DailyUsageManager {
    static let shared = DailyUsageManager()
    
    enum ResetMode {
        case perDay
        case perMinutes(Int)
    }
    
    // 修改这个变量可以切换重置策略（如 .perDay 或 .perMinutes(5)）
//    var resetMode: ResetMode = .perMinutes(5)
    var resetMode: ResetMode = .perDay
    
    private let lastUsageDateKey = "com.pausehere.lastUsageDate"
    private let dailyUsageCountKey = "com.pausehere.dailyUsageCount"
    private let maxDailyUsage = 1
    
    private init() {}

    func canUseToday() -> Bool {
        let now = Date()
        
        if let lastUsageDate = UserDefaults.standard.object(forKey: lastUsageDateKey) as? Date {
            let shouldReset: Bool
            
            switch resetMode {
            case .perDay:
                let calendar = Calendar.current
                let today = calendar.startOfDay(for: now)
                let lastDay = calendar.startOfDay(for: lastUsageDate)
                shouldReset = !calendar.isDate(today, inSameDayAs: lastDay)
                
            case .perMinutes(let minutes):
                let interval = now.timeIntervalSince(lastUsageDate)
                shouldReset = interval >= Double(minutes * 60)
            }
            
            if shouldReset {
                resetDailyUsage()
                return true
            } else {
                let usageCount = UserDefaults.standard.integer(forKey: dailyUsageCountKey)
                return usageCount < maxDailyUsage
            }
        } else {
            // First time usage
            resetDailyUsage()
            return true
        }
    }
    
    func incrementUsage() {
        let currentCount = UserDefaults.standard.integer(forKey: dailyUsageCountKey)
        UserDefaults.standard.set(currentCount + 1, forKey: dailyUsageCountKey)
        UserDefaults.standard.set(Date(), forKey: lastUsageDateKey)
    }
    
    func resetDailyUsage() {
        UserDefaults.standard.set(0, forKey: dailyUsageCountKey)
        UserDefaults.standard.set(Date(), forKey: lastUsageDateKey)
    }
    
    func getRemainingUsage() -> Int {
        _ = canUseToday() // ensure state is up to date
        let usageCount = UserDefaults.standard.integer(forKey: dailyUsageCountKey)
        return max(0, maxDailyUsage - usageCount)
    }
}
