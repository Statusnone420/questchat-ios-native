import Foundation
import Combine

/// Represents a quest shown in the UI. If a quest has a numeric requirement (minutes, sessions, days, cups, HP%), keep the subtitle explicit about the exact number and avoid jargon like “sprint”.
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

    let definition: QuestDefinition
    var isCompleted: Bool
    var isCoreToday: Bool = false
    var progress: Int
    var target: Int

    init(definition: QuestDefinition, isCompleted: Bool = false, isCoreToday: Bool = false, progress: Int = 0, target: Int = 1) {
        self.definition = definition
        self.isCompleted = isCompleted
        self.isCoreToday = isCoreToday
        self.progress = progress
        self.target = target
    }

    var id: String { definition.id }
    var title: String { definition.title }
    var detail: String { definition.subtitle }
    var xpReward: Int { definition.xpReward }
    var tier: Tier { definition.tier }
    var category: QuestCategory { definition.category }
    var difficulty: QuestDifficulty { definition.difficulty }
    var type: QuestType { definition.type }
    var isOncePerDay: Bool { definition.isOncePerDay }
    var completionMode: QuestCompletionMode { definition.completionMode }

    var progressFraction: Double {
        guard target > 0 else { return 0 }
        return min(Double(progress) / Double(target), 1.0)
    }

    var hasProgress: Bool {
        target > 1 && status != .completed
    }

    var status: QuestStatus {
        if isCompleted || progress >= target {
            return .completed
        }
        return progress > 0 ? .inProgress : .pending
    }
}

extension Quest {
    static func == (lhs: Quest, rhs: Quest) -> Bool {
        return lhs.id == rhs.id
    }
}

final class QuestsViewModel: ObservableObject {
    struct LastDailyCompletion: Codable, Equatable {
        let id: String
        let date: Date
    }
    struct ChainEntry: Codable, Equatable {
        let id: String
        let date: Date
    }

    private var lastCompletionKey: String { "last-completion-\(completionKey)" }
    private var dailyActiveKey: String { "daily-active-\(completionKey)" }
    
    @Published var dailyQuests: [Quest] = []
    @Published var weeklyQuests: [Quest] = []
    @Published private(set) var hasUsedRerollToday: Bool = false
    @Published var hasQuestChestReady: Bool = false
    
    @Published private(set) var mysteryQuestID: String? = nil
    
    // Added published dictionary to hold daily hints for quests
    @Published var dailyHints: [String: String] = [:]

    private var mysteryKey: String { "mystery-\(completionKey)" }
    private var chainHistoryKey: String { "chain-history-\(completionKey)" }

    private var isSyncScheduled = false

    private let statsStore: SessionStatsStore
    private let questEngine: QuestEngine
    private let userDefaults: UserDefaults
    private let calendar: Calendar
    private let dayReference: Date
    
    private static let disabledDailyQuestIDs: Set<String> = [
        "irl-patch",
        "tidy-spot",
        "step-outside",
        "quick-self-care",
    ]
    private static let disabledWeeklyQuestIDs: Set<String> = [
        "weekly-digital-dust",
    ]
    private var hydrationGoalDaysThisWeek: Set<Date> = []
    private var hpCheckinDaysThisWeek: Set<Date> = []
    private var weeklyWorkTimerCount: Int = 0
    private var weeklyWorkMinutes: Int = 0
    private var weeklyChoresMinutes: Int = 0
    private var weeklySelfCareDays: Set<Date> = []
    private var weeklyEveningResetDays: Set<Date> = []
    private var weeklyDailySetupDays: Set<Date> = []
    private var weekendTimerDays: Set<Date> = []
    private var weeklyHardQuestCount: Int = 0

    private var completionKey: String {
        Self.dateKey(for: dayReference, calendar: calendar)
    }

    private var questLogOpenedKey: String {
        "quests-log-opened-\(completionKey)"
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
    
    // Added timer combo bonus key
    private var timerComboGrantedKey: String { "timer-combo-granted-\(completionKey)" }

    private var currentWeekKey: String {
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: dayReference)
        let year = components.yearForWeekOfYear ?? 0
        let week = components.weekOfYear ?? 0
        return String(format: "weekly-quests-%04d-W%02d", year, week)
    }

    private var weeklyCompletionKey: String {
        "\(currentWeekKey)-completed"
    }

    private var weeklyActiveKey: String {
        "\(currentWeekKey)-active"
    }

    private var hydrationGoalDaysKey: String {
        "\(currentWeekKey)-hydration-days"
    }

    private var hpCheckinDaysKey: String {
        "\(currentWeekKey)-hp-checkins"
    }
    private var workTimerCountKey: String {
        "\(currentWeekKey)-work-timer-count"
    }
    private var workMinutesKey: String {
        "\(currentWeekKey)-work-minutes"
    }
    private var choresMinutesKey: String {
        "\(currentWeekKey)-chores-minutes"
    }
    private var selfCareDaysKey: String {
        "\(currentWeekKey)-selfcare-days"
    }
    private var eveningResetDaysKey: String {
        "\(currentWeekKey)-evening-resets"
    }
    private var dailySetupDaysKey: String {
        "\(currentWeekKey)-setup-days"
    }
    private var weekendTimerDaysKey: String {
        "\(currentWeekKey)-weekend-timers"
    }
    private var hardQuestCountKey: String {
        "\(currentWeekKey)-hard-quests"
    }
    
    // Added helpers to check/set timer combo bonus grant state
    private func hasGrantedTimerComboBonus() -> Bool { userDefaults.bool(forKey: timerComboGrantedKey) }
    private func setGrantedTimerComboBonus() { userDefaults.set(true, forKey: timerComboGrantedKey) }

    private func loadLastDailyCompletion() -> LastDailyCompletion? {
        guard let data = userDefaults.data(forKey: lastCompletionKey) else { return nil }
        return try? JSONDecoder().decode(LastDailyCompletion.self, from: data)
    }

    private func saveLastDailyCompletion(_ value: LastDailyCompletion) {
        if let data = try? JSONEncoder().encode(value) {
            userDefaults.set(data, forKey: lastCompletionKey)
        }
    }
    
    private func loadChainHistory() -> [ChainEntry] {
        guard let data = userDefaults.data(forKey: chainHistoryKey) else { return [] }
        return (try? JSONDecoder().decode([ChainEntry].self, from: data)) ?? []
    }

    private func saveChainHistory(_ entries: [ChainEntry]) {
        if let data = try? JSONEncoder().encode(entries) {
            userDefaults.set(data, forKey: chainHistoryKey)
        }
    }

