import Foundation
import Combine
import SwiftUI
import UserNotifications
import UIKit
import ActivityKit

/// Represents available timer modes.
enum FocusTimerMode: String, CaseIterable, Identifiable, Codable {
    case focus
    case selfCare

    var id: String { rawValue }

    var title: String {
        switch self {
        case .focus: QuestChatStrings.FocusTimerModeTitles.focus
        case .selfCare: QuestChatStrings.FocusTimerModeTitles.selfCare
        }
    }

    /// Default duration in minutes for the timer mode.
    var defaultDurationMinutes: Int {
        switch self {
        case .focus: 25
        case .selfCare: 5
        }
    }

    var accentSystemImage: String {
        switch self {
        case .focus: "flame.fill"
        case .selfCare: "heart.fill"
        }
    }

}

typealias FocusSessionType = FocusTimerMode

struct FocusSession: Codable, Identifiable {
    let id: UUID
    let type: FocusSessionType
    let duration: TimeInterval
    let startDate: Date
    let category: TimerCategory.Kind?  // Added: track which specific timer was running

    var endDate: Date { startDate.addingTimeInterval(duration) }
}

enum SleepQuality: Int, CaseIterable, Identifiable {
    case awful
    case okay
    case great

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .awful:
            return "Awful"
        case .okay:
            return "Okay"
        case .great:
            return "Great"
        }
    }

    var hpModifier: Int {
        switch self {
        case .awful:
            return -15
        case .okay:
            return 0
        case .great:
            return 10
        }
    }

    var buffLabel: String? {
        switch self {
        case .great:
            return "Well-rested"
        case .okay, .awful:
            return nil
        }
    }

    var debuffLabel: String? {
        switch self {
        case .awful:
            return "Running on fumes"
        case .okay, .great:
            return nil
        }
    }
}

struct TimerCategory: Identifiable, Equatable {
    enum Kind: String, Codable {
        case create
        case focusMode
        case chores
        case selfCare
        case gamingReset
        case move

        var title: String {
            switch self {
            case .create:
                return QuestChatStrings.TimerCategories.createTitle
            case .focusMode:
                return QuestChatStrings.TimerCategories.focusModeTitle
            case .chores:
                return QuestChatStrings.TimerCategories.choresTitle
            case .selfCare:
                return QuestChatStrings.TimerCategories.selfCareTitle
            case .gamingReset:
                return QuestChatStrings.TimerCategories.gamingResetTitle
            case .move:
                return QuestChatStrings.TimerCategories.moveTitle
            }
        }

        var subtitle: String {
            switch self {
            case .create:
                return QuestChatStrings.TimerCategories.createSubtitle
            case .focusMode:
                return QuestChatStrings.TimerCategories.focusModeSubtitle
            case .chores:
                return QuestChatStrings.TimerCategories.choresSubtitle
            case .selfCare:
                return QuestChatStrings.TimerCategories.selfCareSubtitle
            case .gamingReset:
                return QuestChatStrings.TimerCategories.gamingResetSubtitle
            case .move:
                return QuestChatStrings.TimerCategories.moveSubtitle
            }
        }

        var mode: FocusTimerMode {
            switch self {
            case .create, .focusMode, .chores:
                return .focus
            case .selfCare, .gamingReset, .move:
                return .selfCare
            }
        }

        var systemImageName: String {
            switch self {
            case .create:
                return "brain.head.profile"
            case .focusMode:
                return "bolt.circle"
            case .chores:
                return "house.fill"
            case .selfCare:
                return "figure.mind.and.body"
            case .gamingReset:
                return "gamecontroller"
            case .move:
                return "figure.run"
            }
        }
    }

    let id: Kind
    var durationSeconds: Int
}

enum FocusArea: CaseIterable, Codable, Equatable, Identifiable, Hashable {
    case work
    case selfCare
    case chill
    case grind

    var id: String { displayName }

    var icon: String {
        switch self {
        case .work: return "laptopcomputer"
        case .selfCare: return "figure.cooldown"
        case .chill: return "waveform"
        case .grind: return "flame.fill"
        }
    }

    var displayName: String {
        switch self {
        case .work: return QuestChatStrings.FocusAreaTitles.work
        case .selfCare: return QuestChatStrings.FocusAreaTitles.selfCare
        case .chill: return QuestChatStrings.FocusAreaTitles.chill
        case .grind: return QuestChatStrings.FocusAreaTitles.grind
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        switch rawValue {
        case "work":
            self = .work
        case "selfCare", "selfcare", "health", "home":
            self = .selfCare
        case "chill":
            self = .chill
        case "grind":
            self = .grind
        default:
            self = .work
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .work: try container.encode("work")
        case .selfCare: try container.encode("selfCare")
        case .chill: try container.encode("chill")
        case .grind: try container.encode("grind")
        }
    }
}

struct DailyPlan: Codable, Equatable {
    let date: Date
    var focusArea: FocusArea
    var energyLevel: EnergyLevel
    var focusGoalMinutes: Int
}

struct DailyProgress: Codable, Equatable, Identifiable {
    let date: Date
    var questsCompleted: Int
    var focusMinutes: Int
    var reachedFocusGoal: Bool
    var totalQuests: Int?
    var focusGoalMinutes: Int?

    var id: Date { date }

    init(
        date: Date,
        questsCompleted: Int,
        focusMinutes: Int,
        reachedFocusGoal: Bool,
        totalQuests: Int? = nil,
        focusGoalMinutes: Int? = nil
    ) {
        self.date = date
        self.questsCompleted = questsCompleted
        self.focusMinutes = focusMinutes
        self.reachedFocusGoal = reachedFocusGoal
        self.totalQuests = totalQuests
        self.focusGoalMinutes = focusGoalMinutes
    }
}

enum EnergyLevel: String, CaseIterable, Identifiable, Codable {
    case low
    case medium
    case high

    var id: String { rawValue }

    var label: String {
        switch self {
        case .low: return "Low – 20 min"
        case .medium: return "Medium – 40 min"
        case .high: return "High – 60 min"
        }
    }

    var focusGoalMinutes: Int {
        switch self {
        case .low: return 20
        case .medium: return 40
        case .high: return 60
        }
    }

    var emoji: String {
        switch self {
        case .low: return "🌙"
        case .medium: return "🌤️"
        case .high: return "☀️"
        }
    }
}

/// Stores session stats and persists them in UserDefaults for now.
final class SessionStatsStore: ObservableObject {
    struct ProgressionState: Codable, Equatable {
        var level: Int                // legacy support
        var xpInCurrentLevel: Int     // legacy support
        var totalXP: Int              // legacy support
        var streakDays: Int
        var lastActiveDate: Date?
    }

    enum XPReason: Codable {
        case focusSession(minutes: Int)
        case questCompleted(id: String, xp: Int)
        case streakBonus
        case waterGoal
        case healthCombo
        case seasonAchievement(id: String, xp: Int)
    }

    struct LevelUpResult: Equatable {
        let oldLevel: Int
        let newLevel: Int
    }


    struct SessionRecord: Identifiable, Codable {
        let id: UUID
        let date: Date
        let modeRawValue: String
        let durationSeconds: Int
    }

    struct WeeklyGoalDayStatus: Identifiable {
        let date: Date
        let goalHit: Bool
        let isToday: Bool

        var id: Date { date }
    }

    enum MomentumTier {
        case cold      // 0 active days
        case warming   // 1–2 active days
        case rolling   // 3–5 active days
        case onFire    // 6–7 active days
    }

    @Published private(set) var focusSeconds: Int
    @Published private(set) var selfCareSeconds: Int
    @Published private(set) var sessionsCompleted: Int
    @Published private(set) var sessionHistory: [SessionRecord]
    @Published private(set) var totalFocusSecondsToday: Int
    @Published var pendingLevelUp: PendingLevelUp?
    @Published private(set) var dailyPlan: DailyPlan?
    @Published private(set) var dailyProgressHistory: [DailyProgress]
    @Published var shouldShowDailySetup: Bool = false
    @Published private(set) var lastWeeklyGoalBonusAwardedDate: Date?
    @Published private(set) var progression: ProgressionState
    @Published var lastLevelUp: LevelUpResult?

    private(set) var lastKnownLevel: Int

    private let playerStateStore: PlayerStateStore
    private let playerTitleStore: PlayerTitleStore
    private let talentTreeStore: TalentTreeStore
    private var playerCancellables = Set<AnyCancellable>()
    var questEventHandler: ((QuestEvent) -> Void)?

    var level: Int { progression.level }

    var totalXP: Int { progression.totalXP }

    var xpIntoCurrentLevel: Int { progression.xpInCurrentLevel }

    var xpForNextLevel: Int {
        let needed = xpNeededToLevelUp(from: level)
        return needed == Int.max ? 0 : max(0, needed - xpIntoCurrentLevel)
    }
    
    var xpTotalThisLevel: Int { xpIntoCurrentLevel + xpForNextLevel }

    var xp: Int { progression.totalXP }

    var playerTitle: String { levelTitle(for: level) }

    var focusSecondsToday: Int {
        todaySessions
            .filter { $0.modeRawValue == FocusTimerMode.focus.rawValue }
            .reduce(0) { $0 + $1.durationSeconds }
    }

    var selfCareSecondsToday: Int {
        todaySessions
            .filter { $0.modeRawValue == FocusTimerMode.selfCare.rawValue }
            .reduce(0) { $0 + $1.durationSeconds }
    }

    var statusLine: String {
        if currentStreakDays > 0 {
            return QuestChatStrings.StatusLines.streak(currentStreakDays)
        }

        return QuestChatStrings.StatusLines.xpEarned(totalXP)
    }

    var dailyMinutesGoal: Int? { dailyPlan?.focusGoalMinutes }

    var todayPlan: DailyPlan? {
        let today = Calendar.current.startOfDay(for: Date())
        guard let plan = dailyPlan, Calendar.current.isDate(plan.date, inSameDayAs: today) else { return nil }
        return plan
    }

    var todayProgress: DailyProgress? {
        let today = Calendar.current.startOfDay(for: Date())
        return dailyProgressHistory.first { Calendar.current.isDate($0.date, inSameDayAs: today) }
    }

    var dailyMinutesProgress: Int {
        totalFocusSecondsToday / 60
    }

    var focusSessionsToday: Int {
        todaySessions
            .filter { $0.modeRawValue == FocusTimerMode.focus.rawValue }
            .count
    }

    var totalFocusMinutesThisWeek: Int {
        focusSecondsThisWeek / 60
    }

    var totalFocusSessionsThisWeek: Int {
        focusSessionsThisWeek
    }

    init(
        userDefaults: UserDefaults = .standard,
        playerStateStore: PlayerStateStore,
        playerTitleStore: PlayerTitleStore,
        talentTreeStore: TalentTreeStore
    ) {
        self.userDefaults = userDefaults
        self.playerStateStore = playerStateStore
        self.playerTitleStore = playerTitleStore
        self.talentTreeStore = talentTreeStore
        focusSeconds = userDefaults.integer(forKey: Keys.focusSeconds)
        selfCareSeconds = userDefaults.integer(forKey: Keys.selfCareSeconds)
        sessionsCompleted = userDefaults.integer(forKey: Keys.sessionsCompleted)

        if
            let data = userDefaults.data(forKey: Keys.sessionHistory),
            let decoded = try? JSONDecoder().decode([SessionRecord].self, from: data)
        {
            sessionHistory = decoded
        } else {
            sessionHistory = []
        }

        let initialProgression: ProgressionState
        if let loadedProgression = Self.loadProgression(from: userDefaults) {
            initialProgression = loadedProgression
        } else {
            initialProgression = ProgressionState(
                level: 1,
                xpInCurrentLevel: 0,
                totalXP: 0,
                streakDays: 0,
                lastActiveDate: nil
            )
        }
        let initialTotalXP = initialProgression.totalXP > 0 ? initialProgression.totalXP : playerStateStore.xp
        let computedProgression = Self.computeProgression(totalXP: initialTotalXP, streakDays: initialProgression.streakDays, lastActiveDate: initialProgression.lastActiveDate)
        progression = computedProgression

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let storedDate = userDefaults.object(forKey: Keys.totalFocusDate) as? Date

        let initialTotalFocusSecondsToday: Int
        let needsDateReset: Bool
        if let storedDate, calendar.isDate(storedDate, inSameDayAs: today) {
            initialTotalFocusSecondsToday = userDefaults.integer(forKey: Keys.totalFocusSecondsToday)
            needsDateReset = false
        } else {
            initialTotalFocusSecondsToday = 0
            needsDateReset = true
        }
        totalFocusSecondsToday = initialTotalFocusSecondsToday

        let storedLevel = userDefaults.integer(forKey: Keys.lastKnownLevel)
        let initialLevel = computedProgression.level
        lastKnownLevel = storedLevel > 0 ? storedLevel : initialLevel
        pendingLevelUp = nil

        talentTreeStore.applyLevel(computedProgression.level)

        let storedPlan = Self.decodePlan(from: userDefaults.data(forKey: Keys.dailyPlan))
            ?? Self.decodeLegacyConfig(from: userDefaults.data(forKey: Keys.legacyDailyConfig))
        dailyPlan = storedPlan
        dailyProgressHistory = Self.decodeDailyProgress(from: userDefaults.data(forKey: Keys.dailyProgressHistory)) ?? []
        shouldShowDailySetup = !Self.isPlanValidForToday(storedPlan)

        lastWeeklyGoalBonusAwardedDate = userDefaults.object(forKey: Keys.lastWeeklyGoalBonusAwardedDate) as? Date

        // Now that all stored properties are initialized, persist any needed resets.
        if needsDateReset {
            userDefaults.set(today, forKey: Keys.totalFocusDate)
            userDefaults.set(totalFocusSecondsToday, forKey: Keys.totalFocusSecondsToday)
        } else {
            // Defensive: ensure keys exist even if they were missing but it's the same day.
            if userDefaults.object(forKey: Keys.totalFocusDate) == nil {
                userDefaults.set(today, forKey: Keys.totalFocusDate)
            }
            if userDefaults.object(forKey: Keys.totalFocusSecondsToday) == nil {
                userDefaults.set(totalFocusSecondsToday, forKey: Keys.totalFocusSecondsToday)
            }
        }

        refreshDailySetupIfNeeded()
        pruneDailyProgressHistory(referenceDate: today)
        updateDailyProgress(for: today, focusGoalMinutes: dailyPlan?.focusGoalMinutes)
        evaluateWeeklyGoalBonus()

        syncPlayerStateProgress()
        syncBaseLevelTitle()
    }

