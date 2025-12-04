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
        statsStore: SessionStatsStore = SessionStatsStore(playerStateStore: DependencyContainer.shared.playerStateStore),
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
        guard !Self.nonRerollableQuestIDs.contains(quest.id) else { return }
        guard let index = dailyQuests.firstIndex(where: { $0.id == quest.id }) else { return }

        let currentIDs = Set(dailyQuests.map { $0.id })
        let completedToday = completedQuestIDs(for: dayReference, calendar: calendar, userDefaults: userDefaults)
        let availableReplacementQuests = Self.questPool.filter { candidate in
            candidate.id != quest.id &&
                !currentIDs.contains(candidate.id) &&
                !completedToday.contains(candidate.id) &&
                !Self.nonRerollableQuestIDs.contains(candidate.id)
        }

        guard let newQuest = availableReplacementQuests.randomElement() else { return }

        dailyQuests[index] = Quest(
            id: newQuest.id,
            title: newQuest.title,
            detail: newQuest.detail,
            xpReward: newQuest.xpReward,
            tier: newQuest.tier,
            isCompleted: false,
            isCoreToday: false
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

    static let desiredDailyQuestCount = 5

    static let questPool: [Quest] = [
        Quest(id: "daily-checkin", title: "Load today’s quest log", detail: "Open the quest log and decide what actually matters.", xpReward: 10, tier: .core, isCompleted: false),
        Quest(id: "plan-focus-session", title: "Plan one focus session", detail: "Pick a timer and commit to at least one run today.", xpReward: 35, tier: .core, isCompleted: false),
        Quest(id: "healthbar-checkin", title: "HealthBar check-in", detail: "Update your mood, gut, and sleep before you go heads-down.", xpReward: 35, tier: .core, isCompleted: false),
        Quest(id: "finish-focus-session", title: "Finish one focus session", detail: "Complete any focus timer, even a short one.", xpReward: 35, tier: .habit, isCompleted: false),
        Quest(id: "focus-25-min", title: "Hit 25 focus minutes today", detail: "Accumulate at least 25 minutes of focus time.", xpReward: 60, tier: .bonus, isCompleted: false),
        Quest(id: "hydrate-checkpoint", title: "Hydrate checkpoint", detail: "Drink a real glass of water before a session starts.", xpReward: 20, tier: .habit, isCompleted: false),
        Quest(id: "hydration-goal", title: "Hit your hydration goal today", detail: "Stay on top of water throughout the day.", xpReward: 60, tier: .bonus, isCompleted: false),
        Quest(id: "irl-patch", title: "IRL patch update", detail: "Stretch for 2 minutes and do a posture check.", xpReward: 20, tier: .habit, isCompleted: false),
        Quest(id: "tidy-spot", title: "Tidy one small area", detail: "Reset your desk, sink, or a small zone.", xpReward: 20, tier: .habit, isCompleted: false),
        Quest(id: "digital-cobweb", title: "Clear one digital cobweb", detail: "Archive an inbox, clear notifications, or file a document.", xpReward: 20, tier: .habit, isCompleted: false),
        Quest(id: "step-outside", title: "Step outside or change rooms", detail: "Move your body and reset your head for a few minutes.", xpReward: 20, tier: .habit, isCompleted: false),
        Quest(id: "quick-self-care", title: "Do one quick self-care check", detail: "Breathe, sip water, or take a bathroom break.", xpReward: 20, tier: .habit, isCompleted: false)
    ]

    static let coreQuestIDs: [FocusArea: [String]] = [
        .work: ["daily-checkin", "plan-focus-session", "healthbar-checkin"],
        .home: ["daily-checkin", "plan-focus-session", "healthbar-checkin"],
        .health: ["daily-checkin", "plan-focus-session", "healthbar-checkin"],
        .chill: ["daily-checkin", "plan-focus-session", "healthbar-checkin"]
    ]

    static func seedQuests(with completedIDs: Set<String>) -> [Quest] {
        let poolByID = Dictionary(uniqueKeysWithValues: questPool.map { ($0.id, $0) })

        var quests: [Quest] = requiredQuestIDs.compactMap { poolByID[$0] }

        for preferredID in preferredQuestIDs where quests.count < desiredDailyQuestCount {
            if !quests.contains(where: { $0.id == preferredID }), let quest = poolByID[preferredID] {
                quests.append(quest)
            }
        }

        let excludedIDs = Set(quests.map { $0.id })
        let remainingPool = questPool.filter { !excludedIDs.contains($0.id) }
        let remainingSlots = max(desiredDailyQuestCount - quests.count, 0)

        quests.append(contentsOf: remainingPool.shuffled().prefix(remainingSlots))

        quests = quests.map { quest in
            var updated = quest
            updated.isCompleted = completedIDs.contains(quest.id)
            updated.isCoreToday = Self.requiredQuestIDs.contains(quest.id)
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

    static let requiredQuestIDs: [String] = ["daily-checkin"]
    static let preferredQuestIDs: [String] = ["plan-focus-session", "healthbar-checkin"]
    static let nonRerollableQuestIDs: Set<String> = Set(requiredQuestIDs + preferredQuestIDs)
}