    init(
        statsStore: SessionStatsStore = DependencyContainer.shared.sessionStatsStore,
        questEngine: QuestEngine = DependencyContainer.shared.questEngine,
        userDefaults: UserDefaults = .standard,
        calendar: Calendar = .current
    ) {
        self.statsStore = statsStore
        self.questEngine = questEngine
        self.userDefaults = userDefaults
        self.calendar = calendar
        dayReference = calendar.startOfDay(for: Date())
        
        let completedToday = Self.completedQuestIDs(for: dayReference, calendar: calendar, userDefaults: userDefaults)
        if let activeIDs = userDefaults.stringArray(forKey: dailyActiveKey), !activeIDs.isEmpty {
            // Restore exact board
            let pool = Self.activeDailyQuestPool
            let byID = Dictionary(uniqueKeysWithValues: pool.map { ($0.id, $0) })
            let restored: [Quest] = activeIDs.compactMap { id in
                guard let def = byID[id] else { return nil }
                return Quest(definition: def, isCompleted: completedToday.contains(id), isCoreToday: Self.requiredQuestIDs.contains(id))
            }
            if !restored.isEmpty {
                dailyQuests = restored
            } else {
                dailyQuests = Self.seedQuests(with: completedToday)
            }
        } else {
            dailyQuests = Self.seedQuests(with: completedToday)
        }
        // Persist the active board for the day
        userDefaults.set(dailyQuests.map { $0.id }, forKey: dailyActiveKey)
        
        // Seed/load Mystery Buff quest for the day
        if let storedMystery = userDefaults.string(forKey: mysteryKey) {
            mysteryQuestID = storedMystery
        } else {
            // Pick a random quest from today's active board
            mysteryQuestID = dailyQuests.randomElement()?.id
            if let id = mysteryQuestID {
                userDefaults.set(id, forKey: mysteryKey)
            }
        }

        #if DEBUG
        let dateKey = Self.dateKey(for: dayReference, calendar: calendar)
        print("DailyQuestStore: restoring \(dailyQuests.count) quests for \(dateKey)")
        #endif

        hasUsedRerollToday = userDefaults.bool(forKey: rerollKey)
        hasQuestChestReady = userDefaults.bool(forKey: questChestReadyKey)
        checkQuestChestRewardIfNeeded()

        seedWeeklyQuestsIfNeeded()
        loadHydrationGoalDays()
        loadHPCheckinDays()
        loadWeeklyTimerProgress()
        loadSelfCareDays()
        loadEveningResetDays()
        loadDailySetupDays()
        loadWeekendTimerDays()
        weeklyHardQuestCount = userDefaults.integer(forKey: hardQuestCountKey)
        updateWeeklyHydrationQuestCompletion()
        updateWeeklyHPQuestCompletion()
        updateWeeklyDailyQuestCompletionProgress()

        if let focusArea = statsStore.todayPlan?.focusArea, !statsStore.shouldShowDailySetup {
            markCoreQuests(for: focusArea)
        }

        statsStore.questEventHandler = { [weak self] event in
            self?.handleQuestEvent(event)
            self?.syncQuestProgress()
        }

        statsStore.emitQuestProgressSnapshot()
        statsStore.updateDailyQuestsCompleted(completedQuestsCount, totalQuests: dailyQuests.count)

        NotificationCenter.default.addObserver(forName: .gutRatingUpdated, object: nil, queue: .main) { [weak self] note in
            self?.completeQuestIfNeeded(id: "DAILY_HB_GUT_CHECK")
        }

        syncQuestProgress()
        recomputeDailyHints() // Initialize hints after setup
    }

    var completedQuestsCount: Int {
        dailyQuests.filter { $0.isCompleted }.count
    }

    var sortedDailyQuests: [Quest] {
        dailyQuests
            .enumerated()
            .sorted { lhs, rhs in
                if lhs.element.isCompleted != rhs.element.isCompleted {
                    return lhs.element.isCompleted == false
                }

                return lhs.offset < rhs.offset
            }
            .map(\.element)
    }

    var totalQuestsCount: Int {
        dailyQuests.count
    }

    var totalDailyXP: Int {
        dailyQuests.reduce(0) { $0 + $1.xpReward }
    }

    var allCoreDailyQuestsCompleted: Bool {
        let coreQuests = dailyQuests.filter { $0.isCoreToday }
        return !coreQuests.isEmpty && coreQuests.allSatisfy { $0.isCompleted }
    }

    var weeklyCompletedCount: Int {
        weeklyQuests.filter { $0.isCompleted }.count
    }

    var weeklyTotalCount: Int {
        weeklyQuests.count
    }

    var sortedWeeklyQuests: [Quest] {
        weeklyQuests.sorted { lhs, rhs in
            if lhs.isCompleted != rhs.isCompleted {
                return !lhs.isCompleted && rhs.isCompleted
            }

            if !lhs.isCompleted && !rhs.isCompleted && lhs.progressFraction != rhs.progressFraction {
                return lhs.progressFraction > rhs.progressFraction
            }

            return lhs.title < rhs.title
        }
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
        guard quest.completionMode == .manualDebug else { return }
        guard let index = dailyQuests.firstIndex(where: { $0.id == quest.id }) else { return }

        let wasCompleted = dailyQuests[index].isCompleted
        dailyQuests[index].isCompleted.toggle()

        if dailyQuests[index].isCompleted && !wasCompleted {
            statsStore.registerQuestCompleted(id: dailyQuests[index].id, xp: dailyQuests[index].xpReward)
            updateWeeklyDailyQuestCompletionProgress()
            trackHardQuestCompletion(for: dailyQuests[index])
        }

        persistCompletions()
        checkQuestChestRewardIfNeeded()
        statsStore.updateDailyQuestsCompleted(completedQuestsCount, totalQuests: dailyQuests.count)

        syncQuestProgress()
    }

