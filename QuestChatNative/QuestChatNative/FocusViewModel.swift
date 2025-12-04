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
        case deepFocus
        case workSprint
        case choresSprint
        case selfCare
        case gamingReset
        case quickBreak

        var title: String {
            switch self {
            case .deepFocus:
                return QuestChatStrings.TimerCategories.deepFocusTitle
            case .workSprint:
                return QuestChatStrings.TimerCategories.workSprintTitle
            case .choresSprint:
                return QuestChatStrings.TimerCategories.choresSprintTitle
            case .selfCare:
                return QuestChatStrings.TimerCategories.selfCareTitle
            case .gamingReset:
                return QuestChatStrings.TimerCategories.gamingResetTitle
            case .quickBreak:
                return QuestChatStrings.TimerCategories.quickBreakTitle
            }
        }

        var subtitle: String {
            switch self {
            case .deepFocus:
                return QuestChatStrings.TimerCategories.deepFocusSubtitle
            case .workSprint:
                return QuestChatStrings.TimerCategories.workSprintSubtitle
            case .choresSprint:
                return QuestChatStrings.TimerCategories.choresSprintSubtitle
            case .selfCare:
                return QuestChatStrings.TimerCategories.selfCareSubtitle
            case .gamingReset:
                return QuestChatStrings.TimerCategories.gamingResetSubtitle
            case .quickBreak:
                return QuestChatStrings.TimerCategories.quickBreakSubtitle
            }
        }

        var mode: FocusTimerMode {
            switch self {
            case .deepFocus, .workSprint, .choresSprint:
                return .focus
            case .selfCare, .gamingReset, .quickBreak:
                return .selfCare
            }
        }

        var systemImageName: String {
            switch self {
            case .deepFocus:
                return "brain.head.profile"
            case .workSprint:
                return "bolt.circle"
            case .choresSprint:
                return "house.fill"
            case .selfCare:
                return "figure.mind.and.body"
            case .gamingReset:
                return "gamecontroller"
            case .quickBreak:
                return "cup.and.saucer.fill"
            }
        }
    }

    let id: Kind
    var durationSeconds: Int
}

enum FocusArea: String, CaseIterable, Identifiable, Codable {
    case work
    case home
    case health
    case chill

    var id: String { rawValue }

    var title: String {
        switch self {
        case .work:
            return QuestChatStrings.FocusAreaTitles.work
        case .home:
            return QuestChatStrings.FocusAreaTitles.home
        case .health:
            return QuestChatStrings.FocusAreaTitles.health
        case .chill:
            return QuestChatStrings.FocusAreaTitles.chill
        }
    }

    var emoji: String {
        switch self {
        case .work:
            return "💼"
        case .home:
            return "🏡"
        case .health:
            return "💪"
        case .chill:
            return "😌"
        }
    }
}

struct DailyConfig: Codable {
    let date: Date
    let focusArea: FocusArea
    let dailyMinutesGoal: Int
}

enum DailyEnergyLevel: String, CaseIterable, Identifiable {
    case low
    case medium
    case high

    var id: String { rawValue }

    var title: String {
        rawValue.capitalized
    }

    var suggestedMinutes: Int {
        switch self {
        case .low:
            return 20
        case .medium:
            return 40
        case .high:
            return 60
        }
    }

