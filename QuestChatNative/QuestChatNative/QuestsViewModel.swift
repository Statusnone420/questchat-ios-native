import Foundation
import Combine

struct Quest: Identifiable, Equatable {
    enum Tier: String, CaseIterable {
        case core
        case habit
        case bonus

        var displayName: String {
            switch self {
            case .core:
                return "Core"
            case .habit:
                return "Habit"
            case .bonus:
                return "Bonus"
            }
        }
    }

    let id: String
    let title: String
    let detail: String
    let xpReward: Int
    let tier: Tier
    var isCompleted: Bool
}

final class QuestsViewModel: ObservableObject {
    @Published var dailyQuests: [Quest] = []
    @Published private(set) var hasUsedRerollToday: Bool = false
    @Published var hasQuestChestReady: Bool = false

    private let statsStore: SessionStatsStore
    private let userDefaults: UserDefaults
    private let calendar: Calendar
    private let dayReference: Date

    private var completionKey: String {
        Self.dateKey(for: dayReference, calendar: calendar)
    }

    private var rerollKey: String {
        "reroll-\(completionKey)"
    }

    private var questChestGrantedKey: String {
        "quest-chest-granted-\(completionKey)"
    }

    private var questChestReadyKey: String {
        "quest-chest-ready-\(completionKey)"
    }

    init(
        statsStore: SessionStatsStore = SessionStatsStore(),
        userDefaults: UserDefaults = .standard,
        calendar: Calendar = .current
    ) {
        self.statsStore = statsStore
        self.userDefaults = userDefaults
        self.calendar = calendar
        dayReference = calendar.startOfDay(for: Date())
        dailyQuests = Self.seedQuests(with: completedQuestIDs(for: dayReference, calendar: calendar, userDefaults: userDefaults))
        hasUsedRerollToday = userDefaults.bool(forKey: rerollKey)
        hasQuestChestReady = userDefaults.bool(forKey: questChestReadyKey)
        checkQuestChestRewardIfNeeded()
    }

    var completedQuestsCount: Int {
        dailyQuests.filter { $0.isCompleted }.count
    }

    var totalQuestsCount: Int {
        dailyQuests.count
    }

    func toggleQuest(_ quest: Quest) {
        guard let index = dailyQuests.firstIndex(where: { $0.id == quest.id }) else { return }

        let wasCompleted = dailyQuests[index].isCompleted
        dailyQuests[index].isCompleted.toggle()

        if dailyQuests[index].isCompleted && !wasCompleted {
            statsStore.grantBonusXP(dailyQuests[index].xpReward)
        }

        persistCompletions()
        checkQuestChestRewardIfNeeded()
    }

    func reroll(quest: Quest) {
        guard !hasUsedRerollToday else { return }
        guard !quest.isCompleted else { return }
        guard let index = dailyQuests.firstIndex(where: { $0.id == quest.id }) else { return }

        let currentIDs = Set(dailyQuests.map { $0.id })
        let availableReplacementQuests = Self.questPool.filter { candidate in
            candidate.id != quest.id && !currentIDs.contains(candidate.id)
        }

        guard let newQuest = availableReplacementQuests.randomElement() else { return }

        dailyQuests[index] = Quest(
            id: newQuest.id,
            title: newQuest.title,
            detail: newQuest.detail,
            xpReward: newQuest.xpReward,
            tier: newQuest.tier,
            isCompleted: false
        )

        hasUsedRerollToday = true
        userDefaults.set(true, forKey: rerollKey)
        persistCompletions()
    }

    func claimQuestChest() {
        hasQuestChestReady = false
        userDefaults.set(false, forKey: questChestReadyKey)
    }

    var questChestRewardAmount: Int {
        Self.questChestBonusXP
    }
}

private extension QuestsViewModel {
    static let questChestBonusXP = 50

    static let questPool: [Quest] = [
        Quest(id: "daily-checkin", title: "Daily check-in", detail: "Set your intention and mood for the day.", xpReward: 25, tier: .core, isCompleted: false),
        Quest(id: "hydrate", title: "Hydrate", detail: "Drink a full glass of water before starting.", xpReward: 15, tier: .habit, isCompleted: false),
        Quest(id: "stretch", title: "Stretch break", detail: "Do a quick 2-minute stretch to reset.", xpReward: 15, tier: .habit, isCompleted: false),
        Quest(id: "plan", title: "Plan a focus block", detail: "Schedule at least one focused session today.", xpReward: 30, tier: .core, isCompleted: false),
        Quest(id: "deep-focus", title: "Deep focus", detail: "Commit to 25 distraction-free minutes.", xpReward: 35, tier: .bonus, isCompleted: false),
        Quest(id: "gratitude", title: "Gratitude note", detail: "Write down one thing you're grateful for.", xpReward: 20, tier: .bonus, isCompleted: false)
    ]

    static func seedQuests(with completedIDs: Set<String>) -> [Quest] {
        var quests = Array(questPool.prefix(4))

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

    func checkQuestChestRewardIfNeeded() {
        guard !userDefaults.bool(forKey: questChestGrantedKey) else { return }
        guard dailyQuests.allSatisfy({ $0.isCompleted }) else { return }

        statsStore.grantBonusXP(Self.questChestBonusXP)
        userDefaults.set(true, forKey: questChestGrantedKey)
        hasQuestChestReady = true
        userDefaults.set(true, forKey: questChestReadyKey)
    }

    static func dateKey(for date: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let year = components.year ?? 0
        let month = components.month ?? 0
        let day = components.day ?? 0
        return String(format: "quests-%04d-%02d-%02d", year, month, day)
    }
}
