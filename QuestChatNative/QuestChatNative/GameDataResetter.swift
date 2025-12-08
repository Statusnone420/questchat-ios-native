import Foundation

enum ResetWindow: Identifiable {
    case today
    case last7Days
    case full

    var id: String {
        switch self {
        case .today: "today"
        case .last7Days: "last7Days"
        case .full: "full"
        }
    }
}

final class GameDataResetter {
    private let healthStatsStore: HealthBarIRLStatsStore
    private let xpStore: SessionStatsStore
    private let sessionStatsStore: SessionStatsStore
    private let dailyRatingsStore: DailyHealthRatingsStore
    private let userDefaults: UserDefaults
    private let calendar = Calendar.current

    init(
        healthStatsStore: HealthBarIRLStatsStore,
        xpStore: SessionStatsStore,
        sessionStatsStore: SessionStatsStore,
        dailyHealthRatingsStore: DailyHealthRatingsStore,
        userDefaults: UserDefaults = .standard
    ) {
        self.healthStatsStore = healthStatsStore
        self.xpStore = xpStore
        self.sessionStatsStore = sessionStatsStore
        self.dailyRatingsStore = dailyHealthRatingsStore
        self.userDefaults = userDefaults
    }

    func reset(_ window: ResetWindow) {
        switch window {
        case .full:
            resetAllLocalData()
        case .today:
            resetDays([calendar.startOfDay(for: Date())])
        case .last7Days:
            resetLast7Days()
        }
    }

    // MARK: - Helpers

    private func resetLast7Days() {
        let today = calendar.startOfDay(for: Date())
        var days: [Date] = []
        for offset in 0..<7 {
            if let date = calendar.date(byAdding: .day, value: -offset, to: today) {
                days.append(calendar.startOfDay(for: date))
            }
        }
        resetDays(days)
    }

    private func resetDays(_ days: [Date]) {
        guard !days.isEmpty else { return }
        // Sessions & XP: delete from the earliest day forward
        let earliest = days.min() ?? calendar.startOfDay(for: Date())
        xpStore.deleteXPEvents(since: earliest)
        sessionStatsStore.deleteSessions(since: earliest)

        // HealthBar IRL summaries: remove specific days
        for day in days { healthStatsStore.deleteDay(day) }

        // Hydration inputs (DefaultHealthBarStorage uses yyyy-MM-dd keys)
        for day in days { removeHealthInputs(for: day) }

        // Daily ratings
        for day in days { dailyRatingsStore.delete(for: day) }

        // Quests: clear daily board/completions and per-day flags
        for day in days { clearDailyQuests(for: day) }

        // Weekly quest progress/boards for any week touched
        let weekKeys = Set(days.map { weeklyKey(for: $0) })
        for key in weekKeys { clearWeeklyQuests(forWeekKey: key) }
        
        // Daily Setup: if today is among the reset days, re-open the Daily Setup sheet
        let today = calendar.startOfDay(for: Date())
        if days.contains(where: { calendar.isDate($0, inSameDayAs: today) }) {
            sessionStatsStore.shouldShowDailySetup = true
        }
    }

    private func resetAllLocalData() {
        if let bundleID = Bundle.main.bundleIdentifier {
            userDefaults.removePersistentDomain(forName: bundleID)
            userDefaults.synchronize()
        }
    }

    // MARK: - Per-subsystem cleanup

    private func removeHealthInputs(for date: Date) {
        let key = dailyStorageKey(for: date)
        userDefaults.removeObject(forKey: key)
    }

    private func dailyStorageKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func clearDailyQuests(for date: Date) {
        let completionKey = QuestsViewModel.dateKey(for: date, calendar: calendar)
        // Completed quests
        userDefaults.removeObject(forKey: completionKey)
        // Daily active board
        userDefaults.removeObject(forKey: "daily-active-\(completionKey)")
        // Reroll/quest-chest flags and log-opened
        userDefaults.set(false, forKey: "reroll-\(completionKey)")
        userDefaults.set(false, forKey: "quest-chest-granted-\(completionKey)")
        userDefaults.set(false, forKey: "quest-chest-ready-\(completionKey)")
        userDefaults.set(false, forKey: "quests-log-opened-\(completionKey)")
    }

    private func weeklyKey(for date: Date) -> String {
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        let year = components.yearForWeekOfYear ?? 0
        let week = components.weekOfYear ?? 0
        return String(format: "weekly-quests-%04d-W%02d", year, week)
    }

    private func clearWeeklyQuests(forWeekKey currentWeekKey: String) {
        let keys: [String] = [
            "\(currentWeekKey)-active",
            "\(currentWeekKey)-completed",
            "\(currentWeekKey)-hydration-days",
            "\(currentWeekKey)-hp-checkins",
            "\(currentWeekKey)-work-timer-count",
            "\(currentWeekKey)-work-minutes",
            "\(currentWeekKey)-chores-minutes",
            "\(currentWeekKey)-selfcare-days",
            "\(currentWeekKey)-evening-resets",
            "\(currentWeekKey)-setup-days",
            "\(currentWeekKey)-weekend-timers",
            "\(currentWeekKey)-hard-quests"
        ]
        for key in keys { userDefaults.removeObject(forKey: key) }
    }
}