    func handleQuestEvent(_ event: QuestEvent) {
        // HOW TO ADD A NEW AUTO QUEST
        // 1. Add the quest to QuestCatalog.md with a clear completion condition.
        // 2. If it maps to existing data, add a case to `QuestEvent` (if needed) and call
        //    `completeQuestIfNeeded(id:)` or `completeWeeklyQuestIfNeeded(id:)` in the matching event below.
        // 3. Make sure no UI tap handler toggles this quest directly.
        switch event {
        case .questsTabOpened:
            completeQuestIfNeeded(id: "LOAD_QUEST_LOG")
        case .focusSessionStarted(let durationMinutes):
            guard durationMinutes >= 15 else { return }
            completeQuestIfNeeded(id: "plan-focus-session")
        case .focusSessionCompleted(let durationMinutes):
            guard durationMinutes >= 25 else { return }
            completeQuestIfNeeded(id: "finish-focus-session")
            completeWeeklyFocusSessionQuestsIfNeeded()
        case .timerCompleted(let category, let durationMinutes, let endedAt):
            handleTimerCompletion(category: category, durationMinutes: durationMinutes, endedAt: endedAt)
        case .focusMinutesUpdated(let totalMinutesToday):
            // Legacy quest still in pool
            if totalMinutesToday >= 25 {
                completeQuestIfNeeded(id: "focus-25-min")
            }
            completeWeeklyFocusMinuteQuestsIfNeeded()
        case .focusSessionsUpdated:
            completeWeeklyFocusSessionQuestsIfNeeded()
        case .choresTimerCompleted(let durationMinutes):
            guard durationMinutes >= 10 else { return }
            completeQuestIfNeeded(id: "chore-blitz")
        case .hpCheckinCompleted:
            completeQuestIfNeeded(id: "DAILY_HB_MORNING_CHECKIN")
            completeQuestIfNeeded(id: "DAILY_HB_GUT_CHECK")
            completeQuestIfNeeded(id: "DAILY_HB_SLEEP_LOG")
            registerHPCheckinDayIfNeeded()
        case .hydrationLogged(_, let totalMlToday, let percentOfGoal):
            guard totalMlToday > 0 else { return }
            completeQuestIfNeeded(id: "DAILY_HB_FIRST_POTION")
            // Easy sip at >= 4oz (118 ml exact)
            if totalMlToday >= 118 {
                completeQuestIfNeeded(id: "DAILY_EASY_HYDRATION_SIP")
            }
            // Legacy hydrate-checkpoint at >= 16oz (473 ml exact)
            if totalMlToday >= 473 {
                completeQuestIfNeeded(id: "hydrate-checkpoint")
            }
        case .hydrationGoalReached:
            completeQuestIfNeeded(id: "hydration-goal")
            registerHydrationGoalDayIfNeeded()
        case .hydrationGoalDayCompleted:
            registerHydrationGoalDayIfNeeded()
        case .dailySetupCompleted:
            completeQuestIfNeeded(id: "DAILY_META_SETUP_COMPLETE")
            // Removed reference to DAILY_META_CHOOSE_FOCUS (not in new pool)
            registerDailySetupDay()
        case .statsViewed(let scope):
            switch scope {
            case .today:
                completeQuestIfNeeded(id: "DAILY_META_STATS_TODAY")
            case .yesterday:
                // Removed reference to DAILY_META_REVIEW_YESTERDAY (not in new pool)
                break
            }
        case .hydrationReminderFired:
            completeQuestIfNeeded(id: "DAILY_EASY_HYDRATION_SIP")
        case .postureReminderFired:
            completeQuestIfNeeded(id: "DAILY_HB_POSTURE_CHECK")
        case .playerCardViewed:
            completeQuestIfNeeded(id: "DAILY_META_PLAYER_CARD")
        }

        syncQuestProgress()
    }

    func handleQuestLogOpenedIfNeeded() {
        guard !userDefaults.bool(forKey: questLogOpenedKey) else { return }
        userDefaults.set(true, forKey: questLogOpenedKey)
        handleQuestEvent(.questsTabOpened)
        // Fix core quest "load today's quest log" auto-completion on log open
        completeQuestIfNeeded(id: "daily-checkin")
    }

    func syncQuestProgress() {
        // Coalesce multiple sync requests within the same runloop to avoid stale reads and redundant work.
        if isSyncScheduled { return }
        isSyncScheduled = true
        DispatchQueue.main.async { [weak self] in
            self?.performSyncQuestProgress()
        }
    }

    private func performSyncQuestProgress() {
        isSyncScheduled = false

        dailyQuests = dailyQuests.map { quest in
            var updated = quest
            updated.target = 1
            updated.progress = quest.isCompleted ? updated.target : 0
            return updated
        }

        weeklyQuests = weeklyQuests.map { quest in
            let progressInfo = weeklyProgress(for: quest)
            var updated = quest
            updated.target = progressInfo.target
            updated.progress = min(progressInfo.progress, progressInfo.target)
            return updated
        }

        questEngine.updateDailyQuests(dailyQuests.map { questInstance(from: $0) })
        questEngine.updateWeeklyQuests(weeklyQuests.map { questInstance(from: $0) })
        
        recomputeDailyHints() // Keep hints fresh after syncing progress
    }
    
    // Private helper to recompute hints for incomplete daily quests
    private func recomputeDailyHints() {
        var hints: [String: String] = [:]

        // Build a lookup for definitions
        let pool = Self.activeDailyQuestPool
        let byID = Dictionary(uniqueKeysWithValues: pool.map { ($0.id, $0) })

        // Simple context from stats
        let focusMinutesToday = statsStore.focusSecondsToday / 60
        let selfCareMinutesToday = statsStore.selfCareSecondsToday / 60
        let choresMinutesToday = weeklyChoresMinutes // fallback; if you track today separately, replace

        for quest in dailyQuests where !quest.isCompleted {
            guard let def = byID[quest.id] else { continue }
            switch def.id {
            case "DAILY_TIMER_QUICK_WORK":
                if focusMinutesToday < 10 {
                    let remaining = max(0, 10 - focusMinutesToday)
                    hints[def.id] = remaining > 0 ? "\(remaining)m to go — a quick sprint finishes this." : nil
                }
            case "DAILY_TIMER_MINDFUL_BREAK":
                if selfCareMinutesToday < 5 {
                    let remaining = max(0, 5 - selfCareMinutesToday)
                    hints[def.id] = remaining > 0 ? "\(remaining)m away — try a 5-minute self-care." : nil
                }
            case "DAILY_TIMER_CHORES_BURST":
                if choresMinutesToday < 5 {
                    let remaining = max(0, 5 - choresMinutesToday)
                    hints[def.id] = remaining > 0 ? "\(remaining)m left — a tiny tidy completes it." : nil
                }
            case "DAILY_HB_FIRST_POTION":
                hints[def.id] = "Log your first drink to complete this."
            case "DAILY_HB_POSTURE_CHECK":
                hints[def.id] = "Acknowledge one posture reminder."
            case "DAILY_HB_MORNING_CHECKIN":
                hints[def.id] = "Open Player Card and log mood."
            case "DAILY_EASY_ONE_NICE_THING":
                hints[def.id] = "Any 5-minute timer counts — start one now."
            case "DAILY_EASY_TWO_CHAIN":
                hints[def.id] = "Complete 2 quests within 10 minutes — you’ve got this."
            case "DAILY_EASY_THREE_CHAIN":
                hints[def.id] = "3 quests within 30 minutes — go for a mini streak."
            default:
                break
            }
        }

        dailyHints = hints
    }

    func isEventDrivenQuest(_ quest: Quest) -> Bool {
        quest.completionMode == .automatic
    }

    func isEventDrivenWeeklyQuest(_ quest: Quest) -> Bool {
        quest.completionMode == .automatic
    }

    func toggleWeeklyQuest(_ quest: Quest) {
        guard quest.completionMode == .manualDebug else { return }
        guard let index = weeklyQuests.firstIndex(where: { $0.id == quest.id }) else { return }

        let wasCompleted = weeklyQuests[index].isCompleted
        weeklyQuests[index].isCompleted.toggle()

        if weeklyQuests[index].isCompleted && !wasCompleted {
            statsStore.registerQuestCompleted(id: weeklyQuests[index].id, xp: weeklyQuests[index].xpReward)
            trackHardQuestCompletion(for: weeklyQuests[index])
        }

        persistWeeklyCompletions()

        syncQuestProgress()
    }