    var emoji: String {
        switch self {
        case .low:
            return "🌙"
        case .medium:
            return "🌤️"
        case .high:
            return "☀️"
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

    @Published private(set) var focusSeconds: Int
    @Published private(set) var selfCareSeconds: Int
    @Published private(set) var sessionsCompleted: Int
    @Published private(set) var momentum: Double
    @Published private(set) var sessionHistory: [SessionRecord]
    @Published private(set) var totalFocusSecondsToday: Int
    @Published var pendingLevelUp: Int?
    @Published private(set) var dailyConfig: DailyConfig?
    @Published var shouldShowDailySetup: Bool = false
    @Published private(set) var lastWeeklyGoalBonusAwardedDate: Date?
    @Published private(set) var progression: ProgressionState
    @Published var lastLevelUp: LevelUpResult?

    private(set) var lastKnownLevel: Int

    private let playerStateStore: PlayerStateStore
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

    var playerTitle: String {
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

    var dailyMinutesGoal: Int? { dailyConfig?.dailyMinutesGoal }

    var dailyMinutesProgress: Int {
        totalFocusSecondsToday / 60
    }

    init(userDefaults: UserDefaults = .standard, playerStateStore: PlayerStateStore) {
        self.userDefaults = userDefaults
        self.playerStateStore = playerStateStore
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

        let storedMomentum = userDefaults.double(forKey: Keys.momentum)
        let clampedMomentum = max(0, min(storedMomentum, 1))
        momentum = clampedMomentum

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

        lastSessionDate = userDefaults.object(forKey: Keys.lastSessionDate) as? Date
        let storedLastMomentumUpdate = userDefaults.object(forKey: Keys.lastMomentumUpdate) as? Date
        lastMomentumUpdate = storedLastMomentumUpdate ?? lastSessionDate
        if clampedMomentum > 0, lastMomentumUpdate == nil {
            lastMomentumUpdate = Date()
        }

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

        let storedConfig = Self.decodeConfig(from: userDefaults.data(forKey: Keys.dailyConfig))
        dailyConfig = storedConfig
        shouldShowDailySetup = !Self.isConfigValidForToday(storedConfig)

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
        refreshMomentumIfNeeded()
        evaluateWeeklyGoalBonus()

        syncPlayerStateProgress()
    }

    @discardableResult
    func recordSession(mode: FocusTimerMode, duration: Int) -> Int {
        refreshDailyTotalsIfNeeded()
        refreshMomentumIfNeeded()

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

        let _ = registerCompletedSession(duration: TimeInterval(duration))

        momentum = 0
        lastSessionDate = now
        lastMomentumUpdate = now
        persist()
        evaluateWeeklyGoalBonus()
        return progression.totalXP - xpBefore
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

        lastSessionDate = sessionHistory.map { $0.date }.max()
        lastMomentumUpdate = lastSessionDate
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
        let isValid = Self.isConfigValidForToday(dailyConfig, today: today)
        if !isValid {
            dailyConfig = nil
            persistDailyConfig(nil)
        }
        shouldShowDailySetup = !isValid
    }

    func completeDailyConfig(focusArea: FocusArea, energyLevel: DailyEnergyLevel) {
        let today = Calendar.current.startOfDay(for: Date())
        let config = DailyConfig(
            date: today,
            focusArea: focusArea,
            dailyMinutesGoal: energyLevel.suggestedMinutes
        )
        dailyConfig = config
        shouldShowDailySetup = false
        persistDailyConfig(config)
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

        if level > previousLevel {
            let result = LevelUpResult(oldLevel: previousLevel, newLevel: level)
            lastLevelUp = result
            pendingLevelUp = level
        } else {
            lastLevelUp = nil
            pendingLevelUp = nil
        }
        lastKnownLevel = level
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
        totalFocusSecondsToday = 0
        userDefaults.set(Calendar.current.startOfDay(for: Date()), forKey: Keys.totalFocusDate)
        lastKnownLevel = level
        pendingLevelUp = nil
        sessionHistory = []
        momentum = 0
        lastSessionDate = nil
        lastMomentumUpdate = nil
        lastWeeklyGoalBonusAwardedDate = nil
        lastLevelUp = nil
        persist()
    }

    var currentMomentum: Double {
        // Return a computed value without mutating @Published properties to avoid publishing during view updates
        return computeDecayedMomentum(now: Date())
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

        // Removing XP should not trigger a level-up modal
        pendingLevelUp = nil
        lastLevelUp = nil

        // Keep player state in sync and persist
        syncPlayerStateProgress()
        saveProgression()
        persist()
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

    private func computeDecayedMomentum(now: Date) -> Double {
        guard let lastUpdate = lastMomentumUpdate else { return momentum }
        let elapsed = now.timeIntervalSince(lastUpdate)
        guard elapsed > 0, momentum > 0 else { return momentum }
        guard momentumDecayDuration > 0 else { return momentum }
        let decayAmount = elapsed / momentumDecayDuration
        guard decayAmount > 0 else { return momentum }
        return max(0, momentum - decayAmount)
    }

    func refreshMomentumIfNeeded(now: Date = Date()) {
        let newMomentum = computeDecayedMomentum(now: now)
        // If nothing changes, still update lastMomentumUpdate and persist asynchronously
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if newMomentum != self.momentum {
                self.momentum = newMomentum
            }
            self.lastMomentumUpdate = now
            self.persistMomentum()
        }
    }

    var weeklyGoalProgress: [WeeklyGoalDayStatus] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let goalMinutes = dailyMinutesGoal ?? 40

        let statuses: [WeeklyGoalDayStatus] = stride(from: -6, through: 0, by: 1).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: today) else { return nil }
            let focusSecondsForDay = focusSeconds(on: date)
            let goalHit = goalMinutes > 0 && focusSecondsForDay >= goalMinutes * 60
            let isToday = calendar.isDate(date, inSameDayAs: today)
            return WeeklyGoalDayStatus(date: date, goalHit: goalHit, isToday: isToday)
        }

        return statuses
    }

