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

    /// Defines how a quest can be completed
    enum CompletionType: Equatable {
        case manual                           // User taps to complete (legacy)
        case autoOnEvent(eventID: String)     // Auto-completes on specific event
        case progress(current: Int, target: Int, eventID: String)  // Requires multiple actions
    }

    let id: String
    let title: String
    let detail: String
    let xpReward: Int
    let tier: Tier
    var isCompleted: Bool
    var isCoreToday: Bool = false
    var completionType: CompletionType = .manual

    /// Progress for count-based quests (0.0 to 1.0)
    var progressFraction: Double {
        switch completionType {
        case .progress(let current, let target, _):
            guard target > 0 else { return 0 }
            return min(Double(current) / Double(target), 1.0)
        case .manual, .autoOnEvent:
            return isCompleted ? 1.0 : 0.0
        }
    }

    /// Progress text like "2 / 3"
    var progressText: String? {
        switch completionType {
        case .progress(let current, let target, _):
            return "\(current) / \(target)"
        default:
            return nil
        }
    }
}

/// Event IDs for quest auto-completion
enum QuestEventID: String {
    case deepFocusComplete = "deep-focus-complete"
    case selfCareComplete = "self-care-complete"
    case hydrationTap = "hydration-tap"
    case stretchComplete = "stretch-complete"
    case healthPotionUsed = "health-potion-used"
    case manaPotionUsed = "mana-potion-used"
    case staminaPotionUsed = "stamina-potion-used"
    case focusSessionComplete = "focus-session-complete"
    case midTimerTap = "mid-timer-tap"
}

final class QuestsViewModel: ObservableObject {
    @Published var dailyQuests: [Quest] = []
    @Published private(set) var hasUsedRerollToday: Bool = false
    @Published var hasQuestChestReady: Bool = false
    @Published var pendingMidTimerPrompt: MidTimerPrompt?

    /// Mid-timer engagement prompt
    struct MidTimerPrompt: Identifiable {
        let id = UUID()
        let message: String
        let xpReward: Int
    }

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

    private var questProgressKey: String {
        "quest-progress-\(completionKey)"
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
        let dateKeyValue = Self.dateKey(for: dayReference, calendar: calendar)
        dailyQuests = Self.seedQuests(
            with: completedQuestIDs(for: dayReference, calendar: calendar, userDefaults: userDefaults),
            progressData: loadProgressData(for: dayReference, calendar: calendar, userDefaults: userDefaults),
            userDefaults: userDefaults,
            dateKey: dateKeyValue
        )
        hasUsedRerollToday = userDefaults.bool(forKey: rerollKey)
        hasQuestChestReady = userDefaults.bool(forKey: questChestReadyKey)
        checkQuestChestRewardIfNeeded()

        if let focusArea = statsStore.dailyConfig?.focusArea, !statsStore.shouldShowDailySetup {
            markCoreQuests(for: focusArea)
        }
    }

    // MARK: - Event-Based Quest Completion

    /// Called when a quest-related event occurs (timer complete, potion used, etc.)
    func handleEvent(_ eventID: QuestEventID) {
        for index in dailyQuests.indices {
            var quest = dailyQuests[index]
            guard !quest.isCompleted else { continue }

            switch quest.completionType {
            case .autoOnEvent(let targetEvent):
                if targetEvent == eventID.rawValue {
                    completeQuest(at: index)
                }

            case .progress(let current, let target, let targetEvent):
                if targetEvent == eventID.rawValue {
                    let newCurrent = current + 1
                    if newCurrent >= target {
                        completeQuest(at: index)
                    } else {
                        quest.completionType = .progress(current: newCurrent, target: target, eventID: targetEvent)
                        dailyQuests[index] = quest
                        persistProgress()
                    }
                }

            case .manual:
                break
            }
        }

        // Special handling for potion synergy quest
        handlePotionSynergyQuest(eventID: eventID)
    }