    @discardableResult
    func recordSession(mode: FocusTimerMode, duration: Int) -> Int {
        refreshDailyTotalsIfNeeded()

        let now = Date()
        let xpBefore = progression.totalXP

        switch mode {
        case .focus:
            focusSeconds += duration
            totalFocusSecondsToday += duration
        case .selfCare:
            selfCareSeconds += duration
        }

        sessionsCompleted += 1
        recordSessionHistory(mode: mode, duration: duration)

        let baseXP = xpForCompletedFocusSession(duration: TimeInterval(duration))
        let momentumMultiplier = momentumMultiplier(for: now)
        let boostedXP = Int(round(Double(baseXP) * momentumMultiplier))
        let minutes = Int(duration / 60)
        _ = grantXP(boostedXP, reason: .focusSession(minutes: minutes))

        if mode == .focus {
            updateDailyProgress(for: now, focusGoalMinutes: dailyPlan?.focusGoalMinutes)
        }

        persist()
        evaluateWeeklyGoalBonus()

        if mode == .focus {
            questEventHandler?(.focusMinutesUpdated(totalMinutesToday: totalFocusSecondsToday / 60))
            questEventHandler?(.focusSessionsUpdated(totalSessionsToday: focusSessionsToday))
        }
        return progression.totalXP - xpBefore
    }

    func emitQuestProgressSnapshot() {
        questEventHandler?(.focusMinutesUpdated(totalMinutesToday: totalFocusSecondsToday / 60))
        questEventHandler?(.focusSessionsUpdated(totalSessionsToday: focusSessionsToday))
    }

    func refreshDailyFocusTotal() {
        refreshDailyTotalsIfNeeded()
    }

    func deleteSessions(since date: Date) {
        let removedSessions = sessionHistory.filter { $0.date >= date }
        guard !removedSessions.isEmpty else { return }

        sessionHistory.removeAll { $0.date >= date }

        let focusReduction = removedSessions
            .filter { $0.modeRawValue == FocusTimerMode.focus.rawValue }
            .reduce(0) { $0 + $1.durationSeconds }
        let selfCareReduction = removedSessions
            .filter { $0.modeRawValue == FocusTimerMode.selfCare.rawValue }
            .reduce(0) { $0 + $1.durationSeconds }

        focusSeconds = max(0, focusSeconds - focusReduction)
        selfCareSeconds = max(0, selfCareSeconds - selfCareReduction)
        sessionsCompleted = max(0, sessionsCompleted - removedSessions.count)

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let focusRemovedToday = removedSessions
            .filter { calendar.isDate($0.date, inSameDayAs: today) && $0.modeRawValue == FocusTimerMode.focus.rawValue }
            .reduce(0) { $0 + $1.durationSeconds }
        totalFocusSecondsToday = max(0, totalFocusSecondsToday - focusRemovedToday)

        updateDailyProgress(for: today, focusGoalMinutes: dailyPlan?.focusGoalMinutes)

        persist()
    }

    func deleteXPEvents(since date: Date) {
        let impactedSessions = sessionHistory.filter { $0.date >= date }
        guard !impactedSessions.isEmpty else { return }

        let removedXP = impactedSessions.reduce(0) { partialResult, session in
            let duration = TimeInterval(session.durationSeconds)
            return partialResult + xpForCompletedFocusSession(duration: duration)
        }

        guard removedXP > 0 else { return }
        reduceTotalXP(by: removedXP)
    }

    func refreshDailySetupIfNeeded() {
        let today = Calendar.current.startOfDay(for: Date())
        let isValid = Self.isPlanValidForToday(dailyPlan, today: today)
        if !isValid {
            dailyPlan = nil
            persistDailyPlan(nil)
        }
        shouldShowDailySetup = !isValid
    }

    func completeDailyConfig(focusArea: FocusArea, energyLevel: EnergyLevel) {
        let today = Calendar.current.startOfDay(for: Date())
        let plan = DailyPlan(
            date: today,
            focusArea: focusArea,
            energyLevel: energyLevel,
            focusGoalMinutes: energyLevel.focusGoalMinutes
        )
        dailyPlan = plan
        shouldShowDailySetup = false
        persistDailyPlan(plan)
        updateDailyProgress(for: today, focusGoalMinutes: plan.focusGoalMinutes)
        questEventHandler?(.dailySetupCompleted)
    }

    func updateDailyQuestsCompleted(_ count: Int, totalQuests: Int? = nil, date: Date = Date()) {
        updateDailyProgress(
            for: date,
            focusGoalMinutes: dailyPlan?.focusGoalMinutes,
            questsCompleted: count,
            totalQuests: totalQuests
        )
    }

    func recordSessionHistory(mode: FocusTimerMode, duration: Int) {
        let newRecord = SessionRecord(
            id: UUID(),
            date: Date(),
            modeRawValue: mode.rawValue,
            durationSeconds: duration
        )
        sessionHistory.append(newRecord)
        if sessionHistory.count > 30 {
            sessionHistory = Array(sessionHistory.suffix(30))
        }
        persistSessionHistory()
    }

    @discardableResult
    func grantXP(_ amount: Int, reason: XPReason) -> LevelUpResult? {
        guard amount > 0 else { return nil }
        let previousLevel = level

        let newTotal = progression.totalXP + amount
        progression = recalculatedProgression(totalXP: newTotal, streakDays: progression.streakDays, lastActiveDate: progression.lastActiveDate)
        syncBaseLevelTitle()

        if level > previousLevel {
            let result = LevelUpResult(oldLevel: previousLevel, newLevel: level)
            lastLevelUp = result
            let tier = LevelUpTier.compute(oldLevel: previousLevel, newLevel: level)
            pendingLevelUp = PendingLevelUp(level: level, tier: tier)
        } else {
            lastLevelUp = nil
            pendingLevelUp = nil
        }
        lastKnownLevel = level
        syncTalentTreeLevel()
        syncPlayerStateProgress()
        persist()
        return lastLevelUp
    }

    func xpForCompletedFocusSession(duration: TimeInterval) -> Int {
        // Round down to whole minutes, but never less than 1
        let minutes = max(1, Int(duration / 60))

        // Base: roughly 1 XP per 2 minutes, min 1 XP
        var xp = max(1, minutes / 2)

        // Longer-focus bonuses
        if minutes >= 25 {
            xp += 3   // pomodoro-ish bonus
        }
        if minutes >= 45 {
            xp += 3   // deep-focus bonus
        }

        return xp
    }

    @discardableResult
    func registerCompletedSession(duration: TimeInterval) -> LevelUpResult? {
        let xpAward = xpForCompletedFocusSession(duration: duration)
        guard xpAward > 0 else { return nil }
        let minutes = Int(duration / 60)
        return grantXP(xpAward, reason: .focusSession(minutes: minutes))
    }

    @discardableResult
    func registerQuestCompleted(id: String, xp: Int) -> LevelUpResult? {
        guard xp > 0 else { return nil }
        return grantXP(xp, reason: .questCompleted(id: id, xp: xp))
    }

    @discardableResult
    func registerStreakBonus() -> LevelUpResult? {
        grantXP(20, reason: .streakBonus)
    }

    func registerActiveToday(date: Date = Date()) -> LevelUpResult? {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: date)

        if progression.lastActiveDate == nil {
            progression.lastActiveDate = today
            progression.streakDays = 1
        } else if let lastDate = progression.lastActiveDate {
            if calendar.isDate(lastDate, inSameDayAs: today) {
                // No change
            } else if let diff = calendar.dateComponents([.day], from: lastDate, to: today).day, diff == 1 {
                progression.streakDays += 1
                progression.lastActiveDate = today
                return registerStreakBonus()
            } else {
                progression.streakDays = 1
                progression.lastActiveDate = today
            }
        }

        saveProgression()
        persist()
        return nil
    }

    func resetAll() {
        focusSeconds = 0
        selfCareSeconds = 0
        sessionsCompleted = 0
        progression = ProgressionState(level: 1, xpInCurrentLevel: 0, totalXP: 0, streakDays: 0, lastActiveDate: nil)
        syncBaseLevelTitle()
        totalFocusSecondsToday = 0
        userDefaults.set(Calendar.current.startOfDay(for: Date()), forKey: Keys.totalFocusDate)
        lastKnownLevel = level
        pendingLevelUp = nil
        syncTalentTreeLevel()
        sessionHistory = []
        lastWeeklyGoalBonusAwardedDate = nil
        lastLevelUp = nil
        persist()
    }

    func xpNeededToLevelUp(from level: Int) -> Int {
        return 100
    }

    private func reduceTotalXP(by amount: Int) {
        let newTotal = max(0, progression.totalXP - amount)

        // Recompute level + xp in level from the new total XP
        progression = recalculatedProgression(
            totalXP: newTotal,
            streakDays: progression.streakDays,
            lastActiveDate: progression.lastActiveDate
        )
        syncBaseLevelTitle()

        // Removing XP should not trigger a level-up modal
        pendingLevelUp = nil
        lastLevelUp = nil

        // Keep player state in sync and persist
        syncTalentTreeLevel()
        syncPlayerStateProgress()
        saveProgression()
        persist()
    }

    private func levelTitle(for level: Int) -> String {
        switch level {
        case 1...4:
            return QuestChatStrings.PlayerTitles.rookie
        case 5...9:
            return QuestChatStrings.PlayerTitles.worker
        case 10...19:
            return QuestChatStrings.PlayerTitles.knight
        case 20...29:
            return QuestChatStrings.PlayerTitles.master
        default:
            return QuestChatStrings.PlayerTitles.sage
        }
    }

    private func syncBaseLevelTitle() {
        playerTitleStore.updateBaseLevelTitle(levelTitle(for: level))
    }

    private static func computeProgression(totalXP: Int, streakDays: Int, lastActiveDate: Date?) -> ProgressionState {
        let normalizedTotal = max(0, totalXP)
        let computedLevel = (normalizedTotal / 100) + 1
        let xpIntoLevel = normalizedTotal % 100
        return ProgressionState(
            level: computedLevel,
            xpInCurrentLevel: xpIntoLevel,
            totalXP: normalizedTotal,
            streakDays: streakDays,
            lastActiveDate: lastActiveDate
        )
    }

    private func recalculatedProgression(totalXP: Int, streakDays: Int, lastActiveDate: Date?) -> ProgressionState {
        let normalizedTotal = max(0, totalXP)
        let computedLevel = (normalizedTotal / 100) + 1
        let xpIntoLevel = normalizedTotal % 100
        return ProgressionState(
            level: computedLevel,
            xpInCurrentLevel: xpIntoLevel,
            totalXP: normalizedTotal,
            streakDays: streakDays,
            lastActiveDate: lastActiveDate
        )
    }

    private func syncTalentTreeLevel() {
        talentTreeStore.applyLevel(level)
    }

    private func syncPlayerStateProgress() {
        playerStateStore.xp = progression.totalXP
        playerStateStore.level = progression.level
        playerStateStore.pendingLevelUp = pendingLevelUp
    }

    private func saveProgression() {
        if let data = try? JSONEncoder().encode(progression) {
            userDefaults.set(data, forKey: Self.progressionDefaultsKey)
        }
    }

    private static func loadProgression(from userDefaults: UserDefaults) -> ProgressionState? {
        guard let data = userDefaults.data(forKey: progressionDefaultsKey) else { return nil }
        return try? JSONDecoder().decode(ProgressionState.self, from: data)
    }