    func reroll(quest: Quest) {
        // EARLY RETURNS AS PER REQUEST
        if dailyQuests.allSatisfy({ $0.isCompleted }) {
            #if DEBUG
            print("DailyQuestStore: reroll blocked — all quests already completed for \(Self.dateKey(for: dayReference, calendar: calendar)))")
            #endif
            return
        }
        
        let remainingIncomplete = dailyQuests.filter { !$0.isCompleted }.count
        if remainingIncomplete <= 1 {
            #if DEBUG
            print("DailyQuestStore: reroll blocked — only \(remainingIncomplete) incomplete quest(s) remain")
            #endif
            return
        }

        // Re-fetch quest fresh by id to avoid stale state
        guard let freshQuest = dailyQuests.first(where: { $0.id == quest.id }) else {
            return
        }
        if freshQuest.isCompleted {
            #if DEBUG
            print("DailyQuestStore: reroll blocked — quest already completed: \(quest.id)")
            #endif
            return
        }

        guard !hasUsedRerollToday else { return }
        guard !freshQuest.isCompleted else { return }
        // Removed guard against nonRerollableQuestIDs.contains(quest.id) to allow reroll for "plan-focus-session"
        guard let index = dailyQuests.firstIndex(where: { $0.id == quest.id }) else { return }

        let currentIDs = Set(dailyQuests.map { $0.id })
        let completedToday = Self.completedQuestIDs(for: dayReference, calendar: calendar, userDefaults: userDefaults)
        let currentDefinitions = dailyQuests.map { $0.definition }

        let preferredPool = Self.activeDailyQuestPool.filter { candidate in
            candidate.id != quest.id &&
                !currentIDs.contains(candidate.id) &&
                !completedToday.contains(candidate.id) &&
                candidate.category == quest.category &&
                candidate.difficulty == quest.difficulty
        }

        let fallbackPool = Self.activeDailyQuestPool.filter { candidate in
            candidate.id != quest.id &&
                !currentIDs.contains(candidate.id) &&
                !completedToday.contains(candidate.id)
        }

        var newDefinition: QuestDefinition? = nil
        var mode = "none"

        // Try preferred pool with board rules
        newDefinition = preferredPool.first(where: { candidate in
            var updatedDefinitions = currentDefinitions
            updatedDefinitions[index] = candidate
            return Self.meetsDailyBoardRules(definitions: updatedDefinitions)
        })

        if let def = newDefinition {
            mode = "preferred"
        } else {
            // Try fallback pool with board rules
            newDefinition = fallbackPool.first(where: { candidate in
                var updatedDefinitions = currentDefinitions
                updatedDefinitions[index] = candidate
                return Self.meetsDailyBoardRules(definitions: updatedDefinitions)
            })
            if let def = newDefinition {
                mode = "fallback"
            }
        }

        // Removed final fallback that ignores board rules per instructions

        guard let replacement = newDefinition else { return }

        // Re-check quest completion before applying replacement to avoid race conditions
        guard let freshQuestAfterSelection = dailyQuests.first(where: { $0.id == quest.id }), !freshQuestAfterSelection.isCompleted else {
            #if DEBUG
            print("DailyQuestStore: reroll blocked — quest already completed: \(quest.id)")
            #endif
            return
        }

        dailyQuests[index] = Quest(
            definition: replacement,
            isCompleted: false,
            isCoreToday: false
        )

        hasUsedRerollToday = true
        userDefaults.set(true, forKey: rerollKey)
        persistCompletions()
        userDefaults.set(dailyQuests.map { $0.id }, forKey: dailyActiveKey)

        #if DEBUG
        let dateKey = Self.dateKey(for: dayReference, calendar: calendar)
        print("DailyQuestStore: rerolled quest \(quest.id) -> \(replacement.id) for \(dateKey) [mode: \(mode)]")
        #endif

        if let focusArea = statsStore.todayPlan?.focusArea, !statsStore.shouldShowDailySetup {
            markCoreQuests(for: focusArea)
        }

        syncQuestProgress()
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

extension QuestsViewModel {
    static let questChestBonusXP = 50

    static let desiredDailyQuestCount = 7  // Increased from 5 to show more variety
    static let maxTimerQuests = 3  // Increased from 2 since we have fewer timer quests overall

    static var activeDailyQuestPool: [QuestDefinition] {
        QuestCatalog.allDailyQuests.filter { !disabledDailyQuestIDs.contains($0.id) && $0.completionMode == .automatic }
    }

    static var activeWeeklyQuestPool: [QuestDefinition] {
        QuestCatalog.activeWeeklyQuestPool.filter { !disabledWeeklyQuestIDs.contains($0.id) && $0.completionMode == .automatic }
    }

    static let coreQuestIDs: [FocusArea: [String]] = [
        // Keep only new streamlined core quests; no legacy IDs
        .work: ["DAILY_META_SETUP_COMPLETE", "DAILY_TIMER_QUICK_WORK", "DAILY_HB_MORNING_CHECKIN"],
        .selfCare: ["DAILY_META_SETUP_COMPLETE", "DAILY_TIMER_MINDFUL_BREAK", "DAILY_EASY_ONE_NICE_THING"],
        .chill: ["DAILY_META_SETUP_COMPLETE", "DAILY_TIMER_CHILL_CHOICE", "DAILY_EASY_ONE_NICE_THING"],
        .grind: ["DAILY_META_SETUP_COMPLETE", "DAILY_TIMER_QUICK_WORK", "DAILY_EASY_TWO_CHAIN"]
    ]

    static func seedQuests(with completedIDs: Set<String>) -> [Quest] {
        #if DEBUG
        // This path seeds the daily board (reroll) for the active date.
        let todayKey = dateKey(for: Date(), calendar: .current)
        print("DailyQuestStore: rerolling daily quests for new date \(todayKey)")
        #endif
        var selectedDefinitions: [QuestDefinition] = requiredQuestIDs.compactMap { id in
            activeDailyQuestPool.first(where: { $0.id == id })
        }

        var availablePool = activeDailyQuestPool.filter { definition in
            !selectedDefinitions.contains(where: { $0.id == definition.id })
        }

        for preferredID in preferredQuestIDs where selectedDefinitions.count < desiredDailyQuestCount {
            guard let definition = availablePool.first(where: { $0.id == preferredID }) else { continue }
            guard canAddToBoard(definition: definition, existing: selectedDefinitions) else { continue }
            selectedDefinitions.append(definition)
            availablePool.removeAll { $0.id == definition.id }
        }

        enforceCategoryMinimums(into: &selectedDefinitions, availablePool: &availablePool)

        for definition in availablePool.shuffled() {
            guard selectedDefinitions.count < desiredDailyQuestCount else { break }
            guard canAddToBoard(definition: definition, existing: selectedDefinitions) else { continue }
            selectedDefinitions.append(definition)
        }
        
        // Ensure at least one chain quest (two or three) is present if possible
        let chainIDs = ["DAILY_EASY_THREE_CHAIN", "DAILY_EASY_TWO_CHAIN"]
        let currentIDs = Set(selectedDefinitions.map { $0.id })
        if chainIDs.allSatisfy({ !currentIDs.contains($0) }) {
            if let candidate = availablePool.first(where: { chainIDs.contains($0.id) && canAddToBoard(definition: $0, existing: selectedDefinitions) }) {
                // Try to append if space, else swap a non-required easyWin
                if selectedDefinitions.count < desiredDailyQuestCount {
                    selectedDefinitions.append(candidate)
                } else if let swapIndex = selectedDefinitions.firstIndex(where: { $0.category == .easyWin && !requiredQuestIDs.contains($0.id) }) {
                    selectedDefinitions[swapIndex] = candidate
                }
            }
        }

        return selectedDefinitions.map { definition in
            assert(definition.completionMode == .automatic, "Generator should never surface manualDebug quest \(definition.id)")
            return Quest(
                definition: definition,
                isCompleted: completedIDs.contains(definition.id),
                isCoreToday: Self.requiredQuestIDs.contains(definition.id)
            )
        }
    }

    static func canAddToBoard(definition: QuestDefinition, existing: [QuestDefinition]) -> Bool {
        let timerCount = existing.filter { $0.category == .timer }.count
        if definition.category == .timer && timerCount >= maxTimerQuests {
            return false
        }

        return true
    }

    static func meetsDailyBoardRules(definitions: [QuestDefinition]) -> Bool {
        let timerCount = definitions.filter { $0.category == .timer }.count
        let hasHealthBar = definitions.contains { $0.category == .healthBar }
        let hasEasyWin = definitions.contains { $0.category == .easyWin }
        return timerCount <= maxTimerQuests && hasHealthBar && hasEasyWin
    }

    static func enforceCategoryMinimums(into selected: inout [QuestDefinition], availablePool: inout [QuestDefinition]) {
        addCategoryRequirement(.healthBar, into: &selected, availablePool: &availablePool)
        addCategoryRequirement(.easyWin, into: &selected, availablePool: &availablePool)
    }

    static func addCategoryRequirement(_ category: QuestCategory, into selected: inout [QuestDefinition], availablePool: inout [QuestDefinition]) {
        guard !selected.contains(where: { $0.category == category }) else { return }
        guard let candidateIndex = availablePool.firstIndex(where: { $0.category == category }) else { return }

        let candidate = availablePool.remove(at: candidateIndex)
        if selected.count < desiredDailyQuestCount, canAddToBoard(definition: candidate, existing: selected) {
            selected.append(candidate)
            return
        }

        for index in selected.indices {
            let existing = selected[index]
            guard !requiredQuestIDs.contains(existing.id) else { continue }
            var updated = selected
            updated.remove(at: index)
            if canAddToBoard(definition: candidate, existing: updated) {
                selected = updated
                selected.append(candidate)
                return
            }
        }

        availablePool.append(candidate)
    }

    func handleTimerCompletion(category: TimerCategory.Kind, durationMinutes: Int, endedAt: Date) {
        let startOfDay = calendar.startOfDay(for: endedAt)

        // Updated to match new streamlined daily quests
        if isWorkCategory(category) {
            if durationMinutes >= 10 { completeQuestIfNeeded(id: "DAILY_TIMER_QUICK_WORK") }
            registerWorkTimerProgress(durationMinutes: durationMinutes)
        }

        if isChoresCategory(category) {
            if durationMinutes >= 3 { completeQuestIfNeeded(id: "DAILY_EASY_TINY_TIDY") }
            if durationMinutes >= 5 { completeQuestIfNeeded(id: "DAILY_TIMER_CHORES_BURST") }
            registerChoresProgress(durationMinutes: durationMinutes)
        }

        if isSelfCareCategory(category) {
            if durationMinutes >= 5 { completeQuestIfNeeded(id: "DAILY_TIMER_MINDFUL_BREAK") }
            registerSelfCareDayIfNeeded(date: startOfDay, durationMinutes: durationMinutes)
        }

        if isChillCategory(category) {
            if durationMinutes >= 10 { completeQuestIfNeeded(id: "DAILY_TIMER_CHILL_CHOICE") }
            if durationMinutes >= 5 { completeQuestIfNeeded(id: "DAILY_TIMER_GAMING_SESSION") }
        }

        if durationMinutes >= 5 {
            completeQuestIfNeeded(id: "DAILY_EASY_ONE_NICE_THING")
        }

        registerWeekendTimerIfNeeded(durationMinutes: durationMinutes, date: startOfDay)
    }

    func isWorkCategory(_ category: TimerCategory.Kind) -> Bool { category == .focusMode || category == .create }
    func isChoresCategory(_ category: TimerCategory.Kind) -> Bool { category == .chores }
    func isSelfCareCategory(_ category: TimerCategory.Kind) -> Bool { category == .selfCare || category == .move }
    func isChillCategory(_ category: TimerCategory.Kind) -> Bool { category == .gamingReset }

    func registerWorkTimerProgress(durationMinutes: Int) {
        if durationMinutes >= 25 {
            weeklyWorkTimerCount += 1
        }
        weeklyWorkMinutes += durationMinutes
        persistWeeklyTimerProgress()
        if weeklyWorkTimerCount >= 5 {
            completeWeeklyQuestIfNeeded(id: "WEEK_WORK_WARRIOR")
        }
        if weeklyWorkMinutes >= 200 {
            completeWeeklyQuestIfNeeded(id: "WEEK_DEEP_WORK")
        }

        syncQuestProgress()
    }

    func registerChoresProgress(durationMinutes: Int) {
        weeklyChoresMinutes += durationMinutes
        persistWeeklyTimerProgress()
        if weeklyChoresMinutes >= 90 {
            completeWeeklyQuestIfNeeded(id: "WEEK_CLUTTER_CRUSHER")
        }

        syncQuestProgress()
    }

    func registerSelfCareDayIfNeeded(date: Date, durationMinutes: Int) {
        guard durationMinutes >= 15 else { return }
        if weeklySelfCareDays.insert(date).inserted {
            persistSelfCareDays()
        }
        if weeklySelfCareDays.count >= 4 {
            completeWeeklyQuestIfNeeded(id: "WEEK_SELFCARE_CHAMPION")
        }

        syncQuestProgress()
    }

    func registerEveningResetDayIfNeeded(date: Date) {
        if weeklyEveningResetDays.insert(date).inserted {
            persistEveningResetDays()
        }

        if weeklyEveningResetDays.count >= 3 {
            completeWeeklyQuestIfNeeded(id: "WEEK_EVENING_RESET")
        }

        syncQuestProgress()
    }

    func registerDailySetupDay() {
        let today = calendar.startOfDay(for: Date())
        if weeklyDailySetupDays.insert(today).inserted {
            persistDailySetupDays()
        }

        if weeklyDailySetupDays.count >= 5 {
            completeWeeklyQuestIfNeeded(id: "WEEK_DAILY_SETUP_STREAK")
        }

        syncQuestProgress()
    }

    func registerWeekendTimerIfNeeded(durationMinutes: Int, date: Date) {
        guard calendar.isDateInWeekend(date) else { return }
        guard durationMinutes >= 20 else { return }
        if weekendTimerDays.insert(date).inserted {
            persistWeekendTimerDays()
        }
        updateWeekendWarriorProgress()

        syncQuestProgress()
    }

    func trackHardQuestCompletion(for quest: Quest) {
        guard quest.difficulty == .hard else { return }
        weeklyHardQuestCount += 1
        persistHardQuestCount()
        if weeklyHardQuestCount >= 3 {
            completeWeeklyQuestIfNeeded(id: "WEEK_MINI_BOSS")
        }
    }

    static func completedQuestIDs(for date: Date, calendar: Calendar, userDefaults: UserDefaults) -> Set<String> {
        let key = dateKey(for: date, calendar: calendar)
        return Set(userDefaults.stringArray(forKey: key) ?? [])
    }

    func completeQuestIfNeeded(id: String) {
        guard let index = dailyQuests.firstIndex(where: { $0.id == id }) else { return }
        guard !dailyQuests[index].isCompleted else { return }

        let hadCompletedQuests = dailyQuests.contains(where: { $0.isCompleted })

        // Chain quest: complete DAILY_EASY_TWO_CHAIN when two different quests are completed within 10 minutes.
        // Do not allow the chain quest to trigger itself.
        let chainQuestId = "DAILY_EASY_TWO_CHAIN"
        let now = Date()
        let previous = loadLastDailyCompletion()
        let canConsiderChain = id != chainQuestId
        var shouldTriggerChain = false
        if canConsiderChain, let prev = previous {
            // Same calendar day safeguard is implicit via per-day key; also ensure different quest id
            if prev.id != id, now.timeIntervalSince(prev.date) <= 10 * 60 {
                // Only trigger if chain quest isn't already completed today
                if let chainIndex = dailyQuests.firstIndex(where: { $0.id == chainQuestId }) {
                    shouldTriggerChain = !dailyQuests[chainIndex].isCompleted
                }
            }
        }

        dailyQuests[index].isCompleted = true
        statsStore.registerQuestCompleted(id: dailyQuests[index].id, xp: dailyQuests[index].xpReward)
        trackHardQuestCompletion(for: dailyQuests[index])
        updateWeeklyDailyQuestCompletionProgress()

        persistCompletions()
        checkQuestChestRewardIfNeeded()
        statsStore.updateDailyQuestsCompleted(completedQuestsCount, totalQuests: dailyQuests.count)

        if allQuestsComplete {
            hasUsedRerollToday = true
            userDefaults.set(true, forKey: rerollKey)
            userDefaults.set(dailyQuests.map { $0.id }, forKey: dailyActiveKey)
        }

        // Mystery Buff: grant bonus XP when the mystery quest is completed
        if let mysteryId = mysteryQuestID, mysteryId == id {
            statsStore.registerQuestCompleted(id: "DAILY_MYSTERY_BONUS", xp: 15)
        }
        
        // One-time Timer Combo bonus: two timer quests in a day
        if !hasGrantedTimerComboBonus() {
            let completedTodayIDs = dailyQuests.filter { $0.isCompleted }.map { $0.id }
            let defsByID = Dictionary(uniqueKeysWithValues: Self.activeDailyQuestPool.map { ($0.id, $0) })
            let completedTimerCount = completedTodayIDs.compactMap { defsByID[$0] }.filter { $0.category == .timer }.count
            if completedTimerCount >= 2 {
                statsStore.registerQuestCompleted(id: "DAILY_TIMER_COMBO_BONUS", xp: 10)
                setGrantedTimerComboBonus()
            }
        }

        if !hadCompletedQuests && id != "DAILY_EASY_FIRST_QUEST" {
            completeQuestIfNeeded(id: "DAILY_EASY_FIRST_QUEST")
        }

        // Update last completion (must be after marking this quest complete)
        saveLastDailyCompletion(LastDailyCompletion(id: id, date: now))

        // Update chain history and evaluate three-chain
        var history = loadChainHistory()
        history.append(ChainEntry(id: id, date: now))
        if history.count > 4 { history.removeFirst(history.count - 4) }
        saveChainHistory(history)

        // Check for 3 different quests within 30 minutes
        let window: TimeInterval = 30 * 60
        let recent = history.filter { now.timeIntervalSince($0.date) <= window }
        let distinctIDs = Array(Set(recent.map { $0.id }))
        if distinctIDs.count >= 3 {
            // Only trigger if the three-chain quest is on the board and not already completed
            if let chainIndex = dailyQuests.firstIndex(where: { $0.id == "DAILY_EASY_THREE_CHAIN" }) {
                if !dailyQuests[chainIndex].isCompleted {
                    completeQuestIfNeeded(id: "DAILY_EASY_THREE_CHAIN")
                }
            }
        }

        // Trigger chain quest if conditions met
        if shouldTriggerChain {
            completeQuestIfNeeded(id: chainQuestId)
        }

        syncQuestProgress()
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

    func seedWeeklyQuestsIfNeeded() {
        let weeklyBoardTargetCount = 10
        let weeklyMaxTimerQuests = 3
        let weeklyMinHealthBarQuests = 3
        let weeklyMinMetaQuests = 2

        let completedIDs = Set(userDefaults.stringArray(forKey: weeklyCompletionKey) ?? [])
        let pool = Self.activeWeeklyQuestPool
        let poolByID = Dictionary(uniqueKeysWithValues: pool.map { ($0.id, $0) })

        if let activeIDs = userDefaults.stringArray(forKey: weeklyActiveKey) {
            let quests: [Quest] = activeIDs.compactMap { id in
                guard let definition = poolByID[id] else { return nil }
                assert(definition.completionMode == .automatic, "Generator should never surface manualDebug quest \(definition.id)")
                return Quest(definition: definition, isCompleted: completedIDs.contains(id))
            }

            if !quests.isEmpty {
                weeklyQuests = quests
                userDefaults.set(weeklyQuests.map { $0.id }, forKey: weeklyActiveKey)
                persistWeeklyCompletions()
                return
            }
        }

        var selectedIDs: [String] = []

        for coreID in QuestCatalog.coreWeeklyQuestIDs where selectedIDs.count < weeklyBoardTargetCount {
            guard poolByID[coreID] != nil else { continue }
            selectedIDs.append(coreID)
        }

        func categoryCount(_ category: QuestCategory) -> Int {
            selectedIDs.compactMap { poolByID[$0] }.filter { $0.category == category }.count
        }

        func addQuests(from definitions: [QuestDefinition], upTo minimum: Int) {
            for definition in definitions.shuffled() {
                guard selectedIDs.count < weeklyBoardTargetCount else { return }
                guard categoryCount(definition.category) < minimum else { continue }
                selectedIDs.append(definition.id)
            }
        }

        let remainingPool = pool.filter { !selectedIDs.contains($0.id) }
        let healthBarPool = remainingPool.filter { $0.category == .healthBar }
        let metaPool = remainingPool.filter { $0.category == .meta }

        addQuests(from: healthBarPool, upTo: weeklyMinHealthBarQuests)
        addQuests(from: metaPool, upTo: weeklyMinMetaQuests)

        var timerCount = categoryCount(.timer)
        let finalPool = pool.filter { !selectedIDs.contains($0.id) }.shuffled()

        for definition in finalPool {
            guard selectedIDs.count < weeklyBoardTargetCount else { break }
            if definition.category == .timer && timerCount >= weeklyMaxTimerQuests {
                continue
            }

            selectedIDs.append(definition.id)
            if definition.category == .timer {
                timerCount += 1
            }
        }

        let quests: [Quest] = selectedIDs.compactMap { id in
            guard let definition = poolByID[id] else { return nil }
            assert(definition.completionMode == .automatic, "Generator should never surface manualDebug quest \(definition.id)")
            return Quest(definition: definition, isCompleted: completedIDs.contains(id))
        }

        weeklyQuests = quests
        userDefaults.set(weeklyQuests.map { $0.id }, forKey: weeklyActiveKey)
        persistWeeklyCompletions()
    }

    func persistWeeklyCompletions() {
        let completed = weeklyQuests.filter { $0.isCompleted }.map { $0.id }
        userDefaults.set(completed, forKey: weeklyCompletionKey)
    }

    func registerHydrationGoalDayIfNeeded(today: Date = Date()) {
        let startOfDay = calendar.startOfDay(for: today)
        guard !hydrationGoalDaysThisWeek.contains(startOfDay) else { return }

        hydrationGoalDaysThisWeek.insert(startOfDay)
        persistHydrationGoalDays()
        updateWeeklyHydrationQuestCompletion()
        updateBalancedBarProgress()

        syncQuestProgress()
    }

    func updateWeeklyHydrationQuestCompletion() {
        let count = hydrationGoalDaysThisWeek.count
        if count >= Self.weeklyHydrationGoalTarget {
            completeWeeklyQuestIfNeeded(id: "weekly-hydration-hero")
            completeWeeklyQuestIfNeeded(id: "WEEK_HYDRATION_HERO_PLUS")
        }

        if count >= 6 {
            completeWeeklyQuestIfNeeded(id: "WEEK_HYDRATION_DEMON")
        }
    }

    func updateWeeklyHPQuestCompletion() {
        let hpDays = hpCheckinDaysThisWeek.count
        if hpDays >= Self.weeklyHPCheckinTarget {
            completeWeeklyQuestIfNeeded(id: "weekly-health-check")
        }

        if hpDays >= 5 {
            completeWeeklyQuestIfNeeded(id: "WEEK_MOOD_TRACKER")
            completeWeeklyQuestIfNeeded(id: "WEEK_SLEEP_SENTINEL")
        }

        updateBalancedBarProgress()
    }

    func updateBalancedBarProgress() {
        let balancedDays = hydrationGoalDaysThisWeek.intersection(hpCheckinDaysThisWeek)
        if balancedDays.count >= 3 {
            completeWeeklyQuestIfNeeded(id: "WEEK_BALANCED_BAR")
        }
    }

    func registerHPCheckinDayIfNeeded(today: Date = Date()) {
        let startOfDay = calendar.startOfDay(for: today)
        guard !hpCheckinDaysThisWeek.contains(startOfDay) else { return }

        hpCheckinDaysThisWeek.insert(startOfDay)
        persistHPCheckinDays()
        updateWeeklyHPQuestCompletion()
        updateBalancedBarProgress()

        syncQuestProgress()
    }

    func completeWeeklyFocusMinuteQuestsIfNeeded() {
        guard statsStore.totalFocusMinutesThisWeek >= Self.weeklyFocusMinutesTarget else { return }
        completeWeeklyQuestIfNeeded(id: "weekly-focus-marathon")

        syncQuestProgress()
    }

    func completeWeeklyFocusSessionQuestsIfNeeded() {
        guard statsStore.totalFocusSessionsThisWeek >= Self.weeklyFocusSessionTarget else { return }
        completeWeeklyQuestIfNeeded(id: "weekly-session-grinder")

        syncQuestProgress()
    }

    func dailyQuestCompletionCountsThisWeek() -> [Date: Int] {
        guard let startOfWeek = calendar.date(from: calendar.dateComponents([.weekOfYear, .yearForWeekOfYear], from: dayReference)) else {
            return [:]
        }

        var counts: [Date: Int] = [:]
        for offset in 0..<7 {
            guard let date = calendar.date(byAdding: .day, value: offset, to: startOfWeek) else { continue }
            let dayStart = calendar.startOfDay(for: date)
            if calendar.isDate(dayStart, inSameDayAs: dayReference) {
                counts[dayStart] = dailyQuests.filter { $0.isCompleted }.count
            } else {
                counts[dayStart] = Self.completedQuestIDs(for: dayStart, calendar: calendar, userDefaults: userDefaults).count
            }
        }

        return counts
    }

    func dailyQuestCompletionsThisWeek() -> Int {
        dailyQuestCompletionCountsThisWeek().values.reduce(0, +)
    }

    func updateWeeklyDailyQuestCompletionProgress() {
        let completionCounts = dailyQuestCompletionCountsThisWeek()
        if dailyQuestCompletionsThisWeek() >= Self.weeklyDailyQuestCompletionTarget {
            completeWeeklyQuestIfNeeded(id: "weekly-daily-quest-slayer")
            completeWeeklyQuestIfNeeded(id: "WEEK_QUEST_FINISHER")
        }

        let daysMeetingThreshold = completionCounts.values.filter { $0 >= 4 }.count
        if daysMeetingThreshold >= 3 {
            completeWeeklyQuestIfNeeded(id: "WEEK_THREE_GOOD_DAYS")
        }

        updateWeekendWarriorProgress()

        syncQuestProgress()
    }

    func updateWeekendWarriorProgress() {
        let completionCounts = dailyQuestCompletionCountsThisWeek()
        for (date, count) in completionCounts where calendar.isDateInWeekend(date) {
            if count >= 2 && weekendTimerDays.contains(date) {
                completeWeeklyQuestIfNeeded(id: "WEEK_WEEKEND_WARRIOR")
                return
            }
        }

        syncQuestProgress()
    }

    func completeWeeklyQuestIfNeeded(id: String) {
        guard let index = weeklyQuests.firstIndex(where: { $0.id == id }) else { return }
        guard !weeklyQuests[index].isCompleted else { return }

        weeklyQuests[index].isCompleted = true
        statsStore.registerQuestCompleted(id: weeklyQuests[index].id, xp: weeklyQuests[index].xpReward)
        persistWeeklyCompletions()

        // Defer sync to next runloop tick so any state updates (counters/sets) settle before recomputing progress.
        DispatchQueue.main.async { [weak self] in
            self?.syncQuestProgress()
        }
    }

    func loadHydrationGoalDays() {
        let stored = userDefaults.array(forKey: hydrationGoalDaysKey) as? [TimeInterval] ?? []
        hydrationGoalDaysThisWeek = Set(stored.map { Date(timeIntervalSince1970: $0) })
    }

    func loadHPCheckinDays() {
        let stored = userDefaults.array(forKey: hpCheckinDaysKey) as? [TimeInterval] ?? []
        let combined = Set(stored.map { Date(timeIntervalSince1970: $0) })

        hpCheckinDaysThisWeek = combined
        persistHPCheckinDays()
    }

    func loadWeeklyTimerProgress() {
        weeklyWorkTimerCount = userDefaults.integer(forKey: workTimerCountKey)
        weeklyWorkMinutes = userDefaults.integer(forKey: workMinutesKey)
        weeklyChoresMinutes = userDefaults.integer(forKey: choresMinutesKey)
    }

    func loadSelfCareDays() {
        let stored = userDefaults.array(forKey: selfCareDaysKey) as? [TimeInterval] ?? []
        weeklySelfCareDays = Set(stored.map { Date(timeIntervalSince1970: $0) })
    }

    func loadEveningResetDays() {
        let stored = userDefaults.array(forKey: eveningResetDaysKey) as? [TimeInterval] ?? []
        weeklyEveningResetDays = Set(stored.map { Date(timeIntervalSince1970: $0) })
    }

    func loadDailySetupDays() {
        let stored = userDefaults.array(forKey: dailySetupDaysKey) as? [TimeInterval] ?? []
        weeklyDailySetupDays = Set(stored.map { Date(timeIntervalSince1970: $0) })
    }

    func loadWeekendTimerDays() {
        let stored = userDefaults.array(forKey: weekendTimerDaysKey) as? [TimeInterval] ?? []
        weekendTimerDays = Set(stored.map { Date(timeIntervalSince1970: $0) })
    }

    func weeklyProgress(for quest: Quest) -> (progress: Int, target: Int) {
        let current: (progress: Int, target: Int) = {
            switch quest.id {
            case "weekly-hydration-hero":
                return (hydrationGoalDaysThisWeek.count, Self.weeklyHydrationGoalTarget)
            case "WEEK_HYDRATION_HERO_PLUS":
                return (hydrationGoalDaysThisWeek.count, Self.weeklyHydrationGoalTarget)
            case "WEEK_HYDRATION_DEMON":
                return (hydrationGoalDaysThisWeek.count, 6)
            case "weekly-health-check":
                return (hpCheckinDaysThisWeek.count, Self.weeklyHPCheckinTarget)
            case "WEEK_MOOD_TRACKER":
                return (hpCheckinDaysThisWeek.count, 5)
            case "WEEK_SLEEP_SENTINEL":
                return (hpCheckinDaysThisWeek.count, 5)
            case "WEEK_BALANCED_BAR":
                return (balancedDaysCount, 3)
            case "weekly-focus-marathon":
                return (statsStore.totalFocusMinutesThisWeek, Self.weeklyFocusMinutesTarget)
            case "weekly-session-grinder":
                return (statsStore.totalFocusSessionsThisWeek, Self.weeklyFocusSessionTarget)
            case "weekly-daily-quest-slayer", "WEEK_QUEST_FINISHER":
                return (dailyQuestCompletionsThisWeek(), Self.weeklyDailyQuestCompletionTarget)
            case "WEEK_MINI_BOSS":
                return (weeklyHardQuestCount, 3)
            case "WEEK_THREE_GOOD_DAYS":
                return (threeGoodDaysCount, 3)
            case "WEEK_WEEKEND_WARRIOR":
                return (weekendWarriorAchieved ? 1 : 0, 1)
            case "WEEK_WORK_WARRIOR":
                return (weeklyWorkTimerCount, 5)
            case "WEEK_DEEP_WORK":
                return (weeklyWorkMinutes, 200)
            case "WEEK_CLUTTER_CRUSHER":
                return (weeklyChoresMinutes, 90)
            case "WEEK_SELFCARE_CHAMPION":
                return (weeklySelfCareDays.count, 4)
            case "WEEK_EVENING_RESET":
                return (weeklyEveningResetDays.count, 3)
            case "WEEK_DAILY_SETUP_STREAK":
                return (weeklyDailySetupDays.count, 5)
            default:
                return (quest.isCompleted ? 1 : 0, 1)
            }
        }()

        let normalizedProgress = quest.isCompleted ? max(current.progress, current.target) : current.progress
        return (normalizedProgress, current.target)
    }

    var balancedDaysCount: Int {
        hydrationGoalDaysThisWeek.intersection(hpCheckinDaysThisWeek).count
    }

    var threeGoodDaysCount: Int {
        dailyQuestCompletionCountsThisWeek().values.filter { $0 >= 4 }.count
    }

    var weekendWarriorAchieved: Bool {
        let completionCounts = dailyQuestCompletionCountsThisWeek()
        for (date, count) in completionCounts where calendar.isDateInWeekend(date) {
            if count >= 2 && weekendTimerDays.contains(date) {
                return true
            }
        }
        return false
    }

    func questInstance(from quest: Quest) -> QuestInstance {
        QuestInstance(
            definitionId: quest.id,
            createdAt: dayReference,
            status: quest.status,
            progress: quest.progress,
            target: quest.target
        )
    }

    func persistHydrationGoalDays() {
        let intervals = hydrationGoalDaysThisWeek.map { $0.timeIntervalSince1970 }
        userDefaults.set(intervals, forKey: hydrationGoalDaysKey)
    }

    func persistHPCheckinDays() {
        let intervals = hpCheckinDaysThisWeek.map { $0.timeIntervalSince1970 }
        userDefaults.set(intervals, forKey: hpCheckinDaysKey)
    }

    func persistWeeklyTimerProgress() {
        userDefaults.set(weeklyWorkTimerCount, forKey: workTimerCountKey)
        userDefaults.set(weeklyWorkMinutes, forKey: workMinutesKey)
        userDefaults.set(weeklyChoresMinutes, forKey: choresMinutesKey)
    }

    func persistSelfCareDays() {
        let intervals = weeklySelfCareDays.map { $0.timeIntervalSince1970 }
        userDefaults.set(intervals, forKey: selfCareDaysKey)
    }

    func persistEveningResetDays() {
        let intervals = weeklyEveningResetDays.map { $0.timeIntervalSince1970 }
        userDefaults.set(intervals, forKey: eveningResetDaysKey)
    }

    func persistDailySetupDays() {
        let intervals = weeklyDailySetupDays.map { $0.timeIntervalSince1970 }
        userDefaults.set(intervals, forKey: dailySetupDaysKey)
    }

    func persistWeekendTimerDays() {
        let intervals = weekendTimerDays.map { $0.timeIntervalSince1970 }
        userDefaults.set(intervals, forKey: weekendTimerDaysKey)
    }

    func persistHardQuestCount() {
        userDefaults.set(weeklyHardQuestCount, forKey: hardQuestCountKey)
    }

    static func dateKey(for date: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let year = components.year ?? 0
        let month = components.month ?? 0
        let day = components.day ?? 0
        return String(format: "quests-%04d-%02d-%02d", year, month, day)
    }

    static let requiredQuestIDs: [String] = []
    static let preferredQuestIDs: [String] = []
    static let nonRerollableQuestIDs: Set<String> = []  // Changed to empty set

    static let weeklyHydrationGoalTarget = 4
    static let weeklyHPCheckinTarget = 4
    static let weeklyDailyQuestCompletionTarget = 20
    static let weeklyFocusMinutesTarget = 120
    static let weeklyFocusSessionTarget = 15
    
    func isMysteryQuest(_ quest: Quest) -> Bool {
        return quest.id == mysteryQuestID
    }
    
    // Expose hint accessor for UI convenience
    func hint(for quest: Quest) -> String? { dailyHints[quest.id] }
}