    private let userDefaults: UserDefaults
    private var lastSessionDate: Date?
    private var lastMomentumUpdate: Date?
    private static let progressionDefaultsKey = "progression_state_v1"

    private let momentumIncrement: Double = 0.25
    private let momentumDecayDuration: TimeInterval = 4 * 60 * 60
    private let momentumBonusMultiplier: Double = 0.2

    private enum Keys {
        static let focusSeconds = "focusSeconds"
        static let selfCareSeconds = "selfCareSeconds"
        static let sessionsCompleted = "sessionsCompleted"
        static let xp = "xp"
        static let sessionHistory = "sessionHistory"
        static let lastKnownLevel = "lastKnownLevel"
        static let totalFocusSecondsToday = "totalFocusSecondsToday"
        static let totalFocusDate = "totalFocusDate"
        static let dailyConfig = "dailyConfig"
        static let momentum = "momentum"
        static let lastSessionDate = "lastSessionDate"
        static let lastMomentumUpdate = "lastMomentumUpdate"
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
        persistMomentum()
        persistDailyConfig(dailyConfig)
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
    }

    private func persistDailyConfig(_ config: DailyConfig?) {
        guard let config else {
            userDefaults.removeObject(forKey: Keys.dailyConfig)
            return
        }

        if let data = try? JSONEncoder().encode(config) {
            userDefaults.set(data, forKey: Keys.dailyConfig)
        }
    }

    private static func decodeConfig(from data: Data?) -> DailyConfig? {
        guard let data else { return nil }
        return try? JSONDecoder().decode(DailyConfig.self, from: data)
    }

    private static func isConfigValidForToday(_ config: DailyConfig?, today: Date = Calendar.current.startOfDay(for: Date())) -> Bool {
        guard let config else { return false }
        return Calendar.current.isDate(config.date, inSameDayAs: today)
    }

    var currentStreakDays: Int { progression.streakDays }

    private func persistMomentum() {
        userDefaults.set(momentum, forKey: Keys.momentum)
        if let lastSessionDate {
            userDefaults.set(lastSessionDate, forKey: Keys.lastSessionDate)
        } else {
            userDefaults.removeObject(forKey: Keys.lastSessionDate)
        }

        if let lastMomentumUpdate {
            userDefaults.set(lastMomentumUpdate, forKey: Keys.lastMomentumUpdate)
        } else {
            userDefaults.removeObject(forKey: Keys.lastMomentumUpdate)
        }
    }