    func weeklyGoalProgress(asOf referenceDate: Date = Date()) -> [WeeklyGoalDayStatus] {
        let calendar = Calendar.current
        let referenceDay = calendar.startOfDay(for: referenceDate)

        let statuses: [WeeklyGoalDayStatus] = stride(from: -6, through: 0, by: 1).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: referenceDay) else { return nil }
            let progress = progressForDay(date)
            let isToday = calendar.isDate(date, inSameDayAs: referenceDay)
            return WeeklyGoalDayStatus(date: date, goalHit: progress.reachedFocusGoal, isToday: isToday)
        }

        return statuses
    }

    var weeklyGoalProgress: [WeeklyGoalDayStatus] { weeklyGoalProgress(asOf: Date()) }

    func momentumTier(for referenceDate: Date = Date()) -> MomentumTier {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: referenceDate)

        let activeDayCount: Int = (0...6).reduce(0) { count, offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { return count }
            return hasSession(on: date, calendar: calendar) ? count + 1 : count
        }

        switch activeDayCount {
        case 0:
            return .cold
        case 1...2:
            return .warming
        case 3...5:
            return .rolling
        default:
            return .onFire
        }
    }

    func momentumMultiplier(for referenceDate: Date = Date()) -> Double {
        switch momentumTier(for: referenceDate) {
        case .cold:
            return 1.0
        case .warming:
            return 1.05
        case .rolling:
            return 1.10
        case .onFire:
            return 1.20
        }
    }

    func momentumLabel(for referenceDate: Date = Date()) -> String {
        switch momentumTier(for: referenceDate) {
        case .cold:
            return "Cold start"
        case .warming:
            return "Warming up"
        case .rolling:
            return "In the zone"
        case .onFire:
            return "On fire"
        }
    }

    func momentumDescription(for referenceDate: Date = Date()) -> String {
        switch momentumTier(for: referenceDate) {
        case .cold:
            return "Start a session to build Momentum."
        case .warming:
            return "You’ve been active lately, keep going."
        case .rolling:
            return "You’re in the groove."
        case .onFire:
            return "XP bonus for showing up every day."
        }
    }

    private let userDefaults: UserDefaults
    private static let progressionDefaultsKey = "progression_state_v1"

    private enum Keys {
        static let focusSeconds = "focusSeconds"
        static let selfCareSeconds = "selfCareSeconds"
        static let sessionsCompleted = "sessionsCompleted"
        static let xp = "xp"
        static let sessionHistory = "sessionHistory"
        static let lastKnownLevel = "lastKnownLevel"
        static let totalFocusSecondsToday = "totalFocusSecondsToday"
        static let totalFocusDate = "totalFocusDate"
        static let dailyPlan = "dailyPlan"
        static let dailyProgressHistory = "dailyProgressHistory"
        static let legacyDailyConfig = "dailyConfig"
        static let lastWeeklyGoalBonusAwardedDate = "lastWeeklyGoalBonusAwardedDate"
    }

    private var todaySessions: [SessionRecord] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return sessionHistory.filter { session in
            calendar.isDate(session.date, inSameDayAs: today)
        }
    }

    private func persist() {
        saveProgression()
        userDefaults.set(focusSeconds, forKey: Keys.focusSeconds)
        userDefaults.set(selfCareSeconds, forKey: Keys.selfCareSeconds)
        userDefaults.set(sessionsCompleted, forKey: Keys.sessionsCompleted)
        userDefaults.set(progression.totalXP, forKey: Keys.xp)
        userDefaults.set(progression.level, forKey: Keys.lastKnownLevel)
        userDefaults.set(totalFocusSecondsToday, forKey: Keys.totalFocusSecondsToday)
        userDefaults.set(Calendar.current.startOfDay(for: Date()), forKey: Keys.totalFocusDate)
        persistWeeklyGoalBonus()
        persistDailyPlan(dailyPlan)
        persistDailyProgressHistory()
        persistSessionHistory()
    }

    private func persistSessionHistory() {
        if let data = try? JSONEncoder().encode(sessionHistory) {
            userDefaults.set(data, forKey: Keys.sessionHistory)
        }
    }

    private func refreshDailyTotalsIfNeeded() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let storedDate = userDefaults.object(forKey: Keys.totalFocusDate) as? Date

        guard !calendar.isDate(storedDate ?? Date.distantPast, inSameDayAs: today) else { return }

        totalFocusSecondsToday = 0
        userDefaults.set(today, forKey: Keys.totalFocusDate)
        userDefaults.set(totalFocusSecondsToday, forKey: Keys.totalFocusSecondsToday)
        refreshDailySetupIfNeeded()
        pruneDailyProgressHistory(referenceDate: today)
        updateDailyProgress(for: today)
    }

    private func persistDailyPlan(_ plan: DailyPlan?) {
        guard let plan else {
            userDefaults.removeObject(forKey: Keys.dailyPlan)
            return
        }

        if let data = try? JSONEncoder().encode(plan) {
            userDefaults.set(data, forKey: Keys.dailyPlan)
        }
    }

    private func persistDailyProgressHistory() {
        if let data = try? JSONEncoder().encode(dailyProgressHistory) {
            userDefaults.set(data, forKey: Keys.dailyProgressHistory)
        }
    }

    private static func decodePlan(from data: Data?) -> DailyPlan? {
        guard let data else { return nil }
        return try? JSONDecoder().decode(DailyPlan.self, from: data)
    }

    private static func decodeLegacyConfig(from data: Data?) -> DailyPlan? {
        struct LegacyDailyConfig: Codable {
            let date: Date
            let focusArea: FocusArea
            let dailyMinutesGoal: Int
        }

        guard let data else { return nil }
        guard let legacy = try? JSONDecoder().decode(LegacyDailyConfig.self, from: data) else { return nil }

        let energyLevel: EnergyLevel
        switch legacy.dailyMinutesGoal {
        case 60...:
            energyLevel = .high
        case 40...:
            energyLevel = .medium
        default:
            energyLevel = .low
        }

        let normalizedDate = Calendar.current.startOfDay(for: legacy.date)
        return DailyPlan(
            date: normalizedDate,
            focusArea: legacy.focusArea,
            energyLevel: energyLevel,
            focusGoalMinutes: legacy.dailyMinutesGoal
        )
    }

    private static func decodeDailyProgress(from data: Data?) -> [DailyProgress]? {
        guard let data else { return nil }
        return try? JSONDecoder().decode([DailyProgress].self, from: data)
    }

    private static func isPlanValidForToday(_ plan: DailyPlan?, today: Date = Calendar.current.startOfDay(for: Date())) -> Bool {
        guard let plan else { return false }
        return Calendar.current.isDate(plan.date, inSameDayAs: today)
    }

    var currentStreakDays: Int { progression.streakDays }

    var currentGoalStreak: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var streak = 0

        for offset in 0..<7 {
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { break }
            let progress = progressForDay(date)
            guard progress.reachedFocusGoal else { break }
            streak += 1
        }

        return streak
    }

    func dailyProgress(for date: Date) -> DailyProgress {
        progressForDay(date)
    }

    private func normalizedDate(_ date: Date) -> Date { Calendar.current.startOfDay(for: date) }

    private func focusSessionSeconds(on day: Date) -> Int {
        let calendar = Calendar.current
        let targetDay = calendar.startOfDay(for: day)
        return sessionHistory
            .filter { calendar.isDate($0.date, inSameDayAs: targetDay) && $0.modeRawValue == FocusTimerMode.focus.rawValue }
            .reduce(0) { $0 + $1.durationSeconds }
    }

    private func updateDailyProgress(
        for date: Date = Date(),
        focusGoalMinutes: Int? = nil,
        questsCompleted: Int? = nil,
        totalQuests: Int? = nil
    ) {
        let calendar = Calendar.current
        let day = normalizedDate(date)

        var progress = dailyProgressHistory.first { calendar.isDate($0.date, inSameDayAs: day) }
            ?? DailyProgress(date: day, questsCompleted: 0, focusMinutes: 0, reachedFocusGoal: false)

        let focusMinutes: Int
        if calendar.isDate(day, inSameDayAs: Date()) {
            focusMinutes = totalFocusSecondsToday / 60
        } else {
            focusMinutes = focusSessionSeconds(on: day) / 60
        }
        progress.focusMinutes = focusMinutes

        if let questsCompleted {
            progress.questsCompleted = questsCompleted
        }

        if let totalQuests {
            progress.totalQuests = totalQuests
        }

        if let focusGoalMinutes {
            progress.focusGoalMinutes = focusGoalMinutes
        }

        let goalMinutes = focusGoalMinutes
            ?? progress.focusGoalMinutes
            ?? (dailyPlan.flatMap { Calendar.current.isDate($0.date, inSameDayAs: day) ? $0.focusGoalMinutes : nil })

        if let goalMinutes, goalMinutes > 0 {
            progress.reachedFocusGoal = progress.focusMinutes >= goalMinutes
        }

        dailyProgressHistory.removeAll { calendar.isDate($0.date, inSameDayAs: day) }
        dailyProgressHistory.append(progress)
        pruneDailyProgressHistory(referenceDate: day)
    }

    private func progressForDay(_ date: Date) -> DailyProgress {
        let calendar = Calendar.current
        let day = normalizedDate(date)
        if let existing = dailyProgressHistory.first(where: { calendar.isDate($0.date, inSameDayAs: day) }) {
            return existing
        }

        let focusMinutes = focusSessionSeconds(on: day) / 60
        let goalMinutes = dailyPlan.flatMap { Calendar.current.isDate($0.date, inSameDayAs: day) ? $0.focusGoalMinutes : nil }
        let reachedGoal = (goalMinutes ?? 0) > 0 ? focusMinutes >= (goalMinutes ?? 0) : false
        let progress = DailyProgress(
            date: day,
            questsCompleted: 0,
            focusMinutes: focusMinutes,
            reachedFocusGoal: reachedGoal,
            totalQuests: nil,
            focusGoalMinutes: goalMinutes
        )
        dailyProgressHistory.append(progress)
        pruneDailyProgressHistory(referenceDate: day)
        return progress
    }

    private func pruneDailyProgressHistory(referenceDate: Date = Date()) {
        let calendar = Calendar.current
        let cutoff = calendar.date(byAdding: .day, value: -14, to: normalizedDate(referenceDate)) ?? referenceDate
        dailyProgressHistory = dailyProgressHistory.filter { $0.date >= cutoff }
        persistDailyProgressHistory()
    }

    private func hasSession(on day: Date, calendar: Calendar = .current) -> Bool {
        let targetDay = calendar.startOfDay(for: day)
        return sessionHistory.contains { calendar.isDate($0.date, inSameDayAs: targetDay) }
    }

    private var focusSecondsThisWeek: Int {
        sessionHistory
            .filter { $0.modeRawValue == FocusTimerMode.focus.rawValue && isDate($0.date, inSameWeekAs: Date()) }
            .reduce(0) { $0 + $1.durationSeconds }
    }

    private var focusSessionsThisWeek: Int {
        sessionHistory
            .filter { $0.modeRawValue == FocusTimerMode.focus.rawValue && isDate($0.date, inSameWeekAs: Date()) }
            .count
    }

    private func isDate(_ date: Date, inSameWeekAs reference: Date) -> Bool {
        let calendar = Calendar.current
        let targetComponents = calendar.dateComponents([.weekOfYear, .yearForWeekOfYear], from: reference)
        let dateComponents = calendar.dateComponents([.weekOfYear, .yearForWeekOfYear], from: date)
        return targetComponents.weekOfYear == dateComponents.weekOfYear && targetComponents.yearForWeekOfYear == dateComponents.yearForWeekOfYear
    }

    private func evaluateWeeklyGoalBonus() {
        let progress = weeklyGoalProgress
        guard let mostRecentDay = progress.last, mostRecentDay.isToday else { return }
        guard progress.allSatisfy({ $0.goalHit }) else { return }

        let calendar = Calendar.current
        if let lastAwarded = lastWeeklyGoalBonusAwardedDate, calendar.isDate(lastAwarded, inSameDayAs: mostRecentDay.date) {
            return
        }

        lastWeeklyGoalBonusAwardedDate = mostRecentDay.date
        persistWeeklyGoalBonus()
    }

    private func persistWeeklyGoalBonus() {
        if let lastWeeklyGoalBonusAwardedDate {
            userDefaults.set(lastWeeklyGoalBonusAwardedDate, forKey: Keys.lastWeeklyGoalBonusAwardedDate)
        } else {
            userDefaults.removeObject(forKey: Keys.lastWeeklyGoalBonusAwardedDate)
        }
    }
}

extension SessionStatsStore.LevelUpResult: Identifiable {
    var id: String { "\(oldLevel)->\(newLevel)" }
}

/// Manages the state for the Focus timer screen.
final class FocusViewModel: ObservableObject {
    struct SessionSummary {
        let mode: FocusTimerMode
        let duration: Int
        let xpGained: Int
        let timestamp: Date
    }

    enum HydrationNudgeLevel: CaseIterable {
        case thirtyMinutes
        case sixtyMinutes
        case ninetyMinutes

        var thresholdSeconds: Int {
            switch self {
            case .thirtyMinutes: 1_800
            case .sixtyMinutes: 3_600
            case .ninetyMinutes: 5_400
            }
        }

        var bodyText: String {
            switch self {
            case .thirtyMinutes:
                return QuestChatStrings.HydrationNudges.streak
            case .sixtyMinutes:
                return QuestChatStrings.HydrationNudges.hour
            case .ninetyMinutes:
                return QuestChatStrings.HydrationNudges.long
            }
        }
    }

    enum FocusTimerState {
        case idle
        case running
        case paused
    }

