import Foundation

enum ResetWindow: Identifiable {
    case last5Minutes
    case lastHour
    case lastDay
    case lastWeek
    case full

    var id: String {
        switch self {
        case .last5Minutes: "last5Minutes"
        case .lastHour: "lastHour"
        case .lastDay: "lastDay"
        case .lastWeek: "lastWeek"
        case .full: "full"
        }
    }
}

final class GameDataResetter {
    private let healthStatsStore: HealthBarIRLStatsStore
    private let xpStore: SessionStatsStore
    private let sessionStatsStore: SessionStatsStore

    init(
        healthStatsStore: HealthBarIRLStatsStore,
        xpStore: SessionStatsStore,
        sessionStatsStore: SessionStatsStore
    ) {
        self.healthStatsStore = healthStatsStore
        self.xpStore = xpStore
        self.sessionStatsStore = sessionStatsStore
    }

    func reset(_ window: ResetWindow) {
        switch window {
        case .full:
            resetAllLocalData()
        case .last5Minutes, .lastHour, .lastDay, .lastWeek:
            resetSince(cutoffDate(for: window))
        }
    }

    private func cutoffDate(for window: ResetWindow) -> Date {
        let now = Date()
        switch window {
        case .last5Minutes:
            return now.addingTimeInterval(-5 * 60)
        case .lastHour:
            return now.addingTimeInterval(-60 * 60)
        case .lastDay:
            return now.addingTimeInterval(-24 * 60 * 60)
        case .lastWeek:
            return now.addingTimeInterval(-7 * 24 * 60 * 60)
        case .full:
            return now
        }
    }

    private func resetSince(_ date: Date) {
        xpStore.deleteXPEvents(since: date)
        sessionStatsStore.deleteSessions(since: date)
        healthStatsStore.deleteSnapshots(since: date)
    }

    private func resetAllLocalData() {
        if let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
            UserDefaults.standard.synchronize()
        }
    }
}
