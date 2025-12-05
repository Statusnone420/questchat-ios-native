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
    @Published var weeklyQuests: [Quest] = []
    @Published private(set) var hasUsedRerollToday: Bool = false
    @Published var hasQuestChestReady: Bool = false

    private let statsStore: SessionStatsStore
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
    ]
    private let weeklyEventDrivenQuestIDs: Set<String> = [
        "weekly-hydration-hero",
        "weekly-focus-marathon",
        "weekly-session-grinder",
        "weekly-daily-quest-slayer",
        "weekly-health-check",
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

    init(
        statsStore: SessionStatsStore = DependencyContainer.shared.sessionStatsStore,
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

        seedWeeklyQuestsIfNeeded()
        loadHydrationGoalDays()
        loadHPCheckinDays()
        updateWeeklyHydrationQuestCompletion()
        updateWeeklyHPQuestCompletion()
        updateWeeklyDailyQuestCompletionProgress()

        if let focusArea = statsStore.todayPlan?.focusArea, !statsStore.shouldShowDailySetup {
            markCoreQuests(for: focusArea)
        }

        statsStore.questEventHandler = { [weak self] event in
            self?.handleQuestEvent(event)
        }

        statsStore.emitQuestProgressSnapshot()
        statsStore.updateDailyQuestsCompleted(completedQuestsCount)
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
        }

        persistCompletions()
        checkQuestChestRewardIfNeeded()
        statsStore.updateDailyQuestsCompleted(completedQuestsCount)
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
        case .focusSessionStarted(let durationMinutes):
            guard durationMinutes >= 15 else { return }
            completeQuestIfNeeded(id: "plan-focus-session")
        case .focusSessionCompleted(let durationMinutes):
            guard durationMinutes >= 25 else { return }
            completeQuestIfNeeded(id: "finish-focus-session")
            completeWeeklyFocusSessionQuestsIfNeeded()
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
            registerHPCheckinDayIfNeeded()
        case .hydrationIntakeLogged(let totalOuncesToday):
            guard totalOuncesToday > 0 else { return }
            completeQuestIfNeeded(id: "hydrate-checkpoint")
        case .hydrationGoalReached:
            completeQuestIfNeeded(id: "hydration-goal")
            registerHydrationGoalDayIfNeeded()
        case .hydrationGoalDayCompleted:
            registerHydrationGoalDayIfNeeded()
        }
    }

    func handleQuestLogOpenedIfNeeded() {
        guard !userDefaults.bool(forKey: questLogOpenedKey) else { return }
        userDefaults.set(true, forKey: questLogOpenedKey)
        handleQuestEvent(.questsTabOpened)
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
        }

        persistWeeklyCompletions()
    }

    func reroll(quest: Quest) {
        guard !hasUsedRerollToday else { return }
        guard !quest.isCompleted else { return }
        guard !Self.nonRerollableQuestIDs.contains(quest.id) else { return }
        guard let index = dailyQuests.firstIndex(where: { $0.id == quest.id }) else { return }

        let currentIDs = Set(dailyQuests.map { $0.id })
        let completedToday = completedQuestIDs(for: dayReference, calendar: calendar, userDefaults: userDefaults)
        let availableReplacementQuests = Self.activeDailyQuestPool.filter { candidate in
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

        if let focusArea = statsStore.todayPlan?.focusArea, !statsStore.shouldShowDailySetup {
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

    static let desiredWeeklyQuestCount = 3

    static let questPool: [Quest] = [
        Quest(id: "daily-checkin", title: "Load today’s quest log", detail: "Open the quest log and decide what actually matters.", xpReward: 10, tier: .core, isCompleted: false),
        Quest(id: "plan-focus-session", title: "Plan one focus session", detail: "Start a focus timer that runs for at least 15 minutes today.", xpReward: 35, tier: .core, isCompleted: false),
        Quest(id: "healthbar-checkin", title: "HealthBar check-in", detail: "Update your mood, gut, and sleep before you go heads-down.", xpReward: 35, tier: .core, isCompleted: false),
        Quest(id: "chore-blitz", title: "Chore blitz", detail: "Run a Chores timer for at least 10 minutes to clear a small dungeon.", xpReward: 35, tier: .core, isCompleted: false),
        Quest(id: "finish-focus-session", title: "Finish one focus session", detail: "Complete a focus timer that lasts 25 minutes or longer.", xpReward: 35, tier: .habit, isCompleted: false),
        Quest(id: "focus-25-min", title: "Hit 25 focus minutes today", detail: "Accumulate at least 25 minutes of focus time.", xpReward: 60, tier: .bonus, isCompleted: false),
        Quest(id: "hydrate-checkpoint", title: "Hydrate checkpoint", detail: "Drink at least 16 oz of water before a session starts.", xpReward: 20, tier: .habit, isCompleted: false),
        Quest(id: "hydration-goal", title: "Hit your hydration goal today", detail: "Stay on top of water throughout the day.", xpReward: 60, tier: .bonus, isCompleted: false),
        Quest(id: "irl-patch", title: "IRL patch update", detail: "Stretch for 2 minutes and do a posture check.", xpReward: 20, tier: .habit, isCompleted: false),
        Quest(id: "tidy-spot", title: "Tidy one small area", detail: "Reset your desk, sink, or a small zone.", xpReward: 20, tier: .habit, isCompleted: false),
        Quest(id: "step-outside", title: "Step outside or change rooms", detail: "Move your body and reset your head for a few minutes.", xpReward: 20, tier: .habit, isCompleted: false),
        Quest(id: "quick-self-care", title: "Do one quick self-care check", detail: "Breathe, sip water, or take a bathroom break.", xpReward: 20, tier: .habit, isCompleted: false)
    ]
    // TODO: Reintroduce digital-cobweb once a reliable event source exists.

    static let weeklyQuestPool: [Quest] = [
        Quest(id: "weekly-focus-marathon", title: "Weekly focus marathon", detail: "Hit 120 focus minutes this week.", xpReward: 100, tier: .bonus, isCompleted: false),
        Quest(id: "weekly-session-grinder", title: "Session grinder", detail: "Complete 15 focus sessions this week.", xpReward: 100, tier: .bonus, isCompleted: false),
        Quest(id: "weekly-daily-quest-slayer", title: "Daily quest slayer", detail: "Complete 20 daily quests this week.", xpReward: 60, tier: .habit, isCompleted: false),
        Quest(id: "weekly-health-check", title: "Health check-in", detail: "Log mood, gut, and sleep on 4 days this week.", xpReward: 60, tier: .habit, isCompleted: false),
        Quest(id: "weekly-hydration-hero", title: "Hydration hero", detail: "Hit your hydration goal on 4 days this week.", xpReward: 60, tier: .habit, isCompleted: false),
        Quest(id: "weekly-digital-dust", title: "Digital dust buster", detail: "Clear a digital cobweb on 3 days this week.", xpReward: 60, tier: .habit, isCompleted: false)
    ]

    static var activeDailyQuestPool: [Quest] {
        questPool.filter { !disabledDailyQuestIDs.contains($0.id) }
    }

    static var activeWeeklyQuestPool: [Quest] {
        weeklyQuestPool.filter { !disabledWeeklyQuestIDs.contains($0.id) }
    }

    static let coreQuestIDs: [FocusArea: [String]] = [
        .work: ["daily-checkin", "plan-focus-session", "healthbar-checkin", "finish-focus-session", "chore-blitz"],
        .selfCare: ["daily-checkin", "plan-focus-session", "healthbar-checkin", "finish-focus-session", "quick-self-care"],
        .chill: ["daily-checkin", "plan-focus-session", "healthbar-checkin", "finish-focus-session", "step-outside"],
        .grind: ["daily-checkin", "plan-focus-session", "healthbar-checkin", "finish-focus-session", "chore-blitz"]
    ]

    static func seedQuests(with completedIDs: Set<String>) -> [Quest] {
        let poolByID = Dictionary(uniqueKeysWithValues: activeDailyQuestPool.map { ($0.id, $0) })

        var quests: [Quest] = requiredQuestIDs.compactMap { poolByID[$0] }

        for preferredID in preferredQuestIDs where quests.count < desiredDailyQuestCount {
            if !quests.contains(where: { $0.id == preferredID }), let quest = poolByID[preferredID] {
                quests.append(quest)
            }
        }

        let excludedIDs = Set(quests.map { $0.id })
        let remainingPool = activeDailyQuestPool.filter { !excludedIDs.contains($0.id) }
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

    func completeQuestIfNeeded(id: String) {
        guard let index = dailyQuests.firstIndex(where: { $0.id == id }) else { return }
        guard !dailyQuests[index].isCompleted else { return }

        dailyQuests[index].isCompleted = true
        statsStore.registerQuestCompleted(id: dailyQuests[index].id, xp: dailyQuests[index].xpReward)
        updateWeeklyDailyQuestCompletionProgress()

        persistCompletions()
        checkQuestChestRewardIfNeeded()
        statsStore.updateDailyQuestsCompleted(completedQuestsCount)
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

        if let storedActiveIDs = userDefaults.stringArray(forKey: weeklyActiveKey) {
            let storedQuests: [Quest] = storedActiveIDs.compactMap { id in
                guard var quest = poolByID[id] else { return nil }
                quest.isCompleted = completedIDs.contains(id)
                return quest
            }

            if !storedQuests.isEmpty {
                weeklyQuests = storedQuests
                persistWeeklyCompletions()
                return
            }
        }

        let selected = Array(Self.activeWeeklyQuestPool.shuffled().prefix(Self.desiredWeeklyQuestCount))
        weeklyQuests = selected.map { quest in
            var updated = quest
            updated.isCompleted = completedIDs.contains(quest.id)
            return updated
        }

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
    }

    func updateWeeklyHydrationQuestCompletion() {
        guard hydrationGoalDaysThisWeek.count >= Self.weeklyHydrationGoalTarget else { return }
        completeWeeklyQuestIfNeeded(id: "weekly-hydration-hero")
    }

    func updateWeeklyHPQuestCompletion() {
        guard hpCheckinDaysThisWeek.count >= Self.weeklyHPCheckinTarget else { return }
        completeWeeklyQuestIfNeeded(id: "weekly-health-check")
    }

    func registerHPCheckinDayIfNeeded(today: Date = Date()) {
        let startOfDay = calendar.startOfDay(for: today)
        guard !hpCheckinDaysThisWeek.contains(startOfDay) else { return }

        hpCheckinDaysThisWeek.insert(startOfDay)
        persistHPCheckinDays()
        updateWeeklyHPQuestCompletion()
    }

    func completeWeeklyFocusMinuteQuestsIfNeeded() {
        guard statsStore.totalFocusMinutesThisWeek >= Self.weeklyFocusMinutesTarget else { return }
        completeWeeklyQuestIfNeeded(id: "weekly-focus-marathon")
    }

    func completeWeeklyFocusSessionQuestsIfNeeded() {
        guard statsStore.totalFocusSessionsThisWeek >= Self.weeklyFocusSessionTarget else { return }
        completeWeeklyQuestIfNeeded(id: "weekly-session-grinder")
    }

    func dailyQuestCompletionsThisWeek() -> Int {
        guard let startOfWeek = calendar.date(from: calendar.dateComponents([.weekOfYear, .yearForWeekOfYear], from: dayReference)) else {
            return 0
        }

        return (0..<7).reduce(0) { total, offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: startOfWeek) else { return total }
            if calendar.isDate(date, inSameDayAs: dayReference) {
                return total + dailyQuests.filter { $0.isCompleted }.count
            }

            return total + completedQuestIDs(for: date, calendar: calendar, userDefaults: userDefaults).count
        }
    }

    func updateWeeklyDailyQuestCompletionProgress() {
        guard dailyQuestCompletionsThisWeek() >= Self.weeklyDailyQuestCompletionTarget else { return }
        completeWeeklyQuestIfNeeded(id: "weekly-daily-quest-slayer")
    }

    func completeWeeklyQuestIfNeeded(id: String) {
        guard let index = weeklyQuests.firstIndex(where: { $0.id == id }) else { return }
        guard !weeklyQuests[index].isCompleted else { return }

        weeklyQuests[index].isCompleted = true
        statsStore.registerQuestCompleted(id: weeklyQuests[index].id, xp: weeklyQuests[index].xpReward)
        persistWeeklyCompletions()
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

    func persistHydrationGoalDays() {
        let intervals = hydrationGoalDaysThisWeek.map { $0.timeIntervalSince1970 }
        userDefaults.set(intervals, forKey: hydrationGoalDaysKey)
    }

    func persistHPCheckinDays() {
        let intervals = hpCheckinDaysThisWeek.map { $0.timeIntervalSince1970 }
        userDefaults.set(intervals, forKey: hpCheckinDaysKey)
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