    @Published private(set) var currentSession: FocusSession?
    @Published var hasFinishedOnce: Bool = false
    @Published var selectedMode: FocusTimerMode = .focus {
        didSet {
            guard hasInitialized else { return }
            resetForModeChange()
        }
    }
    @Published var categories: [TimerCategory]
    @Published var selectedCategory: TimerCategory.Kind
    @Published var isShowingDurationPicker: Bool = false
    @Published var pendingDurationSeconds: Int = 0
    @Published var lastCompletedSession: SessionSummary?
    @Published var activeReminderEvent: ReminderEvent?
    @Published var activeReminderMessage: String?
    @Published var lastLevelUp: SessionStatsStore.LevelUpResult?
    private var isAppInForeground: Bool = true
    private var pendingBackgroundReminder: (event: ReminderEvent, message: String)?
    private var reminderQueue: [(event: ReminderEvent, message: String)] = []
    @Published var sleepQuality: SleepQuality = .okay {
        didSet {
            guard !isLoadingSleepData else { return }
            persistSleepQualitySelection()
            evaluateHealthXPBonuses()
        }
    }
    @Published var activityLevel: ActivityLevel? {
        didSet {
            guard !isLoadingActivityData else { return }
            persistActivityLevelSelection()
        }
    }
    @Published var totalWaterOuncesToday: Int = 0
    @Published var totalComfortOuncesToday: Int = 0
    @Published private var waterGoalXPGrantedToday = false
    @Published private var healthComboXPGrantedToday = false
    @Published var timerState: FocusTimerState = .idle
    @Published var remainingSeconds: Int = 0
    @Published var isActiveTimerExpanded: Bool = true
    
    // Track last scene phase to avoid redundant handling on tab switches
    private var lastScenePhase: ScenePhase?
    
    // Added published property for hydration sip feedback
    @Published var sipFeedback: String? = nil
    
    @Published var hydrationNudgesEnabled: Bool = false
    @Published var postureRemindersEnabled: Bool = false

    var onSessionComplete: (() -> Void)?

    enum TimerState {
        case idle
        case running
        case paused
        case finished
    }

    @Published var state: TimerState = .idle

    @Published private(set) var notificationAuthorized: Bool = false
    @Published var showMiniFAB: Bool {
        didSet {
            userDefaults.set(showMiniFAB, forKey: "show_mini_fab")
        }
    }
    let statsStore: SessionStatsStore
    let playerStateStore: PlayerStateStore
    let playerTitleStore: PlayerTitleStore
    let healthStatsStore: HealthBarIRLStatsStore
    let hydrationReminderManager: HydrationReminderManager
    let hydrationSettingsStore: HydrationSettingsStore
    private let reminderSettingsStore: ReminderSettingsStore
    let reminderEventsStore: ReminderEventsStore
    let seasonAchievementsStore: SeasonAchievementsStore
    let sleepHistoryStore: SleepHistoryStore
    let activityHistoryStore: ActivityHistoryStore
    private var cancellables = Set<AnyCancellable>()
    private var healthBarViewModel: HealthBarViewModel?

    @Published private var pausedRemainingSeconds: Int?
    @Published private var timerTick: Date = Date()
    private var timerCancellable: AnyCancellable?
    private let notificationCenter = UNUserNotificationCenter.current()
    private let userDefaults = UserDefaults.standard
    private var activeSessionCategory: TimerCategory.Kind?
    private var hpCheckinQuestSentDate: Date?
    private var hydrationGoalQuestSentDate: Date?
    private var reminderTimerCancellable: AnyCancellable?
    private var lastReminderFiredAt: [ReminderType: Date] = [:]
    private let reminderNotificationIdentifiers: [ReminderType: String] = [
        .hydration: "hydration_reminder_next",
        .posture: "posture_reminder_next",
    ]

    @available(iOS 16.1, *)
    private var liveActivityManager: FocusTimerLiveActivityManager? {
        FocusTimerLiveActivityManager.shared
    }

    @available(iOS 17.0, *)
    private var liveActivity: Activity<FocusSessionAttributes>?

    private static let persistedSessionKey = "focus_current_session_v1"
    private var hasInitialized = false
    private let minimumSessionDuration: TimeInterval = 60
    private var activeSessionDuration: Int?
    private var hasLoggedSleepQualityToday = false
    private var isLoadingSleepData = false
    private var hasLoggedActivityToday = false
    private var isLoadingActivityData = false
    @Published private(set) var isRestoringFromLiveActivity = false  // 🎯 Flag to suppress animations during restoration