    private func focusSeconds(on day: Date) -> Int {
        let calendar = Calendar.current
        let targetDay = calendar.startOfDay(for: day)
        return sessionHistory
            .filter { calendar.isDate($0.date, inSameDayAs: targetDay) }
            .reduce(0) { $0 + $1.durationSeconds }
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

    struct HydrationNudge: Identifiable {
        let id = UUID()
        let level: HydrationNudgeLevel
        let message: String
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
    @Published var activeHydrationNudge: HydrationNudge?
    @Published var lastLevelUp: SessionStatsStore.LevelUpResult?
    @Published var sleepQuality: SleepQuality = .okay {
        didSet {
            guard !isLoadingSleepData else { return }
            persistSleepQualitySelection()
            evaluateHealthXPBonuses()
        }
    }
    @Published var totalWaterOuncesToday: Int = 0
    @Published var totalComfortOuncesToday: Int = 0
    @Published private var waterGoalXPGrantedToday = false
    @Published private var healthComboXPGrantedToday = false
    @Published var timerState: FocusTimerState = .idle
    @Published var remainingSeconds: Int = 0

    var onSessionComplete: (() -> Void)?

    enum TimerState {
        case idle
        case running
        case paused
        case finished
    }

    @Published var state: TimerState = .idle

    @Published private(set) var notificationAuthorized: Bool = false
    let statsStore: SessionStatsStore
    let playerStateStore: PlayerStateStore
    let healthStatsStore: HealthBarIRLStatsStore
    let hydrationSettingsStore: HydrationSettingsStore
    private var cancellables = Set<AnyCancellable>()
    private var healthBarViewModel: HealthBarViewModel?

    @Published private var pausedRemainingSeconds: Int?
    @Published private var timerTick: Date = Date()
    private var timerCancellable: AnyCancellable?
    @AppStorage("hydrateNudgesEnabled") private var hydrateNudgesEnabled: Bool = true
    private let notificationCenter = UNUserNotificationCenter.current()
    private let userDefaults = UserDefaults.standard
    private var activeSessionCategory: TimerCategory.Kind?
    private var hpCheckinQuestSentDate: Date?

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

    init(
        statsStore: SessionStatsStore = SessionStatsStore(playerStateStore: DependencyContainer.shared.playerStateStore),
        playerStateStore: PlayerStateStore = DependencyContainer.shared.playerStateStore,
        healthStatsStore: HealthBarIRLStatsStore = HealthBarIRLStatsStore(),
        healthBarViewModel: HealthBarViewModel? = nil,
        hydrationSettingsStore: HydrationSettingsStore = HydrationSettingsStore(),
        initialMode: FocusTimerMode = .focus
    ) {
        // Assign non-dependent stored properties first
        self.statsStore = statsStore
        self.playerStateStore = playerStateStore
        self.healthStatsStore = healthStatsStore
        self.healthBarViewModel = healthBarViewModel
        self.hydrationSettingsStore = hydrationSettingsStore
        self.currentHP = healthStatsStore.currentHP
        hpCheckinQuestSentDate = userDefaults.object(forKey: HealthTrackingStorageKeys.hpCheckinQuestDate) as? Date
        // Defer syncing player HP until after initialization completes to avoid using self too early.
        let initialHP = healthStatsStore.currentHP

        let seeded = FocusViewModel.seededCategories()
        let loadedCategories: [TimerCategory] = seeded.map { base in
            let key = Self.durationKey(for: base.id)
            let storedSeconds = UserDefaults.standard.integer(forKey: key)
            let duration = storedSeconds > 0 ? storedSeconds : base.durationSeconds
            return TimerCategory(id: base.id, durationSeconds: duration)
        }
        self.categories = loadedCategories

        let initialCategory = loadedCategories.first { $0.id.mode == initialMode } ?? loadedCategories[0]
        self.selectedCategory = initialCategory.id
        self.selectedMode = initialCategory.id.mode
        self.pausedRemainingSeconds = initialCategory.durationSeconds
        self.remainingSeconds = initialCategory.durationSeconds

        hasInitialized = true

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

        if let healthBarViewModel {
            bindHealthBarViewModel(healthBarViewModel)
        }

        if #available(iOS 17.0, *) {
            restoreLiveActivityIfNeeded()
        }

        refreshDailyHealthBonusState()
        loadSleepQuality()
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

    var isRunning: Bool { state == .running }

    var hydrationNudgesEnabled: Bool { hydrateNudgesEnabled }

    func logHydrationPillTapped() {
        guard let healthBarViewModel else { return }

        // HP updates are capped inside HealthBarViewModel; still log even when already at max HP.
        healthBarViewModel.logHydration()

        updateWaterIntakeTotals()
        healthStatsStore.update(from: healthBarViewModel.inputs)
        syncPlayerHP()
        evaluateHealthXPBonuses()
        statsStore.questEventHandler?(.hydrationIntakeLogged(totalOuncesToday: totalWaterOuncesToday))
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

        healthBarViewModel.logFocusSprint()
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

        let session = FocusSession(
            id: currentSession?.id ?? UUID(),
            type: selectedMode,
            duration: TimeInterval(totalDuration),
            startDate: Date()
        )

        let category = selectedCategoryData ?? TimerCategory(id: selectedCategory, durationSeconds: currentDuration)

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
        if session.type == .focus {
            let durationMinutes = totalDuration / 60
            statsStore.questEventHandler?(.focusSessionStarted(durationMinutes: durationMinutes))
        }
        if #available(iOS 17.0, *) {
            Task {
                for activity in Activity<FocusSessionAttributes>.activities {
                    await activity.end(nil, dismissalPolicy: .immediate)
                }

                let attributes = FocusSessionAttributes(sessionId: UUID(), totalSeconds: totalDuration)
                let contentState = FocusSessionAttributes.ContentState(
                    startDate: Date(),
                    endDate: session.endDate,
                    isPaused: false,
                    remainingSeconds: totalDuration,
                    title: title
                )

                do {
                    let activity = try Activity.request(
                        attributes: attributes,
                        contentState: contentState,
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
        pausedRemainingSeconds = remaining
        remainingSeconds = remaining
        currentSession = nil
        stopUITimer()
        clearPersistedSession()
        timerState = .paused
        state = .paused
        print("[FocusTimer] Paused with \(remaining) seconds left")
        if #available(iOS 17.0, *) {
            updateLiveActivity(isPaused: true, remaining: remaining, title: selectedCategoryData?.id.title ?? selectedMode.title, startDate: Date(), endDate: Date())
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
            startDate: Date()
        )
        currentSession = session
        activeSessionCategory = selectedCategory
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
            liveActivityManager?.start(
                endDate: session.endDate,
                sessionType: category.id.rawValue,
                title: category.id.title
            )
        }
    }

    func resetTimer() {
        cancelCompletionNotifications()
        pausedRemainingSeconds = nil
        currentSession = nil
        stopUITimer()
        hasFinishedOnce = false
        activeSessionDuration = nil
        clearPersistedSession()
        timerState = .idle
        state = .idle
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
            liveActivityManager?.end()
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
        let contentState = FocusSessionAttributes.ContentState(
            startDate: startDate,
            endDate: endDate,
            isPaused: isPaused,
            remainingSeconds: remaining,
            title: title
        )

        Task {
            guard let liveActivity else { return }
            await liveActivity.update(using: contentState)
            print("[FocusLiveActivity] Updated: paused=\(isPaused) remaining=\(remaining)")
        }
    }

    @available(iOS 17.0, *)
    func restoreLiveActivityIfNeeded() {
        Task {
            // Grab the first active FocusSession Live Activity, if any
            guard let activity = Activity<FocusSessionAttributes>.activities.first else { return }

            // Use `content` instead of deprecated `contentState`
            let content = activity.content
            let contentState = content.state
            let totalDuration = activity.attributes.totalSeconds
            let now = Date()
            let isPaused = contentState.isPaused
            var remaining: Int

            if isPaused {
                // Paused session: just restore remaining seconds and paused state
                remaining = contentState.remainingSeconds
                timerState = .paused
                self.state = .paused
                currentSession = nil
            } else {
                // Running session: compute remaining based on endDate
                remaining = max(Int(ceil(contentState.endDate.timeIntervalSince(now))), 0)

                if remaining > 0 {
                    // Still in progress → recreate the session and resume UI timer
                    let session = FocusSession(
                        id: UUID(),
                        type: selectedMode,
                        duration: TimeInterval(totalDuration),
                        startDate: contentState.startDate
                    )
                    currentSession = session
                    timerState = .running
                    self.state = .running
                    startUITimer()
                } else {
                    // ⛔️ Timer already finished while the app was gone.
                    // End the Live Activity so it doesn't stick around.
                    timerState = .idle
                    self.state = .idle
                    remaining = 0

                    await activity.end(nil, dismissalPolicy: .immediate)
                    await MainActor.run {
                        self.liveActivity = nil
                    }
                    print("[FocusLiveActivity] Ended stale activity \(activity.id)")
                    return
                }
            }

            // Keep internal state in sync with whatever we restored
            activeSessionDuration = totalDuration
            pausedRemainingSeconds = isPaused ? remaining : pausedRemainingSeconds
            remainingSeconds = remaining

            await MainActor.run {
                self.liveActivity = activity
            }
            print("[FocusLiveActivity] Restored existing activity \(activity.id) paused=\(isPaused) remaining=\(remaining)")
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
                        if #available(iOS 17.0, *) {
                            let title = self.selectedCategoryData?.id.title ?? self.selectedMode.title
                            self.updateLiveActivity(
                                isPaused: false,
                                remaining: remaining,
                                title: title,
                                startDate: session.startDate,
                                endDate: session.endDate
                            )
                        }
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
        hasFinishedOnce = true
        if let sessionType = currentSession?.type {
            selectedMode = sessionType
        }
        statsStore.refreshDailyFocusTotal()
        let previousFocusTotal = statsStore.totalFocusSecondsToday
        let xpBefore = statsStore.totalXP
        let recordedDuration = Int(currentSession?.duration ?? TimeInterval(activeSessionDuration ?? currentDuration))
        _ = statsStore.recordSession(mode: selectedMode, duration: recordedDuration)
        if currentSession?.type == .focus {
            let durationMinutes = recordedDuration / 60
            statsStore.questEventHandler?(.focusSessionCompleted(durationMinutes: durationMinutes))
            if activeSessionCategory == .choresSprint {
                statsStore.questEventHandler?(.choresTimerCompleted(durationMinutes: durationMinutes))
            }
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
        sendImmediateHydrationReminder()
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
        switch phase {
        case .active:
            // App came to the foreground: restore and snap timer into sync
            restorePersistedSessionIfNeeded()
            syncRemainingSecondsNow()
            startUITimer()
            handleSessionCompletionIfNeeded()
        case .background:
            // App going to background: save state and stop UI timer
            persistCurrentSessionIfNeeded()
            scheduleCompletionNotification()
            stopUITimer()
        default:
            break
        }
    }

    func handleAppear() {
        if #available(iOS 17.0, *) {
            restoreLiveActivityIfNeeded()
        }
        // Make the in-app timer label catch up immediately
        syncRemainingSecondsNow()
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
        timerState = .running
        state = .running
        remainingSeconds = max(Int(ceil(session.endDate.timeIntervalSinceNow)), 0)
    }

    private func clearPersistedSession() {
        userDefaults.removeObject(forKey: Self.persistedSessionKey)
    }

    private func sendImmediateHydrationReminder() {
        guard notificationAuthorized, hydrateNudgesEnabled else { return }
        let content = UNMutableNotificationContent()
        content.title = QuestChatStrings.Notifications.hydrateReminderTitle
        content.body = QuestChatStrings.Notifications.hydrateReminderBody
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "focus_timer_hydrate", content: content, trigger: trigger)
        notificationCenter.add(request)
    }

    private func handleHydrationThresholds(previousTotal: Int, newTotal: Int) {
        guard hydrateNudgesEnabled, selectedMode == .focus else { return }

        for level in HydrationNudgeLevel.allCases {
            let threshold = level.thresholdSeconds
            guard previousTotal < threshold, newTotal >= threshold else { continue }
            guard !hasTriggeredNudge(for: level) else { continue }

            sendHydrationNudge(level: level)
            markNudgeTriggered(for: level)
        }
    }

    func sendHydrationNudge(level: HydrationNudgeLevel) {
        guard hydrateNudgesEnabled else { return }

        let content = UNMutableNotificationContent()
        content.title = QuestChatStrings.Notifications.hydrateNudgeTitle
        content.body = level.bodyText
        content.sound = .default

        if notificationAuthorized {
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
            let request = UNNotificationRequest(
                identifier: "hydrate_nudge_\(level.thresholdSeconds)",
                content: content,
                trigger: trigger
            )
            notificationCenter.add(request)
        }

        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            activeHydrationNudge = HydrationNudge(level: level, message: level.bodyText)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self] in
            withAnimation(.easeInOut(duration: 0.3)) {
                self?.activeHydrationNudge = nil
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
        updateWaterIntakeTotals()
    }

    private func persistSleepQualitySelection() {
        let today = Calendar.current.startOfDay(for: Date())
        userDefaults.set(sleepQuality.rawValue, forKey: HealthTrackingStorageKeys.sleepQualityValue)
        userDefaults.set(today, forKey: HealthTrackingStorageKeys.sleepQualityDate)
        userDefaults.set(today, forKey: HealthTrackingStorageKeys.sleepQualityLogged)
        hasLoggedSleepQualityToday = true
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

    private func evaluateHealthXPBonuses() {
        let today = Date()
        refreshDailyHealthBonusState(today: today)

        if didHitWaterGoalToday && !waterGoalXPGrantedToday {
            statsStore.questEventHandler?(.hydrationGoalReached)
            statsStore.grantXP(10, reason: .waterGoal)
            waterGoalXPGrantedToday = true
            userDefaults.set(Calendar.current.startOfDay(for: today), forKey: HealthTrackingStorageKeys.waterGoalAwardDate)
        }

        if healthComboIsComplete && !healthComboXPGrantedToday {
            statsStore.grantXP(10, reason: .healthCombo)
            healthComboXPGrantedToday = true
            userDefaults.set(Calendar.current.startOfDay(for: today), forKey: HealthTrackingStorageKeys.healthComboAwardDate)
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
            TimerCategory(id: .deepFocus, durationSeconds: 25 * 60),
            TimerCategory(id: .workSprint, durationSeconds: 45 * 60),
            TimerCategory(id: .choresSprint, durationSeconds: 15 * 60),
            TimerCategory(id: .selfCare, durationSeconds: 5 * 60),
            TimerCategory(id: .gamingReset, durationSeconds: 10 * 60),
            TimerCategory(id: .quickBreak, durationSeconds: 8 * 60),
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

