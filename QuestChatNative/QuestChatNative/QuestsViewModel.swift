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
    @Published var dailyQuests: [Quest] = []
    @Published var weeklyQuests: [Quest] = []
    @Published private(set) var hasUsedRerollToday: Bool = false
    @Published var hasQuestChestReady: Bool = false

    private let statsStore: SessionStatsStore
    private let questEngine: QuestEngine
    private let userDefaults: UserDefaults
    private let calendar: Calendar
    private let dayReference: Date
    private let eventDrivenQuestIDs: Set<String> = [
        "daily-checkin",
        "plan-focus-session",
        "finish-focus-session",
        "healthbar-checkin",
        "chore-blitz",
        "hydrate-checkpoint",
        "hydration-goal",
        "focus-25-min",
        "LOAD_QUEST_LOG",
        "DAILY_TIMER_QUICK_WORK",
        "DAILY_TIMER_DEEP_WORK",
        "DAILY_TIMER_CHORES_BURST",
        "DAILY_TIMER_HOME_RESET",
        "DAILY_TIMER_SELF_CARE",
        "DAILY_TIMER_MINDFUL_BREAK",
        "DAILY_TIMER_FOCUS_CHAIN",
        "DAILY_TIMER_EVENING_RESET",
        "DAILY_TIMER_BOSS_BATTLE",
        "DAILY_TIMER_CHILL_CHOICE",
        "DAILY_HB_MORNING_CHECKIN",
        "DAILY_HB_SLEEP_LOG",
        "DAILY_HB_FIRST_POTION",
        "DAILY_HB_HYDRATION_COMPLETE",
        "DAILY_HB_GENTLE_MOVEMENT",
        "DAILY_HB_GUT_CHECK",
        "DAILY_META_SETUP_COMPLETE",
        "DAILY_META_STATS_TODAY",
        "DAILY_META_REVIEW_YESTERDAY",
        "DAILY_EASY_TINY_TIDY",
        "DAILY_EASY_ONE_NICE_THING",
    ]
    private let weeklyEventDrivenQuestIDs: Set<String> = [
        "weekly-hydration-hero",
        "weekly-focus-marathon",
        "weekly-session-grinder",
        "weekly-daily-quest-slayer",
        "weekly-health-check",
        "WEEK_WORK_WARRIOR",
        "WEEK_DEEP_WORK",
        "WEEK_CLUTTER_CRUSHER",
        "WEEK_SELFCARE_CHAMPION",
        "WEEK_EVENING_RESET",
        "WEEK_HYDRATION_HERO_PLUS",
        "WEEK_HYDRATION_DEMON",
        "WEEK_MOOD_TRACKER",
        "WEEK_SLEEP_SENTINEL",
        "WEEK_BALANCED_BAR",
        "WEEK_DAILY_SETUP_STREAK",
        "WEEK_QUEST_FINISHER",
        "WEEK_MINI_BOSS",
        "WEEK_THREE_GOOD_DAYS",
        "WEEK_WEEKEND_WARRIOR",
    ]
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
        dailyQuests = Self.seedQuests(with: completedQuestIDs(for: dayReference, calendar: calendar, userDefaults: userDefaults))
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
        statsStore.updateDailyQuestsCompleted(completedQuestsCount)

        syncQuestProgress()
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
        guard !eventDrivenQuestIDs.contains(quest.id) else { return }
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
        statsStore.updateDailyQuestsCompleted(completedQuestsCount)

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
            completeQuestIfNeeded(id: "daily-checkin")
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
            completeQuestIfNeeded(id: "healthbar-checkin")
            completeQuestIfNeeded(id: "DAILY_HB_MORNING_CHECKIN")
            completeQuestIfNeeded(id: "DAILY_HB_GUT_CHECK")
            completeQuestIfNeeded(id: "DAILY_HB_SLEEP_LOG")
            registerHPCheckinDayIfNeeded()
        case .hydrationIntakeLogged(let totalOuncesToday):
            guard totalOuncesToday > 0 else { return }
            completeQuestIfNeeded(id: "hydrate-checkpoint")
            completeQuestIfNeeded(id: "DAILY_HB_FIRST_POTION")
        case .hydrationGoalReached:
            completeQuestIfNeeded(id: "hydration-goal")
            completeQuestIfNeeded(id: "DAILY_HB_HYDRATION_COMPLETE")
            registerHydrationGoalDayIfNeeded()
        case .hydrationGoalDayCompleted:
            registerHydrationGoalDayIfNeeded()
        case .dailySetupCompleted:
            completeQuestIfNeeded(id: "DAILY_META_SETUP_COMPLETE")
            registerDailySetupDay()
        case .statsViewed(let scope):
            switch scope {
            case .today:
                completeQuestIfNeeded(id: "DAILY_META_STATS_TODAY")
            case .yesterday:
                completeQuestIfNeeded(id: "DAILY_META_REVIEW_YESTERDAY")
            }
        }

        syncQuestProgress()
    }

    func handleQuestLogOpenedIfNeeded() {
        guard !userDefaults.bool(forKey: questLogOpenedKey) else { return }
        userDefaults.set(true, forKey: questLogOpenedKey)
        handleQuestEvent(.questsTabOpened)
    }

    func syncQuestProgress() {
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
    }

    func isEventDrivenQuest(_ quest: Quest) -> Bool {
        eventDrivenQuestIDs.contains(quest.id)
    }

    func isEventDrivenWeeklyQuest(_ quest: Quest) -> Bool {
        weeklyEventDrivenQuestIDs.contains(quest.id)
    }

    func toggleWeeklyQuest(_ quest: Quest) {
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
        guard !hasUsedRerollToday else { return }
        guard !quest.isCompleted else { return }
        guard !Self.nonRerollableQuestIDs.contains(quest.id) else { return }
        guard let index = dailyQuests.firstIndex(where: { $0.id == quest.id }) else { return }

        let currentIDs = Set(dailyQuests.map { $0.id })
        let completedToday = completedQuestIDs(for: dayReference, calendar: calendar, userDefaults: userDefaults)
        let currentDefinitions = dailyQuests.map { $0.definition }

        let preferredPool = Self.activeDailyQuestPool.filter { candidate in
            candidate.id != quest.id &&
                !currentIDs.contains(candidate.id) &&
                !completedToday.contains(candidate.id) &&
                !Self.nonRerollableQuestIDs.contains(candidate.id) &&
                candidate.category == quest.category &&
                candidate.difficulty == quest.difficulty
        }

        let fallbackPool = Self.activeDailyQuestPool.filter { candidate in
            candidate.id != quest.id &&
                !currentIDs.contains(candidate.id) &&
                !completedToday.contains(candidate.id) &&
                !Self.nonRerollableQuestIDs.contains(candidate.id)
        }

        let replacementCandidates = preferredPool.isEmpty ? fallbackPool : preferredPool

        guard let newDefinition = replacementCandidates.first(where: { candidate in
            var updatedDefinitions = currentDefinitions
            updatedDefinitions[index] = candidate
            return Self.meetsDailyBoardRules(definitions: updatedDefinitions)
        }) else { return }

        dailyQuests[index] = Quest(
            definition: newDefinition,
            isCompleted: false,
            isCoreToday: false
        )

        hasUsedRerollToday = true
        userDefaults.set(true, forKey: rerollKey)
        persistCompletions()

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

private extension QuestsViewModel {
    static let questChestBonusXP = 50

    static let desiredDailyQuestCount = 5
    static let maxTimerQuests = 2

    static var activeDailyQuestPool: [QuestDefinition] {
        QuestCatalog.allDailyQuests.filter { !disabledDailyQuestIDs.contains($0.id) }
    }

    static var activeWeeklyQuestPool: [QuestDefinition] {
        QuestCatalog.allWeeklyQuests.filter { !disabledWeeklyQuestIDs.contains($0.id) }
    }

    static let coreQuestIDs: [FocusArea: [String]] = [
        .work: ["daily-checkin", "plan-focus-session", "healthbar-checkin", "finish-focus-session", "chore-blitz"],
        .selfCare: ["daily-checkin", "plan-focus-session", "healthbar-checkin", "finish-focus-session", "quick-self-care"],
        .chill: ["daily-checkin", "plan-focus-session", "healthbar-checkin", "finish-focus-session", "step-outside"],
        .grind: ["daily-checkin", "plan-focus-session", "healthbar-checkin", "finish-focus-session", "chore-blitz"]
    ]

    static func seedQuests(with completedIDs: Set<String>) -> [Quest] {
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

        return selectedDefinitions.map { definition in
            Quest(
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

        if isWorkCategory(category) {
            if durationMinutes >= 15 { completeQuestIfNeeded(id: "DAILY_TIMER_QUICK_WORK") }
            if durationMinutes >= 40 { completeQuestIfNeeded(id: "DAILY_TIMER_DEEP_WORK") }
            if durationMinutes >= 60 { completeQuestIfNeeded(id: "DAILY_TIMER_BOSS_BATTLE") }
            registerWorkTimerProgress(durationMinutes: durationMinutes)
        }

        if isChoresCategory(category) {
            if durationMinutes >= 3 { completeQuestIfNeeded(id: "DAILY_EASY_TINY_TIDY") }
            if durationMinutes >= 10 { completeQuestIfNeeded(id: "DAILY_TIMER_CHORES_BURST") }
            if durationMinutes >= 25 { completeQuestIfNeeded(id: "DAILY_TIMER_HOME_RESET") }
            registerChoresProgress(durationMinutes: durationMinutes)
        }

        if isSelfCareCategory(category) {
            if durationMinutes >= 5 { completeQuestIfNeeded(id: "DAILY_HB_GENTLE_MOVEMENT") }
            if durationMinutes >= 10 { completeQuestIfNeeded(id: "DAILY_TIMER_MINDFUL_BREAK") }
            if durationMinutes >= 20 { completeQuestIfNeeded(id: "DAILY_TIMER_SELF_CARE") }
            registerSelfCareDayIfNeeded(date: startOfDay, durationMinutes: durationMinutes)
        }

        if isChillCategory(category) {
            if durationMinutes >= 20 { completeQuestIfNeeded(id: "DAILY_TIMER_CHILL_CHOICE") }
        }

        if !isChillCategory(category) && durationMinutes >= 20 {
            completeQuestIfNeeded(id: "DAILY_TIMER_FOCUS_CHAIN")
        }

        if durationMinutes >= 5 {
            completeQuestIfNeeded(id: "DAILY_EASY_ONE_NICE_THING")
        }

        if (isChoresCategory(category) || isSelfCareCategory(category)) && durationMinutes >= 15 {
            if calendar.component(.hour, from: endedAt) >= 18 {
                completeQuestIfNeeded(id: "DAILY_TIMER_EVENING_RESET")
                registerEveningResetDayIfNeeded(date: startOfDay)
            }
        }

        registerWeekendTimerIfNeeded(durationMinutes: durationMinutes, date: startOfDay)
    }

    func isWorkCategory(_ category: TimerCategory.Kind) -> Bool { category == .workSprint || category == .deepFocus }
    func isChoresCategory(_ category: TimerCategory.Kind) -> Bool { category == .choresSprint }
    func isSelfCareCategory(_ category: TimerCategory.Kind) -> Bool { category == .selfCare || category == .quickBreak }
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

    func completedQuestIDs(for date: Date, calendar: Calendar, userDefaults: UserDefaults) -> Set<String> {
        let key = Self.dateKey(for: date, calendar: calendar)
        return Set(userDefaults.stringArray(forKey: key) ?? [])
    }

    func completeQuestIfNeeded(id: String) {
        guard let index = dailyQuests.firstIndex(where: { $0.id == id }) else { return }
        guard !dailyQuests[index].isCompleted else { return }

        dailyQuests[index].isCompleted = true
        statsStore.registerQuestCompleted(id: dailyQuests[index].id, xp: dailyQuests[index].xpReward)
        trackHardQuestCompletion(for: dailyQuests[index])
        updateWeeklyDailyQuestCompletionProgress()

        persistCompletions()
        checkQuestChestRewardIfNeeded()
        statsStore.updateDailyQuestsCompleted(completedQuestsCount)

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
        let completedIDs = Set(userDefaults.stringArray(forKey: weeklyCompletionKey) ?? [])
        let poolByID = Dictionary(uniqueKeysWithValues: Self.activeWeeklyQuestPool.map { ($0.id, $0) })

        let activeIDs = userDefaults.stringArray(forKey: weeklyActiveKey) ?? Array(poolByID.keys)
        var quests: [Quest] = activeIDs.compactMap { id in
            guard let definition = poolByID[id] else { return nil }
            return Quest(definition: definition, isCompleted: completedIDs.contains(id))
        }

        if quests.isEmpty {
            quests = Self.activeWeeklyQuestPool.map { Quest(definition: $0, isCompleted: completedIDs.contains($0.id)) }
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
                counts[dayStart] = completedQuestIDs(for: dayStart, calendar: calendar, userDefaults: userDefaults).count
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

        syncQuestProgress()
    }

    func loadHydrationGoalDays() {
        let stored = userDefaults.array(forKey: hydrationGoalDaysKey) as? [TimeInterval] ?? []
        hydrationGoalDaysThisWeek = Set(stored.map { Date(timeIntervalSince1970: $0) })
    }

    func loadHPCheckinDays() {
        let stored = userDefaults.array(forKey: hpCheckinDaysKey) as? [TimeInterval] ?? []
        var combined = Set(stored.map { Date(timeIntervalSince1970: $0) })

        if let startOfWeek = calendar.date(from: calendar.dateComponents([.weekOfYear, .yearForWeekOfYear], from: dayReference)) {
            for offset in 0..<7 {
                guard let date = calendar.date(byAdding: .day, value: offset, to: startOfWeek) else { continue }
                let completedIDs = completedQuestIDs(for: date, calendar: calendar, userDefaults: userDefaults)
                if completedIDs.contains("healthbar-checkin") {
                    combined.insert(date)
                }
            }
        }

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

    static let requiredQuestIDs: [String] = ["daily-checkin"]
    static let preferredQuestIDs: [String] = ["plan-focus-session", "healthbar-checkin"]
    static let nonRerollableQuestIDs: Set<String> = Set(requiredQuestIDs + preferredQuestIDs)

    static let weeklyHydrationGoalTarget = 4
    static let weeklyHPCheckinTarget = 4
    static let weeklyDailyQuestCompletionTarget = 20
    static let weeklyFocusMinutesTarget = 120
    static let weeklyFocusSessionTarget = 15
}