    init(
        statsStore: SessionStatsStore = DependencyContainer.shared.sessionStatsStore,
        playerStateStore: PlayerStateStore = DependencyContainer.shared.playerStateStore,
        playerTitleStore: PlayerTitleStore = DependencyContainer.shared.playerTitleStore,
        healthStatsStore: HealthBarIRLStatsStore = HealthBarIRLStatsStore(),
        healthBarViewModel: HealthBarViewModel? = nil,
        hydrationReminderManager: HydrationReminderManager = DependencyContainer.shared.hydrationReminderManager,
        hydrationSettingsStore: HydrationSettingsStore = DependencyContainer.shared.hydrationSettingsStore,
        reminderSettingsStore: ReminderSettingsStore = DependencyContainer.shared.reminderSettingsStore,
        reminderEventsStore: ReminderEventsStore = ReminderEventsStore(),
        seasonAchievementsStore: SeasonAchievementsStore = DependencyContainer.shared.seasonAchievementsStore,
        sleepHistoryStore: SleepHistoryStore = DependencyContainer.shared.sleepHistoryStore,
        activityHistoryStore: ActivityHistoryStore = DependencyContainer.shared.activityHistoryStore,
        initialMode: FocusTimerMode = .focus
    ) {
        // Assign non-dependent stored properties first
        self.statsStore = statsStore
        self.playerStateStore = playerStateStore
        self.playerTitleStore = playerTitleStore
        self.healthStatsStore = healthStatsStore
        self.healthBarViewModel = healthBarViewModel
        self.hydrationReminderManager = hydrationReminderManager
        self.hydrationSettingsStore = hydrationSettingsStore
        self.reminderSettingsStore = reminderSettingsStore
        self.reminderEventsStore = reminderEventsStore
        self.seasonAchievementsStore = seasonAchievementsStore
        self.sleepHistoryStore = sleepHistoryStore
        self.activityHistoryStore = activityHistoryStore
        self.currentHP = healthStatsStore.currentHP
        hpCheckinQuestSentDate = userDefaults.object(forKey: HealthTrackingStorageKeys.hpCheckinQuestDate) as? Date
        
        // Initialize Mini FAB visibility setting (default: true)
        self.showMiniFAB = userDefaults.object(forKey: "show_mini_fab") as? Bool ?? true
        
        // Defer syncing player HP until after initialization completes to avoid using self too early.
        let initialHP = healthStatsStore.currentHP

        self.hydrationNudgesEnabled = reminderSettingsStore.hydrationSettings.enabled
        self.postureRemindersEnabled = reminderSettingsStore.postureSettings.enabled

        // Removed assign pipelines here; will add sink pipelines after hasInitialized = true

        let seeded = FocusViewModel.seededCategories()
        let loadedCategories: [TimerCategory] = seeded.map { base in
            let key = Self.durationKey(for: base.id)
            let storedSeconds = UserDefaults.standard.integer(forKey: key)
            let duration = storedSeconds > 0 ? storedSeconds : base.durationSeconds
            return TimerCategory(id: base.id, durationSeconds: duration)
        }
        self.categories = loadedCategories

        let initialCategory = loadedCategories.first(where: { $0.id == .focusMode })
            ?? loadedCategories.first { $0.id.mode == initialMode }
            ?? loadedCategories[0]
        self.selectedCategory = initialCategory.id
        self.selectedMode = initialCategory.id.mode
        self.pausedRemainingSeconds = initialCategory.durationSeconds
        self.remainingSeconds = initialCategory.durationSeconds

        hasInitialized = true

        // Add the new subscriptions here with sink and store

        reminderSettingsStore.$hydrationSettings
            .map { $0.enabled }
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] enabled in
                self?.hydrationNudgesEnabled = enabled
            }
            .store(in: &cancellables)

        reminderSettingsStore.$postureSettings
            .map { $0.enabled }
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] enabled in
                self?.postureRemindersEnabled = enabled
            }
            .store(in: &cancellables)

        ReminderType.allCases.forEach { type in
            if let storedDate = userDefaults.object(forKey: Self.reminderLastFiredKey(for: type)) as? Date {
                lastReminderFiredAt[type] = storedDate
            }
        }

        hydrationReminderManager.$lastHydrationReminderDate
            .receive(on: RunLoop.main)
            .sink { [weak self] date in
                guard let date else { return }
                self?.lastReminderFiredAt[.hydration] = date
            }
            .store(in: &cancellables)

        if let hydrationLast = hydrationReminderManager.lastHydrationReminderDate {
            if let existing = lastReminderFiredAt[.hydration] {
                lastReminderFiredAt[.hydration] = max(existing, hydrationLast)
            } else {
                lastReminderFiredAt[.hydration] = hydrationLast
            }
        }

        // Now that initialization is complete, it is safe to use self in method calls.
        syncPlayerHP(with: initialHP)

        // Defer side-effectful calls until after full initialization
        requestNotificationAuthorization()

        statsStore.$lastLevelUp
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.lastLevelUp = $0 }
            .store(in: &cancellables)

        healthStatsStore.$currentHP
            .receive(on: RunLoop.main)
            .sink { [weak self] hp in
                self?.currentHP = hp
                self?.syncPlayerHP(with: hp)
            }
            .store(in: &cancellables)

        reminderSettingsStore.$hydrationSettings
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.refreshReminderScheduling(shouldEvaluateImmediately: false) }
            .store(in: &cancellables)

        reminderSettingsStore.$postureSettings
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.refreshReminderScheduling(shouldEvaluateImmediately: false) }
            .store(in: &cancellables)

        if let healthBarViewModel {
            bindHealthBarViewModel(healthBarViewModel)
        }

        if #available(iOS 17.0, *) {
            restoreLiveActivityIfNeeded()
        }

        refreshDailyHealthBonusState()
        loadSleepQuality()
        loadActivityLevel()
        refreshReminderScheduling()
    }

    var timerStatusText: String {
        if hasFinishedOnce {
            return QuestChatStrings.FocusView.sessionCompleteAccessory
        }

        switch selectedMode {
        case .focus:
            return QuestChatStrings.FocusView.focusAccessory
        case .selfCare:
            return QuestChatStrings.FocusView.selfCareAccessory
        }
    }

    var currentLevel: Int { statsStore.level }
    var xpInCurrentLevel: Int { statsStore.xpIntoCurrentLevel }
    var xpNeededForNextLevel: Int { statsStore.xpNeededToLevelUp(from: statsStore.level) }
    var playerLevel: Int { statsStore.level }
    var playerTotalXP: Int { statsStore.totalXP }
    var xpIntoCurrentLevel: Int { statsStore.xpIntoCurrentLevel }
    var levelProgressFraction: Double {
        let needed = max(1, xpNeededForNextLevel == Int.max ? 1 : xpNeededForNextLevel)
        return Double(xpInCurrentLevel) / Double(needed)
    }

    var selectedCategoryData: TimerCategory? {
        categories.first { $0.id == selectedCategory }
    }

    private var gutStatus: GutStatus {
        healthBarViewModel?.inputs.gutStatus ?? .none
    }

    private var moodStatus: MoodStatus {
        healthBarViewModel?.inputs.moodStatus ?? .none
    }

    @Published private(set) var currentHP: Int = 0

    var hpProgress: Double { healthStatsStore.hpPercentage }

    var hydrationProgress: Double {
        let goal = hydrationSettingsStore.dailyWaterGoalOunces
        guard goal > 0 else { return 0 }
        let intake = (healthBarViewModel?.inputs.hydrationCount ?? 0) * hydrationSettingsStore.ouncesPerWaterTap
        return clampProgress(Double(intake) / Double(goal))
    }

    var sleepProgress: Double {
        let normalized = Double(sleepQuality.rawValue) / Double(SleepQuality.allCases.count - 1)
        return clampProgress(normalized)
    }

    var moodProgress: Double {
        let mood = healthBarViewModel?.inputs.moodStatus ?? .none
        let value: Double = {
            switch mood {
            case .none:
                return 0
            case .bad:
                return 0.25
            case .neutral:
                return 0.5
            case .good:
                return 1
            }
        }()

        return clampProgress(value)
    }

    var staminaProgress: Double {
        let focusCount = healthBarViewModel?.inputs.focusSprints ?? 0
        let target = 4.0
        return clampProgress(Double(focusCount) / target)
    }

    var hydrationSummaryText: String {
        let intake = waterIntakeOuncesToday
        let goal = hydrationSettingsStore.dailyWaterGoalOunces
        let goalText = goal > 0 ? " / \(goal) oz" : " oz"
        return "\(intake)\(goalText)"
    }

    var hydrationCupsText: String? {
        let intake = waterIntakeOuncesToday
        let goal = hydrationSettingsStore.dailyWaterGoalOunces
        guard intake > 0 || goal > 0 else { return nil }

        let intakeCups = Double(intake) / 8
        let goalCups = goal > 0 ? Double(goal) / 8 : nil
        if let goalCups { return String(format: "%.0f / %.0f cups", intakeCups, goalCups) }
        return String(format: "%.0f cups", intakeCups)
    }

    var staminaLabel: String {
        let sprints = healthBarViewModel?.inputs.focusSprints ?? 0
        return "\(sprints) focus sprints"
    }

    var sleepQualityLabel: String { sleepQuality.label }

    var moodStatusLabel: String {
        switch moodStatus {
        case .good: return "Good"
        case .neutral: return "Neutral"
        case .bad: return "Bad"
        case .none: return "Not set"
        }
    }

    private func clampProgress(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }

    var activeEffects: [StatusEffect] {
        var effects: [StatusEffect] = []

        switch gutStatus {
        case .rough:
            effects.append(
                StatusEffect(
                    title: "Gut Trouble",
                    description: "Rough digestion is draining HP recovery.",
                    systemImageName: "exclamationmark.triangle.fill",
                    kind: .debuff,
                    affectedStats: ["HP"]
                )
            )
        case .great:
            effects.append(
                StatusEffect(
                    title: "Gut of Steel",
                    description: "Great gut health boosts HP gains.",
                    systemImageName: "shield.fill",
                    kind: .buff,
                    affectedStats: ["HP"]
                )
            )
        case .meh, .none:
            break
        }

        switch moodStatus {
        case .good:
            effects.append(
                StatusEffect(
                    title: "Upbeat",
                    description: "Bright mood increases resilience.",
                    systemImageName: "face.smiling.fill",
                    kind: .buff,
                    affectedStats: ["Mood", "HP"]
                )
            )
        case .bad:
            effects.append(
                StatusEffect(
                    title: "Stormy Mood",
                    description: "Feeling off reduces overall HP.",
                    systemImageName: "cloud.bolt.fill",
                    kind: .debuff,
                    affectedStats: ["Mood", "HP"]
                )
            )
        case .neutral, .none:
            break
        }

        if sleepQuality == .awful, let debuffLabel = sleepQuality.debuffLabel {
            effects.append(
                StatusEffect(
                    title: debuffLabel,
                    description: "Poor sleep hurts stamina and HP.",
                    systemImageName: "bed.double.fill",
                    kind: .debuff,
                    affectedStats: ["Sleep", "HP", "Stamina"]
                )
            )
        }

        if sleepQuality == .great, let buffLabel = sleepQuality.buffLabel {
            effects.append(
                StatusEffect(
                    title: buffLabel,
                    description: "Rested up and ready to quest.",
                    systemImageName: "moon.zzz.fill",
                    kind: .buff,
                    affectedStats: ["Sleep", "HP", "Stamina"]
                )
            )
        }

        return effects
    }

    private var currentDuration: Int {
        durationForSelectedCategory()
    }

    var progress: Double {
        let total = Double(activeSessionDuration ?? currentDuration)
        guard total > 0 else { return 0 }
        if timerState == .idle && remainingSeconds == 0 {
            return 0
        }
        let value = 1 - (Double(remainingSeconds) / total)
        return min(max(value, 0), 1)
    }

    var remainingTimeLabel: String {
        let seconds = max(remainingSeconds, 0)
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%d:%02d", minutes, secs)
        }
    }

    var isRunning: Bool { state == .running }

    func toggleHydrationNudges() {
        var settings = reminderSettingsStore.hydrationSettings
        settings.enabled.toggle()
        reminderSettingsStore.updateSettings(settings, for: .hydration)
    }

    func togglePostureReminders() {
        var settings = reminderSettingsStore.postureSettings
        settings.enabled.toggle()
        reminderSettingsStore.updateSettings(settings, for: .posture)
    }

    func logHydrationPillTapped() {
        guard let healthBarViewModel else { return }

        // HP updates are capped inside HealthBarViewModel; still log even when already at max HP.
        healthBarViewModel.logHydration()

        updateWaterIntakeTotals()
        let mlPerOunce = 29.57
        let amountMl = Int((Double(hydrationSettingsStore.ouncesPerWaterTap) * mlPerOunce).rounded())
        let totalMl = Int((Double(totalWaterOuncesToday) * mlPerOunce).rounded())
        let percentOfGoal = waterGoalToday > 0 ? Double(totalWaterOuncesToday) / Double(waterGoalToday) : 0
        statsStore.questEventHandler?(
            .hydrationLogged(
                amountMl: amountMl,
                totalMlToday: totalMl,
                percentOfGoal: percentOfGoal
            )
        )
        healthStatsStore.update(from: healthBarViewModel.inputs)
        syncPlayerHP()
        evaluateHealthXPBonuses()
    }

    func logComfortBeverageTapped() {
        guard let healthBarViewModel else { return }

        // HP updates are capped inside HealthBarViewModel; still log even when already at max HP.
        healthBarViewModel.logSelfCareSession()

        totalComfortOuncesToday += hydrationSettingsStore.ouncesPerComfortTap
        healthStatsStore.update(from: healthBarViewModel.inputs)
        syncPlayerHP()
    }

    func logStaminaPotionTapped() {
        guard let healthBarViewModel else { return }

        healthBarViewModel.logFocusSession()
    }
    
    // Added method to show sip feedback with auto-dismiss
    func showSipFeedback(_ text: String) {
        sipFeedback = text
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { [weak self] in
            self?.sipFeedback = nil
        }
    }

    /// Starts the timer if currently idle or paused.
    func start() {
        if timerState == .paused {
            resumeTimer()
            return
        }

        startTimer(duration: remainingSeconds == 0 ? currentDuration : remainingSeconds)
    }

    func startTimer(duration: Int) {
        guard timerState == .idle else { return }

        let clampedDuration = max(duration, Int(minimumSessionDuration))
        hasFinishedOnce = false

        if activeSessionDuration == nil || timerState == .idle {
            activeSessionDuration = clampedDuration
        }

        let totalDuration = activeSessionDuration ?? clampedDuration
        remainingSeconds = totalDuration

        let startDate = Date()
        let category = selectedCategoryData ?? TimerCategory(id: selectedCategory, durationSeconds: currentDuration)
        
        let session = FocusSession(
            id: currentSession?.id ?? UUID(),
            type: selectedMode,
            duration: TimeInterval(totalDuration),
            startDate: startDate,
            category: category.id  // Capture category at session start
        )

        pausedRemainingSeconds = nil
        currentSession = session
        activeSessionCategory = category.id
        timerState = .running
        state = .running
        print("[FocusTimer] Start timer for \(totalDuration)s")
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        scheduleCompletionNotification()
        startUITimer()
        let title = category.id.title
        let durationMinutes = totalDuration / 60
        statsStore.questEventHandler?(.focusSessionStarted(durationMinutes: durationMinutes))
        if #available(iOS 17.0, *) {
            Task {
                for activity in Activity<FocusSessionAttributes>.activities {
                    await activity.end(nil, dismissalPolicy: .immediate)
                }

                let attributes = FocusSessionAttributes(sessionId: UUID(), totalSeconds: totalDuration)
                let contentState = FocusSessionAttributes.ContentState(
                    startDate: startDate,
                    endDate: session.endDate,
                    isPaused: false,
                    remainingSeconds: totalDuration,
                    title: title,
                    category: category.id.rawValue
                )
                let content = ActivityContent(state: contentState, staleDate: session.endDate)

                do {
                    let activity = try Activity.request(
                        attributes: attributes,
                        content: content,
                        pushType: nil
                    )
                    await MainActor.run {
                        self.liveActivity = activity
                    }
                    print("[FocusLiveActivity] Started: \(activity.id)")
                } catch {
                    print("[FocusLiveActivity] Failed to start: \(error)")
                }
            }
        } else if #available(iOS 16.1, *) {
            let sessionType = category.id.rawValue
            liveActivityManager?.start(
                endDate: session.endDate,
                sessionType: sessionType,
                title: title
            )
        }
        handleSessionCompletionIfNeeded()
    }

    /// Pauses the timer if currently running.
    func pause() {
        pauseTimer()
    }

    func pauseTimer() {
        guard timerState == .running else { return }
        guard let session = currentSession else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        cancelCompletionNotifications()
        let remaining = max(Int(ceil(session.endDate.timeIntervalSinceNow)), 0)
        let startDate = session.startDate
        let endDate = session.endDate
        
        // Calculate elapsed time for partial quest credit
        let totalDuration = Int(session.duration)
        let elapsed = totalDuration - remaining
        let elapsedMinutes = elapsed / 60
        
        // Award quest credit for completed time (but don't record as full session)
        if elapsedMinutes > 0, let category = activeSessionCategory {
            print("[FocusTimer] Paused after \(elapsedMinutes)m - awarding partial quest credit")
            statsStore.questEventHandler?(
                .timerCompleted(
                    category: category,
                    durationMinutes: elapsedMinutes,
                    endedAt: Date()
                )
            )
        }
        
        pausedRemainingSeconds = remaining
        remainingSeconds = remaining
        currentSession = nil
        stopUITimer()
        clearPersistedSession()
        timerState = .paused
        state = .paused
        // NOTE: activeSessionCategory is intentionally NOT cleared here - we preserve it for resume
        print("[FocusTimer] Paused with \(remaining) seconds left")
        if #available(iOS 17.0, *) {
            updateLiveActivity(
                isPaused: true,
                remaining: remaining,
                title: selectedCategoryData?.id.title ?? selectedMode.title,
                startDate: startDate,
                endDate: endDate
            )
        } else if #available(iOS 16.1, *) {
            liveActivityManager?.pause()
        }
    }

    /// Resets the timer to the selected category duration.
    func reset() {
        resetTimer()
    }

    func resumeTimer() {
        guard timerState == .paused else { return }

        let duration = remainingSeconds
        guard duration > 0 else {
            resetTimer()
            return
        }

        let session = FocusSession(
            id: UUID(),
            type: selectedMode,
            duration: TimeInterval(duration),
            startDate: Date(),
            category: activeSessionCategory  // Preserve the original category from when timer started
        )
        currentSession = session
        // Do NOT reassign activeSessionCategory here - it should already be set from the original start
        timerState = .running
        state = .running
        print("[FocusTimer] Resumed for \(duration)s")
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        scheduleCompletionNotification()
        startUITimer()

        if #available(iOS 17.0, *) {
            updateLiveActivity(
                isPaused: false,
                remaining: remainingSeconds,
                title: selectedCategoryData?.id.title ?? selectedMode.title,
                startDate: session.startDate,
                endDate: session.endDate
            )
        } else if #available(iOS 16.1, *) {
            let category = selectedCategoryData ?? TimerCategory(id: selectedCategory, durationSeconds: currentDuration)
            liveActivityManager?.update(
                title: category.id.title,
                endDate: session.endDate,
                isPaused: false
            )
        }
    }

    func resetTimer() {
        // Award credit for any time spent before reset
        if let session = currentSession, timerState == .running {
            let elapsed = max(0, Int(Date().timeIntervalSince(session.startDate)))
            let elapsedMinutes = elapsed / 60
            if elapsedMinutes > 0, let category = activeSessionCategory {
                print("[FocusTimer] Reset after \(elapsedMinutes)m - awarding partial quest credit")
                statsStore.questEventHandler?(
                    .timerCompleted(
                        category: category,
                        durationMinutes: elapsedMinutes,
                        endedAt: Date()
                    )
                )
            }
        } else if timerState == .paused, let paused = pausedRemainingSeconds, let category = activeSessionCategory {
            // If paused, calculate from what was saved
            let totalDuration = currentDuration
            let elapsed = max(0, totalDuration - paused)
            let elapsedMinutes = elapsed / 60
            if elapsedMinutes > 0 {
                print("[FocusTimer] Reset from paused state after \(elapsedMinutes)m - awarding partial quest credit")
                statsStore.questEventHandler?(
                    .timerCompleted(
                        category: category,
                        durationMinutes: elapsedMinutes,
                        endedAt: Date()
                    )
                )
            }
        }
        
        cancelCompletionNotifications()
        pausedRemainingSeconds = nil
        currentSession = nil
        stopUITimer()
        hasFinishedOnce = false
        activeSessionDuration = nil
        clearPersistedSession()
        timerState = .idle
        state = .idle
        isActiveTimerExpanded = true
        remainingSeconds = 0
        activeSessionCategory = nil
        print("[FocusTimer] Reset timer")

        if #available(iOS 17.0, *) {
            Task {
                // End ALL FocusSession live activities, just in case
                for activity in Activity<FocusSessionAttributes>.activities {
                    print("[FocusLiveActivity] Ending activity \(activity.id) on reset")
                    await activity.end(nil, dismissalPolicy: .immediate)
                }
                await MainActor.run {
                    self.liveActivity = nil
                }
            }
        } else if #available(iOS 16.1, *) {
            liveActivityManager?.cancel()
        }

        clearLiveActivityState()
    }

    func selectCategory(_ category: TimerCategory) {
        guard category.id != selectedCategory else { return }
        guard state == .idle || state == .finished else { return }

        selectedCategory = category.id
        selectedMode = category.id.mode
        pausedRemainingSeconds = category.durationSeconds
        remainingSeconds = category.durationSeconds
        hasFinishedOnce = false
        activeSessionDuration = nil
        state = .idle
        timerState = .idle
        isActiveTimerExpanded = true
    }

    func durationForSelectedCategory() -> Int {
        categories.first(where: { $0.id == selectedCategory })?.durationSeconds ?? selectedMode.defaultDurationMinutes * 60
    }

    func setDurationForSelectedCategory(_ seconds: Int) {
        guard state != .running else { return }
        guard let index = categories.firstIndex(where: { $0.id == selectedCategory }) else { return }
        let maxSeconds = (59 * 60) + 59
        let clamped = min(max(seconds, 0), maxSeconds)

        categories[index].durationSeconds = clamped
        saveDuration(clamped, for: categories[index].id)

        if state == .idle {
            pausedRemainingSeconds = clamped
            activeSessionDuration = nil
            remainingSeconds = clamped
        }
    }

    func formattedDuration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secondsPart = seconds % 60
        if secondsPart == 0 {
            return "\(minutes) min"
        }
        return String(format: "%d:%02d", minutes, secondsPart)
    }

    private func clearLiveActivityState() {
        if #available(iOS 17.0, *) {
            liveActivity = nil
        }
    }

    private func stopUITimer() {
        timerCancellable?.cancel()
        timerCancellable = nil
    }

    @available(iOS 17.0, *)
    private func updateLiveActivity(
        isPaused: Bool,
        remaining: Int,
        title: String,
        startDate: Date,
        endDate: Date
    ) {
        let categoryRawValue = activeSessionCategory?.rawValue ?? selectedCategory.rawValue
        let contentState = FocusSessionAttributes.ContentState(
            startDate: startDate,
            endDate: endDate,
            isPaused: isPaused,
            remainingSeconds: remaining,
            title: title,
            category: categoryRawValue
        )
        let content = ActivityContent(state: contentState, staleDate: isPaused ? nil : endDate)

        Task {
            guard let liveActivity else { return }
            await liveActivity.update(content)
            print("[FocusLiveActivity] Updated: paused=\(isPaused) remaining=\(remaining)")
        }
    }

    @available(iOS 17.0, *)
    func restoreLiveActivityIfNeeded() {
        Task {
            // ⚠️ Don't restore if we already have a timer state (running, paused, or finished)
            // Only restore on cold start when timer is idle and we have no active/paused session
            await MainActor.run {
                guard self.timerState == .idle,
                      self.currentSession == nil,
                      self.pausedRemainingSeconds == nil else {
                    print("[FocusLiveActivity] Skipping restore - app already has timer state")
                    return
                }
            }
            
            // Grab the first active FocusSession Live Activity, if any
            guard let activity = Activity<FocusSessionAttributes>.activities.first else { return }

            // Use `content` instead of deprecated `contentState`
            let content = activity.content
            let contentState = content.state
            let totalDuration = activity.attributes.totalSeconds
            let now = Date()
            let isPaused = contentState.isPaused
            var remaining: Int
            
            // ✅ Restore the category from the Live Activity
            let restoredCategory = TimerCategory.Kind(rawValue: contentState.category) ?? .focusMode
            
            // 🎯 Set flag to suppress view animations during restoration
            await MainActor.run {
                self.isRestoringFromLiveActivity = true
            }

            if isPaused {
                // Paused session: just restore remaining seconds and paused state
                remaining = contentState.remainingSeconds
                
                // ✅ Batch all state updates together without animation
                await MainActor.run {
                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) {
                        self.timerState = .paused
                        self.state = .paused
                        self.currentSession = nil
                        self.selectedCategory = restoredCategory
                        self.selectedMode = restoredCategory.mode
                        self.activeSessionCategory = restoredCategory
                        self.activeSessionDuration = totalDuration
                        self.pausedRemainingSeconds = remaining
                        self.remainingSeconds = remaining
                    }
                }
            } else {
                // Running session: compute remaining based on endDate
                remaining = max(Int(ceil(contentState.endDate.timeIntervalSince(now))), 0)

                if remaining > 0 {
                    // Still in progress → recreate the session and resume UI timer
                    let session = FocusSession(
                        id: UUID(),
                        type: restoredCategory.mode,
                        duration: TimeInterval(totalDuration),
                        startDate: contentState.startDate,
                        category: restoredCategory
                    )
                    
                    // ✅ Batch all state updates together without animation
                    await MainActor.run {
                        var transaction = Transaction()
                        transaction.disablesAnimations = true
                        withTransaction(transaction) {
                            self.currentSession = session
                            self.timerState = .running
                            self.state = .running
                            self.selectedCategory = restoredCategory
                            self.selectedMode = restoredCategory.mode
                            self.activeSessionCategory = restoredCategory
                            self.activeSessionDuration = totalDuration
                            self.remainingSeconds = remaining
                        }
                    }
                    
                    startUITimer()
                } else {
                    // ⛔️ Timer already finished while the app was gone.
                    // End the Live Activity so it doesn't stick around.
                    await MainActor.run {
                        var transaction = Transaction()
                        transaction.disablesAnimations = true
                        withTransaction(transaction) {
                            self.timerState = .idle
                            self.state = .idle
                            self.remainingSeconds = 0
                        }
                    }

                    await activity.end(nil, dismissalPolicy: .immediate)
                    await MainActor.run {
                        self.liveActivity = nil
                    }
                    print("[FocusLiveActivity] Ended stale activity \(activity.id)")
                    
                    // Reset flag
                    await MainActor.run {
                        self.isRestoringFromLiveActivity = false
                    }
                    return
                }
            }

            await MainActor.run {
                self.liveActivity = activity
            }
            print("[FocusLiveActivity] Restored existing activity \(activity.id) paused=\(isPaused) remaining=\(remaining) category=\(restoredCategory)")
            
            // 🎯 Reset flag after a short delay to allow views to settle
            Task {
                try? await Task.sleep(for: .milliseconds(100))
                await MainActor.run {
                    self.isRestoringFromLiveActivity = false
                }
            }
        }
    }

    private func startUITimer() {
        guard timerState == .running else { return }
        timerCancellable?.cancel()
        timerCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] date in
                guard let self else { return }
                self.timerTick = date
                if let session = self.currentSession {
                    let remaining = max(Int(ceil(session.endDate.timeIntervalSince(date))), 0)
                    if remaining != self.remainingSeconds {
                        self.remainingSeconds = remaining
                        // Live Activity kit updates are throttled: avoid per-second updates from the UI timer.
                        // We update the live activity only on start/pause/resume/finish/restoration.
                    }
                }
                self.handleSessionCompletionIfNeeded()
            }
    }

    private func finishSession() {
        cancelCompletionNotifications()
        stopUITimer()
        timerState = .idle
        state = .finished
        isActiveTimerExpanded = true
        hasFinishedOnce = true
        if let sessionType = currentSession?.type {
            selectedMode = sessionType
        }
        statsStore.refreshDailyFocusTotal()
        let previousFocusTotal = statsStore.totalFocusSecondsToday
        let xpBefore = statsStore.totalXP
        let recordedDuration = Int(currentSession?.duration ?? TimeInterval(activeSessionDuration ?? currentDuration))
        
        // Log for debugging quest progression
        print("[FocusTimer] Finishing session - category: \(String(describing: activeSessionCategory)), duration: \(recordedDuration)s")
        
        _ = statsStore.recordSession(mode: selectedMode, duration: recordedDuration)
        if currentSession?.type == .focus {
            let durationMinutes = recordedDuration / 60
            statsStore.questEventHandler?(.focusSessionCompleted(durationMinutes: durationMinutes))
            if activeSessionCategory == .chores {
                statsStore.questEventHandler?(.choresTimerCompleted(durationMinutes: durationMinutes))
            }
        }
        // Use category in priority order: 1) activeSessionCategory, 2) session.category, 3) selectedCategory fallback
        let timerCategory = activeSessionCategory ?? currentSession?.category ?? selectedCategory
        let endDate = currentSession?.endDate ?? Date()
        statsStore.questEventHandler?(
            .timerCompleted(
                category: timerCategory,
                durationMinutes: recordedDuration / 60,
                endedAt: endDate
            )
        )
        let today = Calendar.current.startOfDay(for: Date())
        if selectedMode == .focus {
            let durationMinutes = recordedDuration / 60
            if durationMinutes >= 40 {
                seasonAchievementsStore.applyProgress(
                    conditionType: .focusSessionsLong,
                    amount: 1,
                    date: today
                )
            }

            if durationMinutes >= 30, let category = activeSessionCategory {
                seasonAchievementsStore.recordFourRealmsSessionCompletion(
                    mode: category,
                    date: today
                )
            }

            if activeSessionCategory == .chores, durationMinutes >= 10 {
                seasonAchievementsStore.applyProgress(
                    conditionType: .choreBlitzSessions,
                    amount: 1,
                    date: today
                )
            }
        }
        let totalFocusMinutesToday = statsStore.totalFocusSecondsToday / 60
        if totalFocusMinutesToday >= 60 {
            seasonAchievementsStore.applyProgress(
                conditionType: .dailyFocusMinutesStreak,
                amount: 1,
                date: today
            )
        }
        let streakLevelUp = statsStore.registerActiveToday()
        let totalXPGained = statsStore.totalXP - xpBefore
        if streakLevelUp != nil {
            lastLevelUp = streakLevelUp
        } else {
            lastLevelUp = statsStore.lastLevelUp
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        withAnimation(.easeInOut(duration: 0.25)) {
            lastCompletedSession = SessionSummary(
                mode: selectedMode,
                duration: recordedDuration,
                xpGained: totalXPGained,
                timestamp: Date()
            )
        }
        pausedRemainingSeconds = 0
        currentSession = nil
        clearPersistedSession()
        handleHydrationThresholds(previousTotal: previousFocusTotal, newTotal: statsStore.totalFocusSecondsToday)
        _ = maybeScheduleHydrationReminder(
            reason: .timerCompleted,
            now: endDate,
            sessionCategory: timerCategory,
            sessionDurationMinutes: recordedDuration / 60,
            message: QuestChatStrings.Notifications.hydrateReminderBody
        )
        if #available(iOS 17.0, *) {
            Task {
                for activity in Activity<FocusSessionAttributes>.activities {
                    print("[FocusLiveActivity] Ending activity \(activity.id) after finish")
                    await activity.end(nil, dismissalPolicy: .immediate)
                }
                await MainActor.run {
                    self.liveActivity = nil
                }
            }
        } else if #available(iOS 16.1, *) {
            liveActivityManager?.end()
        }
        clearLiveActivityState()
        remainingSeconds = 0
        onSessionComplete?()
        activeSessionCategory = nil
    }

    private func resetForModeChange() {
        cancelCompletionNotifications()
        stopUITimer()
        pausedRemainingSeconds = currentDuration
        remainingSeconds = currentDuration
        hasFinishedOnce = false
        state = .idle
        timerState = .idle
    }

    private func requestNotificationAuthorization() {
        notificationCenter.requestAuthorization(options: [.alert, .badge, .sound]) { [weak self] granted, _ in
            DispatchQueue.main.async {
                self?.notificationAuthorized = granted
            }
        }
    }

    private func scheduleCompletionNotification() {
        guard notificationAuthorized else { return }
        cancelCompletionNotifications()

        let content = UNMutableNotificationContent()
        content.title = QuestChatStrings.Notifications.timerCompleteTitle
        content.body = QuestChatStrings.Notifications.timerCompleteBody
        content.sound = .default

        guard let session = currentSession else { return }
        let interval = session.endDate.timeIntervalSinceNow
        guard interval > 0 else { return }

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request = UNNotificationRequest(identifier: "focus_timer_completion", content: content, trigger: trigger)
        notificationCenter.add(request)
    }

    private func cancelCompletionNotifications() {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: ["focus_timer_completion"])
    }

    func handleScenePhaseChange(_ phase: ScenePhase) {
        // Only handle actual scene phase changes, not redundant calls
        // (e.g., when switching tabs within the app, phase stays .active)
        guard phase != lastScenePhase else {
            // Same phase as before - just ensure UI timer is running if needed
            if timerState == .running && currentSession != nil {
                startUITimer()
            }
            return
        }
        
        let previousPhase = lastScenePhase
        lastScenePhase = phase
        
        switch phase {
        case .active:
            // App came to the foreground: restore and snap timer into sync
            restorePersistedSessionIfNeeded()
            syncRemainingSecondsNow()
            startUITimer()
            startReminderTimer()
            refreshReminderScheduling()
            handleSessionCompletionIfNeeded()
        case .background:
            // App going to background: save state and stop UI timer
            persistCurrentSessionIfNeeded()
            scheduleCompletionNotification()
            stopUITimer()
            stopReminderTimer()
            scheduleBackgroundReminders()
        default:
            break
        }
    }

    func handleAppear() {
        // 🚨 NUCLEAR OPTION: Uncomment these lines to kill all Live Activities on startup
        // This prevents category mismatch issues but means users lose their running timers
        // if #available(iOS 17.0, *) {
        //     Task {
        //         for activity in Activity<FocusSessionAttributes>.activities {
        //             await activity.end(nil, dismissalPolicy: .immediate)
        //             print("[FocusLiveActivity] Killed stale activity \(activity.id) on app start")
        //         }
        //     }
        //     return  // Don't restore if we're killing everything
        // }
        
        // Only restore Live Activity if we don't already have timer state
        if #available(iOS 17.0, *), timerState == .idle, currentSession == nil, pausedRemainingSeconds == nil {
            restoreLiveActivityIfNeeded()
        }
        
        // Make the in-app timer label catch up immediately
        syncRemainingSecondsNow()
        startReminderTimer()
        refreshReminderScheduling()
    }

    private func handleSessionCompletionIfNeeded() {
        guard let session = currentSession else { return }
        if Date() >= session.endDate {
            finishSession()
        }
    }

    private func syncRemainingSecondsNow() {
        let now = Date()

        if let session = currentSession {
            // Timer is running: recompute based on endDate
            let newRemaining = max(Int(ceil(session.endDate.timeIntervalSince(now))), 0)
            if newRemaining != remainingSeconds {
                remainingSeconds = newRemaining
            }
        } else if timerState == .paused, let paused = pausedRemainingSeconds {
            // Timer is paused: keep using the paused snapshot
            if paused != remainingSeconds {
                remainingSeconds = paused
            }
        }
    }

    private func persistCurrentSessionIfNeeded() {
        guard state == .running else {
            clearPersistedSession()
            return
        }

        guard let session = currentSession else {
            clearPersistedSession()
            return
        }

        if let data = try? JSONEncoder().encode(session) {
            userDefaults.set(data, forKey: Self.persistedSessionKey)
        }
    }

    private func restorePersistedSessionIfNeeded() {
        guard currentSession == nil else { return }
        guard let data = userDefaults.data(forKey: Self.persistedSessionKey),
              let session = try? JSONDecoder().decode(FocusSession.self, from: data) else { return }

        userDefaults.removeObject(forKey: Self.persistedSessionKey)
        currentSession = session
        activeSessionDuration = Int(session.duration)
        selectedMode = session.type
        
        // Restore the category if it was saved with the session
        if let savedCategory = session.category {
            activeSessionCategory = savedCategory
        }
        
        timerState = .running
        state = .running
        remainingSeconds = max(Int(ceil(session.endDate.timeIntervalSinceNow)), 0)
    }

    private func clearPersistedSession() {
        userDefaults.removeObject(forKey: Self.persistedSessionKey)
    }

    func reminderIconName(for type: ReminderType) -> String {
        switch type {
        case .hydration:
            return "drop.fill"
        case .posture:
            return "figure.stand"
        }
    }

    func reminderTitle(for type: ReminderType) -> String {
        switch type {
        case .hydration:
            return QuestChatStrings.Reminders.hydrationTitle
        case .posture:
            return QuestChatStrings.Reminders.postureTitle
        }
    }

    func reminderBody(for type: ReminderType) -> String {
        switch type {
        case .hydration:
            return QuestChatStrings.Reminders.hydrationBody
        case .posture:
            return QuestChatStrings.Reminders.postureBody
        }
    }

    private func handleHydrationThresholds(previousTotal: Int, newTotal: Int) {
        guard hydrationNudgesEnabled, selectedMode == .focus else { return }

        for level in HydrationNudgeLevel.allCases {
            let threshold = level.thresholdSeconds
            guard previousTotal < threshold, newTotal >= threshold else { continue }
            guard !hasTriggeredNudge(for: level) else { continue }

            if maybeScheduleHydrationReminder(reason: .periodic, message: level.bodyText) {
                markNudgeTriggered(for: level)
            }
        }
    }

    private func bindHealthBarViewModel(_ healthBarViewModel: HealthBarViewModel) {
        healthBarViewModel.$inputs
            .debounce(for: .milliseconds(50), scheduler: RunLoop.main)
            .receive(on: RunLoop.main)
            .sink { [weak self] inputs in
                self?.updateWaterIntakeTotals()
                self?.healthStatsStore.update(from: inputs)
                self?.syncPlayerHP()
                self?.evaluateHealthXPBonuses()
                self?.checkHPCheckinQuestEvent()
                self?.evaluateWellnessAchievements()
            }
            .store(in: &cancellables)
    }

    private func syncPlayerHP(with hp: Int? = nil) {
        let currentHP = hp ?? healthStatsStore.currentHP
        playerStateStore.currentHP = currentHP
        playerStateStore.maxHP = healthStatsStore.maxHP
    }

    private var waterGoalToday: Int { hydrationSettingsStore.dailyWaterGoalOunces }

    private var waterIntakeOuncesToday: Int {
        (healthBarViewModel?.inputs.hydrationCount ?? 0) * hydrationSettingsStore.ouncesPerWaterTap
    }

    private var didHitWaterGoalToday: Bool {
        waterGoalToday > 0 && waterIntakeOuncesToday >= waterGoalToday
    }

    private var healthComboIsComplete: Bool {
        let gutStatus = healthBarViewModel?.inputs.gutStatus ?? .none
        let moodStatus = healthBarViewModel?.inputs.moodStatus ?? .none
        return gutStatus != .none && moodStatus != .none && hasLoggedSleepQualityToday
    }

    private func refreshDailyHealthBonusState(today: Date = Date()) {
        waterGoalXPGrantedToday = isDate(userDefaults.object(forKey: HealthTrackingStorageKeys.waterGoalAwardDate) as? Date, inSameDayAs: today)
        healthComboXPGrantedToday = isDate(userDefaults.object(forKey: HealthTrackingStorageKeys.healthComboAwardDate) as? Date, inSameDayAs: today)
        hasLoggedSleepQualityToday = isDate(userDefaults.object(forKey: HealthTrackingStorageKeys.sleepQualityLogged) as? Date, inSameDayAs: today)
        hpCheckinQuestSentDate = userDefaults.object(forKey: HealthTrackingStorageKeys.hpCheckinQuestDate) as? Date
        hydrationGoalQuestSentDate = userDefaults.object(forKey: HealthTrackingStorageKeys.hydrationGoalQuestDate) as? Date
        updateWaterIntakeTotals()
    }

    private func persistSleepQualitySelection() {
        let today = Calendar.current.startOfDay(for: Date())
        userDefaults.set(sleepQuality.rawValue, forKey: HealthTrackingStorageKeys.sleepQualityValue)
        userDefaults.set(today, forKey: HealthTrackingStorageKeys.sleepQualityDate)
        userDefaults.set(today, forKey: HealthTrackingStorageKeys.sleepQualityLogged)
        hasLoggedSleepQualityToday = true
        sleepHistoryStore.record(quality: sleepQuality, date: today)
        checkHPCheckinQuestEvent()
    }

    private func loadSleepQuality() {
        isLoadingSleepData = true
        let today = Calendar.current.startOfDay(for: Date())

        if
            let storedDate = userDefaults.object(forKey: HealthTrackingStorageKeys.sleepQualityDate) as? Date,
            Calendar.current.isDate(storedDate, inSameDayAs: today),
            let storedQuality = SleepQuality(rawValue: userDefaults.integer(forKey: HealthTrackingStorageKeys.sleepQualityValue))
        {
            sleepQuality = storedQuality
            hasLoggedSleepQualityToday = isDate(userDefaults.object(forKey: HealthTrackingStorageKeys.sleepQualityLogged) as? Date, inSameDayAs: today)
        } else {
            sleepQuality = .okay
            hasLoggedSleepQualityToday = false
        }

        isLoadingSleepData = false
    }

    private func persistActivityLevelSelection() {
        guard let activityLevel else {
            clearActivityLevel()
            return
        }

        let today = Calendar.current.startOfDay(for: Date())
        userDefaults.set(activityLevel.rawValue, forKey: HealthTrackingStorageKeys.activityLevelValue)
        userDefaults.set(today, forKey: HealthTrackingStorageKeys.activityLevelDate)
        userDefaults.set(today, forKey: HealthTrackingStorageKeys.activityLevelLogged)
        hasLoggedActivityToday = true
        activityHistoryStore.record(level: activityLevel, date: today)
    }

    private func loadActivityLevel() {
        isLoadingActivityData = true
        let today = Calendar.current.startOfDay(for: Date())

        if
            let storedDate = userDefaults.object(forKey: HealthTrackingStorageKeys.activityLevelDate) as? Date,
            Calendar.current.isDate(storedDate, inSameDayAs: today),
            let storedLevel = ActivityLevel(rawValue: userDefaults.integer(forKey: HealthTrackingStorageKeys.activityLevelValue))
        {
            activityLevel = storedLevel
            hasLoggedActivityToday = isDate(userDefaults.object(forKey: HealthTrackingStorageKeys.activityLevelLogged) as? Date, inSameDayAs: today)
        } else {
            activityLevel = nil
            hasLoggedActivityToday = false
        }

        isLoadingActivityData = false
    }

    private func clearActivityLevel() {
        let today = Calendar.current.startOfDay(for: Date())
        userDefaults.removeObject(forKey: HealthTrackingStorageKeys.activityLevelValue)
        userDefaults.removeObject(forKey: HealthTrackingStorageKeys.activityLevelDate)
        userDefaults.removeObject(forKey: HealthTrackingStorageKeys.activityLevelLogged)
        hasLoggedActivityToday = false
        activityHistoryStore.removeRecord(on: today)
    }

    private func evaluateHealthXPBonuses() {
        let today = Date()
        refreshDailyHealthBonusState(today: today)

        if didHitWaterGoalToday && !waterGoalXPGrantedToday {
            statsStore.grantXP(10, reason: .waterGoal)
            waterGoalXPGrantedToday = true
            userDefaults.set(Calendar.current.startOfDay(for: today), forKey: HealthTrackingStorageKeys.waterGoalAwardDate)
        }

        if didHitWaterGoalToday && !isDate(hydrationGoalQuestSentDate, inSameDayAs: today) {
            let startOfDay = Calendar.current.startOfDay(for: today)
            hydrationGoalQuestSentDate = startOfDay
            userDefaults.set(startOfDay, forKey: HealthTrackingStorageKeys.hydrationGoalQuestDate)
            statsStore.questEventHandler?(.hydrationGoalReached)
            statsStore.questEventHandler?(.hydrationGoalDayCompleted)
            seasonAchievementsStore.applyProgress(
                conditionType: .hydrationDaysReached,
                amount: 1,
                date: startOfDay
            )
        }

        if healthComboIsComplete && !healthComboXPGrantedToday {
            statsStore.grantXP(10, reason: .healthCombo)
            healthComboXPGrantedToday = true
            userDefaults.set(Calendar.current.startOfDay(for: today), forKey: HealthTrackingStorageKeys.healthComboAwardDate)
        }
    }

    private func evaluateWellnessAchievements(today: Date = Date()) {
        let calendar = Calendar.current
        let day = calendar.startOfDay(for: today)

        guard let todaySummary = healthStatsStore.days.first(where: { calendar.isDate($0.date, inSameDayAs: day) }) else {
            return
        }

        let averageHPFraction = todaySummary.averageHP / Double(healthStatsStore.maxHP)
        if averageHPFraction >= 0.70 {
            seasonAchievementsStore.applyProgress(
                conditionType: .hpAboveThresholdDays,
                amount: 1,
                date: day
            )
        }

        if todaySummary.lastMood == .good {
            seasonAchievementsStore.applyProgress(
                conditionType: .moodAboveMehDaysStreak,
                amount: 1,
                date: day
            )
        }
    }

    private func checkHPCheckinQuestEvent() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        if let hpCheckinQuestSentDate,
           calendar.isDate(hpCheckinQuestSentDate, inSameDayAs: today) {
            return
        }

        let hasGutStatus = gutStatus != .none
        let hasMoodStatus = moodStatus != .none

        guard hasGutStatus, hasMoodStatus, hasLoggedSleepQualityToday else { return }

        // Don't trigger quest completion during onboarding
        let hasCompletedOnboarding = userDefaults.bool(forKey: "hasCompletedOnboarding")
        guard hasCompletedOnboarding else { return }

        hpCheckinQuestSentDate = today
        userDefaults.set(today, forKey: HealthTrackingStorageKeys.hpCheckinQuestDate)
        statsStore.questEventHandler?(.hpCheckinCompleted)
    }

    private func updateWaterIntakeTotals() {
        totalWaterOuncesToday = waterIntakeOuncesToday
    }

    private func isDate(_ date: Date?, inSameDayAs target: Date = Date()) -> Bool {
        guard let date else { return false }
        return Calendar.current.isDate(date, inSameDayAs: target)
    }

    private func hasTriggeredNudge(for level: HydrationNudgeLevel) -> Bool {
        let calendar = Calendar.current
        let storedDate = userDefaults.object(forKey: level.triggerKey) as? Date
        return calendar.isDateInToday(storedDate ?? Date.distantPast)
    }

    private func markNudgeTriggered(for level: HydrationNudgeLevel) {
        let today = Calendar.current.startOfDay(for: Date())
        userDefaults.set(today, forKey: level.triggerKey)
    }

    private func startReminderTimer() {
        reminderTimerCancellable?.cancel()
        reminderTimerCancellable = Timer.publish(every: 60, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] date in
                self?.evaluateReminders(now: date)
            }
    }

    private func stopReminderTimer() {
        reminderTimerCancellable?.cancel()
        reminderTimerCancellable = nil
    }

    private func refreshReminderScheduling(now: Date = Date(), shouldEvaluateImmediately: Bool = true) {
        if shouldEvaluateImmediately {
            evaluateReminders(now: now)
        }
        scheduleBackgroundReminders(now: now)
    }

    private func evaluateReminders(now: Date = Date()) {
        _ = maybeScheduleHydrationReminder(reason: .periodic, now: now)

        ReminderType.allCases.filter { $0 != .hydration }.forEach { type in
            guard shouldFireReminder(for: type, at: now) else { return }
            triggerReminder(for: type, at: now)
        }
    }

    private func triggerReminder(
        for type: ReminderType,
        at date: Date = Date(),
        message: String? = nil,
        bypassCadence: Bool = false
    ) {
        let settings = reminderSettingsStore.settings(for: type)
        guard settings.enabled else { return }

        if type == .posture, settings.onlyDuringFocusSessions, !isFocusSessionActive {
            return
        }

        if !bypassCadence, !shouldFireReminder(for: type, at: date) {
            return
        }

        let event = ReminderEvent(
            id: UUID(),
            type: type,
            firedAt: date,
            responded: false,
            respondedAt: nil
        )
        lastReminderFiredAt[type] = date
        userDefaults.set(date, forKey: Self.reminderLastFiredKey(for: type))
        reminderEventsStore.log(event: event)

        switch type {
        case .hydration:
            statsStore.questEventHandler?(.hydrationReminderFired)
        case .posture:
            statsStore.questEventHandler?(.postureReminderFired)
        }

        // If there's already an active reminder or items in queue, add to queue
        if activeReminderEvent != nil || !reminderQueue.isEmpty {
            reminderQueue.append((event, message ?? reminderBody(for: type)))
        } else {
            presentInAppReminder(event: event, message: message ?? reminderBody(for: type))
        }
        
        scheduleLocalNotification(for: type, message: message)
        scheduleBackgroundReminders(now: date)
    }

    private func presentInAppReminder(event: ReminderEvent, message: String) {
        // If the app is in the background, queue it to show when user returns
        guard isAppInForeground else {
            pendingBackgroundReminder = (event, message)
            return
        }
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            activeReminderEvent = event
            activeReminderMessage = message
        }

        // Auto-dismiss after 30 seconds if not acknowledged, then show next in queue
        DispatchQueue.main.asyncAfter(deadline: .now() + 30) { [weak self] in
            guard let self else { return }
            // Only dismiss if this is still the active reminder
            if self.activeReminderEvent?.id == event.id {
                self.dismissActiveReminderAndShowNext()
            }
        }
    }
    
    private func dismissActiveReminderAndShowNext() {
        withAnimation(.easeInOut(duration: 0.2)) {
            activeReminderEvent = nil
            activeReminderMessage = nil
        }
        
        // Process next reminder in queue after a brief delay
        if !reminderQueue.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                guard let self else { return }
                guard let next = self.reminderQueue.first else { return }
                self.reminderQueue.removeFirst()
                self.presentInAppReminder(event: next.event, message: next.message)
            }
        }
    }

    private func scheduleLocalNotification(for type: ReminderType, message: String?) {
        guard notificationAuthorized else { return }

        let content = UNMutableNotificationContent()
        content.title = reminderTitle(for: type)
        content.body = message ?? reminderBody(for: type)
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let identifier = "reminder_fire_\(type.rawValue)_\(UUID().uuidString)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        notificationCenter.add(request)
    }

    @discardableResult
    private func maybeScheduleHydrationReminder(
        reason: HydrationReminderReason,
        now: Date = Date(),
        sessionCategory: TimerCategory.Kind? = nil,
        sessionDurationMinutes: Int? = nil,
        message: String? = nil
    ) -> Bool {
        return hydrationReminderManager.maybeScheduleHydrationReminder(
            reason: reason,
            now: now,
            waterIntakeOuncesToday: waterIntakeOuncesToday,
            waterGoalOunces: waterGoalToday,
            isFocusSessionContextActive: isFocusSessionActive || reason == .timerCompleted,
            sessionCategory: sessionCategory,
            sessionDurationMinutes: sessionDurationMinutes
        ) { [weak self] in
            guard let self else { return }
            self.triggerReminder(
                for: .hydration,
                at: now,
                message: message ?? self.reminderBody(for: .hydration),
                bypassCadence: true
            )
        }
    }

    private func scheduleBackgroundReminders(now: Date = Date()) {
        scheduleNextHydrationReminder(now: now)

        ReminderType.allCases
            .filter { $0 != .hydration }
            .forEach { type in
                scheduleNextReminderNotification(for: type, now: now)
            }
    }

    private func scheduleNextReminderNotification(for type: ReminderType, now: Date = Date()) {
        let identifier = reminderNotificationIdentifiers[type] ?? "reminder_\(type.rawValue)_next"
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [identifier])
        guard notificationAuthorized else { return }
        guard let next = nextReminderDate(for: type, from: now) else { return }

        let content = UNMutableNotificationContent()
        content.title = reminderTitle(for: type)
        content.body = reminderBody(for: type)
        content.sound = .default

        let components = Calendar.current.dateComponents([
            .year, .month, .day, .hour, .minute, .second
        ], from: next)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        notificationCenter.add(request)
    }

    private func scheduleNextHydrationReminder(now: Date = Date()) {
        let identifier = reminderNotificationIdentifiers[.hydration] ?? "hydration_reminder_next"
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [identifier])
        guard notificationAuthorized else { return }
        guard let next = hydrationReminderManager.nextEligibleReminderDate(
            now: now,
            waterIntakeOuncesToday: waterIntakeOuncesToday,
            waterGoalOunces: waterGoalToday,
            isFocusSessionContextActive: isFocusSessionActive
        ) else { return }

        let content = UNMutableNotificationContent()
        content.title = reminderTitle(for: .hydration)
        content.body = reminderBody(for: .hydration)
        content.sound = .default

        let components = Calendar.current.dateComponents([
            .year, .month, .day, .hour, .minute, .second
        ], from: next)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        notificationCenter.add(request)
    }

    private func shouldFireReminder(for type: ReminderType, at date: Date) -> Bool {
        if type == .hydration {
            return hydrationReminderManager.canScheduleHydrationReminder(
                reason: .periodic,
                now: date,
                waterIntakeOuncesToday: waterIntakeOuncesToday,
                waterGoalOunces: waterGoalToday,
                isFocusSessionContextActive: isFocusSessionActive
            )
        }

        let settings = reminderSettingsStore.settings(for: type)
        guard settings.enabled else { return false }

        if type == .posture, settings.onlyDuringFocusSessions, !isFocusSessionActive {
            return false
        }

        guard isWithinActiveWindow(date, settings: settings) else { return false }
        let cadence = TimeInterval(settings.cadenceMinutes * 60)
        let lastFired = lastReminderFiredAt[type] ?? .distantPast
        return date.timeIntervalSince(lastFired) >= cadence
    }

    private func nextReminderDate(for type: ReminderType, from date: Date) -> Date? {
        if type == .hydration {
            return hydrationReminderManager.nextEligibleReminderDate(
                now: date,
                waterIntakeOuncesToday: waterIntakeOuncesToday,
                waterGoalOunces: waterGoalToday,
                isFocusSessionContextActive: isFocusSessionActive
            )
        }

        let settings = reminderSettingsStore.settings(for: type)
        guard settings.enabled else { return nil }

        if type == .posture, settings.onlyDuringFocusSessions, !isFocusSessionActive {
            return nil
        }

        let cadence = TimeInterval(settings.cadenceMinutes * 60)
        let lastFired = lastReminderFiredAt[type] ?? date
        let tentative = max(date, lastFired.addingTimeInterval(cadence))

        guard isWithinActiveWindow(tentative, settings: settings) else {
            return nextWindowStart(after: tentative, settings: settings)
        }

        return tentative
    }

    private func isWithinActiveWindow(_ date: Date, settings: ReminderSettings) -> Bool {
        let calendar = Calendar.current
        guard
            let start = calendar.date(bySettingHour: settings.activeStartHour, minute: 0, second: 0, of: date),
            let end = calendar.date(bySettingHour: settings.activeEndHour, minute: 0, second: 0, of: date)
        else { return true }

        if settings.activeStartHour == settings.activeEndHour {
            return true
        }

        if end > start {
            return date >= start && date <= end
        } else {
            return date >= start || date <= end
        }
    }

    private func nextWindowStart(after date: Date, settings: ReminderSettings) -> Date? {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = settings.activeStartHour
        components.minute = 0
        components.second = 0

        guard let todayStart = calendar.date(from: components) else { return nil }

        if date < todayStart {
            return todayStart
        }

        return calendar.date(byAdding: .day, value: 1, to: todayStart)
    }

    private var isFocusSessionActive: Bool { timerState == .running }

    private static func reminderLastFiredKey(for type: ReminderType) -> String {
        "reminder_last_fired_\(type.rawValue)"
    }

    private static func durationKey(for category: TimerCategory.Kind) -> String {
        "timerCategory_duration_\(category.rawValue)"
    }

    private func saveDuration(_ seconds: Int, for category: TimerCategory.Kind) {
        userDefaults.set(seconds, forKey: Self.durationKey(for: category))
    }
}

