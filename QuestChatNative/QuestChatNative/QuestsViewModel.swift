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
                return QuestChatStrings.QuestsPool.coreTier
            case .habit:
                return QuestChatStrings.QuestsPool.habitTier
            case .bonus:
                return QuestChatStrings.QuestsPool.bonusTier
            }
        }
    }

    let id: String
    let title: String
    let detail: String
    let xpReward: Int
    let tier: Tier
    var isCompleted: Bool
    var isCoreToday: Bool = false
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

        if let focusArea = statsStore.dailyConfig?.focusArea, !statsStore.shouldShowDailySetup {
            markCoreQuests(for: focusArea)
        }
    }

    var completedQuestsCount: Int {
        dailyQuests.filter { $0.isCompleted }.count
    }

    var totalQuestsCount: Int {
        dailyQuests.count
    }

    var totalDailyXP: Int {
        dailyQuests.reduce(0) { $0 + $1.xpReward }
    }

    var remainingQuestsUntilChest: Int {
        max(dailyQuests.filter { !$0.isCompleted }.count, 0)
    }

    var allQuestsComplete: Bool {
        dailyQuests.allSatisfy { $0.isCompleted }
    }

    var incompleteQuests: [Quest] {
        dailyQuests.filter { !$0.isCompleted }
    }

    var canRerollToday: Bool { !hasUsedRerollToday }

    func toggleQuest(_ quest: Quest) {
        guard let index = dailyQuests.firstIndex(where: { $0.id == quest.id }) else { return }

        let wasCompleted = dailyQuests[index].isCompleted
        dailyQuests[index].isCompleted.toggle()

        if dailyQuests[index].isCompleted && !wasCompleted {
            statsStore.registerQuestCompleted(id: dailyQuests[index].id, xp: dailyQuests[index].xpReward)
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

        if let focusArea = statsStore.dailyConfig?.focusArea, !statsStore.shouldShowDailySetup {
            markCoreQuests(for: focusArea)
        }
    }

    func claimQuestChest() {
        hasQuestChestReady = false
        userDefaults.set(false, forKey: questChestReadyKey)
    }

    var questChestRewardAmount: Int {
        Self.questChestBonusXP
    }

    func markCoreQuests(for focusArea: FocusArea) {
        let desiredIDs = Set(Self.coreQuestIDs[focusArea] ?? [])
        dailyQuests = dailyQuests.map { quest in
            var updated = quest
            updated.isCoreToday = desiredIDs.contains(quest.id)
            return updated
        }
    }
}

private extension QuestsViewModel {
    static let questChestBonusXP = 50

    static let questPool: [Quest] = [
        Quest(id: "daily-checkin", title: QuestChatStrings.QuestsPool.dailyCheckInTitle, detail: QuestChatStrings.QuestsPool.dailyCheckInDescription, xpReward: 25, tier: .core, isCompleted: false),
        Quest(id: "hydrate", title: QuestChatStrings.QuestsPool.hydrateTitle, detail: QuestChatStrings.QuestsPool.hydrateDescription, xpReward: 15, tier: .habit, isCompleted: false),
        Quest(id: "stretch", title: QuestChatStrings.QuestsPool.stretchTitle, detail: QuestChatStrings.QuestsPool.stretchDescription, xpReward: 15, tier: .habit, isCompleted: false),
        Quest(id: "plan", title: QuestChatStrings.QuestsPool.planTitle, detail: QuestChatStrings.QuestsPool.planDescription, xpReward: 30, tier: .core, isCompleted: false),
        Quest(id: "deep-focus", title: QuestChatStrings.QuestsPool.deepFocusTitle, detail: QuestChatStrings.QuestsPool.deepFocusDescription, xpReward: 35, tier: .bonus, isCompleted: false),
        Quest(id: "gratitude", title: QuestChatStrings.QuestsPool.gratitudeTitle, detail: QuestChatStrings.QuestsPool.gratitudeDescription, xpReward: 20, tier: .bonus, isCompleted: false)
    ]

    static let coreQuestIDs: [FocusArea: [String]] = [
        .work: ["daily-checkin", "plan", "hydrate"],
        .home: ["daily-checkin", "stretch", "hydrate"],
        .health: ["stretch", "hydrate", "plan"],
        .chill: ["daily-checkin", "stretch", "plan"]
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

        statsStore.registerQuestCompleted(id: "quest-chest", xp: Self.questChestBonusXP)
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