    /// Tracks unique potion usage for the "Potion Master" quest
    private func handlePotionSynergyQuest(eventID: QuestEventID) {
        // Check if this is a potion event
        let potionType: String?
        switch eventID {
        case .healthPotionUsed:
            potionType = "health"
        case .manaPotionUsed:
            potionType = "mana"
        case .staminaPotionUsed:
            potionType = "stamina"
        default:
            potionType = nil
        }

        guard let potion = potionType else { return }

        // Track unique potions used today
        var usedPotions = loadUsedPotions()
        let wasAlreadyUsed = usedPotions.contains(potion)
        usedPotions.insert(potion)
        saveUsedPotions(usedPotions)

        // Update the potion-master quest progress if potion is new
        guard !wasAlreadyUsed else { return }

        for index in dailyQuests.indices {
            var quest = dailyQuests[index]
            guard quest.id == "potion-master" else { continue }
            guard !quest.isCompleted else { return }

            if case .progress(_, let target, let eventID) = quest.completionType {
                let newCount = usedPotions.count
                if newCount >= target {
                    completeQuest(at: index)
                } else {
                    quest.completionType = .progress(current: newCount, target: target, eventID: eventID)
                    dailyQuests[index] = quest
                    persistProgress()
                }
            }
            break
        }
    }

    private func loadUsedPotions() -> Set<String> {
        let key = "potions-used-\(completionKey)"
        return Set(userDefaults.stringArray(forKey: key) ?? [])
    }

    private func saveUsedPotions(_ potions: Set<String>) {
        let key = "potions-used-\(completionKey)"
        userDefaults.set(Array(potions), forKey: key)
    }

    /// Completes a quest at the given index and grants XP
    private func completeQuest(at index: Int) {
        guard index < dailyQuests.count else { return }
        guard !dailyQuests[index].isCompleted else { return }

        dailyQuests[index].isCompleted = true
        statsStore.registerQuestCompleted(id: dailyQuests[index].id, xp: dailyQuests[index].xpReward)
        persistCompletions()
        persistProgress()
        checkQuestChestRewardIfNeeded()
    }

    // MARK: - Mid-Timer Micro-Interactions

    /// Call this during active timer sessions to potentially show engagement prompt
    func considerMidTimerPrompt(elapsedSeconds: Int, totalSeconds: Int) {
        // Only show once per session, at ~40-60% through
        let progress = Double(elapsedSeconds) / Double(totalSeconds)
        guard progress >= 0.4 && progress <= 0.6 else { return }
        guard pendingMidTimerPrompt == nil else { return }

        // Check if we haven't already shown today
        let promptShownKey = "mid-timer-prompt-\(completionKey)"
        guard !userDefaults.bool(forKey: promptShownKey) else { return }

        let prompts = [
            "Still locked in? Tap to bank bonus XP!",
            "Focus check! Tap to confirm you're crushing it.",
            "Quick tap to log your streak bonus!",
            "You're in the zone. Tap to seal the deal."
        ]

        pendingMidTimerPrompt = MidTimerPrompt(
            message: prompts.randomElement() ?? prompts[0],
            xpReward: 5
        )
    }

    /// Called when user taps the mid-timer prompt
    func claimMidTimerBonus() {
        guard let prompt = pendingMidTimerPrompt else { return }

        statsStore.grantBonusXP(prompt.xpReward)
        handleEvent(.midTimerTap)

        let promptShownKey = "mid-timer-prompt-\(completionKey)"
        userDefaults.set(true, forKey: promptShownKey)

        pendingMidTimerPrompt = nil
    }