extension FocusViewModel {
    static func seededCategories() -> [TimerCategory] {
        [
            TimerCategory(id: .create, durationSeconds: 30 * 60),       // Create: 30 min (focus work)
            TimerCategory(id: .move, durationSeconds: 15 * 60),          // Move: 15 min (quick movement break)
            TimerCategory(id: .chores, durationSeconds: 20 * 60),        // Chores: 20 min (household tasks)
            TimerCategory(id: .focusMode, durationSeconds: 50 * 60),     // Focus: 50 min (deep work session)
            TimerCategory(id: .gamingReset, durationSeconds: 30 * 60),   // Gaming: 30 min (intentional break)
            TimerCategory(id: .selfCare, durationSeconds: 15 * 60),      // Self Care: 15 min (mindfulness/stretch)
        ]
    }
}

private extension FocusViewModel.HydrationNudgeLevel {
    var triggerKey: String {
        switch self {
        case .thirtyMinutes: return "hydrateNudge30Date"
        case .sixtyMinutes: return "hydrateNudge60Date"
        case .ninetyMinutes: return "hydrateNudge90Date"
        }
    }
}

import SwiftUI

extension FocusViewModel {
    func acknowledgeReminder(_ event: ReminderEvent) {
        reminderEventsStore.markResponded(eventId: event.id)
        
        // Trigger quest completion when user actually acknowledges the reminder
        if event.type == .posture {
            statsStore.questEventHandler?(.postureReminderAcknowledged)
        }
        
        dismissActiveReminderAndShowNext()
    }
    
