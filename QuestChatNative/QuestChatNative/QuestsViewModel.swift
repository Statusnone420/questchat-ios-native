import Foundation
import Combine

struct Quest: Identifiable, Equatable {
    let id: String
    let title: String
    let detail: String
    let xpReward: Int
    var isCompleted: Bool
}

final class QuestsViewModel: ObservableObject {
    @Published var dailyQuests: [Quest] = []

    private let statsStore: SessionStatsStore
    private let userDefaults: UserDefaults
    private let calendar: Calendar

    private var completionKey: String {
        Self.dateKey(for: Date(), calendar: calendar)
    }

    init(
        statsStore: SessionStatsStore = SessionStatsStore(),
        userDefaults: UserDefaults = .standard,
        calendar: Calendar = .current
    ) {
        self.statsStore = statsStore
        self.userDefaults = userDefaults
        self.calendar = calendar
        dailyQuests = Self.seedQuests(with: completedQuestIDs(for: Date(), calendar: calendar, userDefaults: userDefaults))
    }

    func toggleQuest(_ quest: Quest) {
        guard let index = dailyQuests.firstIndex(where: { $0.id == quest.id }) else { return }

        let wasCompleted = dailyQuests[index].isCompleted
        dailyQuests[index].isCompleted.toggle()

        if dailyQuests[index].isCompleted && !wasCompleted {
            statsStore.grantBonusXP(dailyQuests[index].xpReward)
        }

        persistCompletions()
    }
}

private extension QuestsViewModel {
    static func seedQuests(with completedIDs: Set<String>) -> [Quest] {
        var quests = [
            Quest(id: "daily-checkin", title: "Daily check-in", detail: "Set your intention and mood for the day.", xpReward: 20, isCompleted: false),
            Quest(id: "hydrate", title: "Hydrate", detail: "Drink a full glass of water before starting.", xpReward: 15, isCompleted: false),
            Quest(id: "stretch", title: "Stretch break", detail: "Do a quick 2-minute stretch to reset.", xpReward: 15, isCompleted: false),
            Quest(id: "plan", title: "Plan a focus block", detail: "Schedule at least one focused session today.", xpReward: 25, isCompleted: false)
        ]

        quests = quests.map { quest in
            var updated = quest
            updated.isCompleted = completedIDs.contains(quest.id)
            return updated
        }

        return quests
    }

    func completedQuestIDs(for date: Date, calendar: Calendar, userDefaults: UserDefaults) -> Set<String> {
        let key = Self.dateKey(for: date, calendar: calendar)
        return Set(userDefaults.stringArray(forKey: key) ?? [])
    }

    func persistCompletions() {
        let completed = dailyQuests.filter { $0.isCompleted }.map { $0.id }
        userDefaults.set(completed, forKey: completionKey)
    }

    static func dateKey(for date: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let year = components.year ?? 0
        let month = components.month ?? 0
        let day = components.day ?? 0
        return String(format: "quests-%04d-%02d-%02d", year, month, day)
    }
}