    /// Dismiss the prompt without claiming
    func dismissMidTimerPrompt() {
        let promptShownKey = "mid-timer-prompt-\(completionKey)"
        userDefaults.set(true, forKey: promptShownKey)
        pendingMidTimerPrompt = nil
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

    // MARK: - Updated Quest Pool with Event-Driven Completion

    static let questPool: [Quest] = [
        // Core quests - manual check-in stays manual
        Quest(
            id: "daily-checkin",
            title: QuestChatStrings.QuestsPool.dailyCheckInTitle,
            detail: QuestChatStrings.QuestsPool.dailyCheckInDescription,
            xpReward: 25,
            tier: .core,
            isCompleted: false,
            completionType: .manual
        ),

        // Hydrate - now requires 3 hydration taps (progress-based)
        Quest(
            id: "hydrate",
            title: QuestChatStrings.QuestsPool.hydrateTitle,
            detail: QuestChatStrings.QuestsPool.hydrateDescription,
            xpReward: 20,
            tier: .habit,
            isCompleted: false,
            completionType: .progress(current: 0, target: 3, eventID: QuestEventID.hydrationTap.rawValue)
        ),

        // Stretch - auto-completes on self-care timer completion
        Quest(
            id: "stretch",
            title: QuestChatStrings.QuestsPool.stretchTitle,
            detail: QuestChatStrings.QuestsPool.stretchDescription,
            xpReward: 15,
            tier: .habit,
            isCompleted: false,
            completionType: .autoOnEvent(eventID: QuestEventID.selfCareComplete.rawValue)
        ),

        // Plan focus session - auto-completes on any focus session start/complete
        Quest(
            id: "plan",
            title: QuestChatStrings.QuestsPool.planTitle,
            detail: QuestChatStrings.QuestsPool.planDescription,
            xpReward: 30,
            tier: .core,
            isCompleted: false,
            completionType: .autoOnEvent(eventID: QuestEventID.focusSessionComplete.rawValue)
        ),

        // Deep focus - auto-completes on deep focus timer completion
        Quest(
            id: "deep-focus",
            title: QuestChatStrings.QuestsPool.deepFocusTitle,
            detail: QuestChatStrings.QuestsPool.deepFocusDescription,
            xpReward: 35,
            tier: .bonus,
            isCompleted: false,
            completionType: .autoOnEvent(eventID: QuestEventID.deepFocusComplete.rawValue)
        ),

        // Gratitude - stays manual (journaling)
        Quest(
            id: "gratitude",
            title: QuestChatStrings.QuestsPool.gratitudeTitle,
            detail: QuestChatStrings.QuestsPool.gratitudeDescription,
            xpReward: 20,
            tier: .bonus,
            isCompleted: false,
            completionType: .manual
        ),

        // NEW: Potion synergy quest - use all 3 potion types
        Quest(
            id: "potion-master",
            title: QuestChatStrings.QuestsPool.potionMasterTitle,
            detail: QuestChatStrings.QuestsPool.potionMasterDescription,
            xpReward: 25,
            tier: .bonus,
            isCompleted: false,
            completionType: .progress(current: 0, target: 3, eventID: "potion-any")
        ),

        // NEW: Focus streak quest - complete 2 focus sessions
        Quest(
            id: "focus-streak",
            title: QuestChatStrings.QuestsPool.focusStreakTitle,
            detail: QuestChatStrings.QuestsPool.focusStreakDescription,
            xpReward: 40,
            tier: .bonus,
            isCompleted: false,
            completionType: .progress(current: 0, target: 2, eventID: QuestEventID.focusSessionComplete.rawValue)
        )
    ]

    static let coreQuestIDs: [FocusArea: [String]] = [
        .work: ["daily-checkin", "plan", "hydrate"],
        .home: ["daily-checkin", "stretch", "hydrate"],
        .health: ["stretch", "hydrate", "plan"],
        .chill: ["daily-checkin", "stretch", "plan"]
    ]

    static func seedQuests(with completedIDs: Set<String>, progressData: [String: Int], userDefaults: UserDefaults = .standard, dateKey: String = "") -> [Quest] {
        var quests = Array(questPool.prefix(5))

        // Load potion usage for synergy quest
        let potionKey = "potions-used-\(dateKey)"
        let usedPotions = Set(userDefaults.stringArray(forKey: potionKey) ?? [])

        quests = quests.map { quest in
            var updated = quest
            updated.isCompleted = completedIDs.contains(quest.id)

            // Restore progress for progress-based quests
            if case .progress(_, let target, let eventID) = quest.completionType {
                // Special handling for potion-master quest
                if quest.id == "potion-master" {
                    let potionProgress = usedPotions.count
                    updated.completionType = .progress(current: potionProgress, target: target, eventID: eventID)
                } else {
                    let savedProgress = progressData[quest.id] ?? 0
                    updated.completionType = .progress(current: savedProgress, target: target, eventID: eventID)
                }
            }

            return updated
        }

        return quests
    }

    func completedQuestIDs(for date: Date, calendar: Calendar, userDefaults: UserDefaults) -> Set<String> {
        let key = Self.dateKey(for: date, calendar: calendar)
        return Set(userDefaults.stringArray(forKey: key) ?? [])
    }

    func loadProgressData(for date: Date, calendar: Calendar, userDefaults: UserDefaults) -> [String: Int] {
        let key = "quest-progress-\(Self.dateKey(for: date, calendar: calendar))"
        guard let data = userDefaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode([String: Int].self, from: data) else {
            return [:]
        }
        return decoded
    }

    func persistCompletions() {
        let completed = dailyQuests.filter { $0.isCompleted }.map { $0.id }
        userDefaults.set(completed, forKey: completionKey)
    }

    func persistProgress() {
        var progressData: [String: Int] = [:]
        for quest in dailyQuests {
            if case .progress(let current, _, _) = quest.completionType {
                progressData[quest.id] = current
            }
        }
        if let data = try? JSONEncoder().encode(progressData) {
            userDefaults.set(data, forKey: questProgressKey)
        }
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