    func dismissReminder() {
        // Dismiss without marking as responded - for swipe dismissal
        dismissActiveReminderAndShowNext()
    }
    
    func updateScenePhase(_ phase: ScenePhase) {
        let wasInForeground = isAppInForeground
        isAppInForeground = (phase == .active)
        
        // If we just came back to foreground and there's a pending reminder, show it
        if isAppInForeground && !wasInForeground, let pending = pendingBackgroundReminder {
            pendingBackgroundReminder = nil
            // Small delay to let the app settle
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                guard let self else { return }
                // If there's already an active reminder or queue, add to queue
                if self.activeReminderEvent != nil || !self.reminderQueue.isEmpty {
                    self.reminderQueue.append(pending)
                } else {
                    self.presentInAppReminder(event: pending.event, message: pending.message)
                }
            }
        }
    }

    func debugFireHydrationReminder() {
        #if DEBUG
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            self?.triggerReminder(for: .hydration, at: Date(), bypassCadence: true)
        }
        #endif
    }

    func debugFirePostureReminder() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            self?.triggerReminder(for: .posture, at: Date(), bypassCadence: true)
        }
    }
    
    // Added method to log a 1 oz hydration "sip"
    func logHydrationSip() {
        // Minimal, 1 oz increment for banner taps.
        recordHydration(ounces: 1)
        
        // Force update totals and sync to get accurate ounces from HealthStatsStore
        healthStatsStore.update(from: healthBarViewModel?.inputs ?? DailyHealthInputs(
            hydrationCount: 0,
            selfCareSessions: 0,
            focusSprints: 0,
            gutStatus: .none,
            moodStatus: .none
        ))
        
        // Post quest event to track hydration progress - get actual ounces from HealthStatsStore
        let today = Calendar.current.startOfDay(for: Date())
        let todayOunces = healthStatsStore.days.first(where: { Calendar.current.isDate($0.date, inSameDayAs: today) })?.hydrationOunces ?? 0
        
        let mlPerOunce = 29.57
        let amountMl = Int((1.0 * mlPerOunce).rounded())  // 1 oz in ml
        let totalMl = Int((Double(todayOunces) * mlPerOunce).rounded())
        let percentOfGoal = waterGoalToday > 0 ? Double(todayOunces) / Double(waterGoalToday) : 0
        statsStore.questEventHandler?(
            .hydrationLogged(
                amountMl: amountMl,
                totalMlToday: totalMl,
                percentOfGoal: percentOfGoal
            )
        )
        
        syncPlayerHP()
        evaluateHealthXPBonuses()
    }
}

private extension FocusViewModel {
    func recordHydration(ounces: Int) {
        healthBarViewModel?.logHydration(ounces: ounces)
    }
}

