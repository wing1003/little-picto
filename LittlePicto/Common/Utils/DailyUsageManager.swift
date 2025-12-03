import Foundation

enum UsagePeriod {
    case perDay
    case perWeek   // NEW: limit counted by calendar week
    case unlimited
}

struct DailyUsageManager {
    private let calendar = Calendar.current
    private let maxWeeklyUses = 3
    private let maxDailyUses = 1

    private let period: UsagePeriod
    private var lastResetDate: Date?
    private var currentCount: Int = 0

    mutating func canUseNow() -> Bool {
        let now = Date()

        switch period {
        case .perDay:
            resetIfNewDay(now: now)
            return currentCount < maxDailyUses   // whatever you use today

        case .perWeek:
            resetIfNewWeek(now: now)
            return currentCount < maxWeeklyUses  // 3 uses per week

        case .unlimited:
            return true
        }
    }

    mutating func recordUse() {
        let now = Date()

        switch period {
        case .perDay:
            resetIfNewDay(now: now)
        case .perWeek:
            resetIfNewWeek(now: now)
        case .unlimited:
            break
        }

        currentCount += 1
    }

    // MARK: - Helpers

    private mutating func resetIfNewDay(now: Date) {
        guard let last = lastResetDate else {
            lastResetDate = now
            currentCount = 0
            return
        }
        if !calendar.isDate(now, inSameDayAs: last) {
            lastResetDate = now
            currentCount = 0
        }
    }

    private mutating func resetIfNewWeek(now: Date) {
        guard let last = lastResetDate else {
            lastResetDate = now
            currentCount = 0
            return
        }

        let lastWeek = calendar.component(.weekOfYear, from: last)
        let lastYear = calendar.component(.yearForWeekOfYear, from: last)
        let currentWeek = calendar.component(.weekOfYear, from: now)
        let currentYear = calendar.component(.yearForWeekOfYear, from: now)

        if lastWeek != currentWeek || lastYear != currentYear {
            // New calendar week: reset usage
            lastResetDate = now
            currentCount = 0
        }
    }
}
