import Foundation
import Combine
import SwiftUI
import UserNotifications
import UIKit

/// Represents available timer modes.
enum FocusTimerMode: String, CaseIterable, Identifiable {
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
                return "broom"
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
        var level: Int                // 1...100
        var xpInCurrentLevel: Int     // XP stored into the current level
        var totalXP: Int              // lifetime XP, for stats only
        var streakDays: Int
        var lastActiveDate: Date?
    }

    enum XpSource: Codable {
        case focusSession(minutes: Int)
        case questCompleted(id: String, xp: Int)
        case streakBonus
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
    @Published private(set) var xp: Int
    @Published private(set) var momentum: Double
    @Published private(set) var sessionHistory: [SessionRecord]
    @Published private(set) var totalFocusSecondsToday: Int
    @Published private(set) var todayCategorySessionCounts: [TimerCategory.Kind: Int]
    @Published private(set) var categoryComboBonusAwardedToday: Set<TimerCategory.Kind>
    @Published var pendingLevelUp: Int?
    @Published private(set) var dailyConfig: DailyConfig?
    @Published var shouldShowDailySetup: Bool = false
    @Published private(set) var lastWeeklyGoalBonusAwardedDate: Date?
    @Published private(set) var progression: ProgressionState
    @Published var lastLevelUp: LevelUpResult?

    private(set) var lastKnownLevel: Int

    var level: Int { progression.level }

    var xpIntoCurrentLevel: Int { progression.xpInCurrentLevel }

    var xpForNextLevel: Int {
        let needed = xpNeededToLevelUp(from: progression.level)
        return needed == Int.max ? 0 : needed
    }

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

        return QuestChatStrings.StatusLines.xpEarned(xp)
    }

    var dailyMinutesGoal: Int? { dailyConfig?.dailyMinutesGoal }

    var dailyMinutesProgress: Int {
        totalFocusSecondsToday / 60
    }

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        focusSeconds = userDefaults.integer(forKey: Keys.focusSeconds)
        selfCareSeconds = userDefaults.integer(forKey: Keys.selfCareSeconds)
        sessionsCompleted = userDefaults.integer(forKey: Keys.sessionsCompleted)

        let storedXP = userDefaults.integer(forKey: Keys.xp)

        if
            let data = userDefaults.data(forKey: Keys.sessionHistory),
            let decoded = try? JSONDecoder().decode([SessionRecord].self, from: data)
        {
            sessionHistory = decoded
        } else {
            sessionHistory = []
        }

        if let data = userDefaults.data(forKey: Keys.categorySessionCounts),
           let decoded = try? JSONDecoder().decode([String: Int].self, from: data)
        {
            todayCategorySessionCounts = decoded.reduce(into: [:]) { partialResult, pair in
                if let id = TimerCategory.Kind(rawValue: pair.key) {
                    partialResult[id] = pair.value
                }
            }
        } else {
            todayCategorySessionCounts = [:]
        }

        if let data = userDefaults.data(forKey: Keys.categoryComboBonusesAwarded),
           let decoded = try? JSONDecoder().decode([String].self, from: data)
        {
            categoryComboBonusAwardedToday = Set(decoded.compactMap { TimerCategory.Kind(rawValue: $0) })
        } else {
            categoryComboBonusAwardedToday = []
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
                totalXP: storedXP,
                streakDays: 0,
                lastActiveDate: nil
            )
        }
        progression = initialProgression
        xp = initialProgression.totalXP

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
        let initialLevel = initialProgression.level
        lastKnownLevel = storedLevel > 0 ? storedLevel : initialLevel
        pendingLevelUp = nil

        let storedConfig = Self.decodeConfig(from: userDefaults.data(forKey: Keys.dailyConfig))
        dailyConfig = storedConfig
        shouldShowDailySetup = !Self.isConfigValidForToday(storedConfig)

        lastWeeklyGoalBonusAwardedDate = userDefaults.object(forKey: Keys.lastWeeklyGoalBonusAwardedDate) as? Date

        refreshDailyCategoryCountsIfNeeded(today: today)

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
    }

    @discardableResult
    func recordSession(mode: FocusTimerMode, duration: Int) -> Int {
        refreshDailyTotalsIfNeeded()
        refreshMomentumIfNeeded()

        let now = Date()
        let minutes = max(0, duration / 60)
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

        let baseXP = minutes * 2
        let _ = registerCompletedSession(minutes: minutes)

        if momentum >= 1.0 {
            let bonusXP = Int((Double(baseXP) * momentumBonusMultiplier).rounded())
            if bonusXP > 0 {
                grantBonusXP(bonusXP)
            }
            momentum = 0
        }

        momentum = min(1.0, momentum + momentumIncrement)
        lastSessionDate = now
        lastMomentumUpdate = now
        persist()
        evaluateWeeklyGoalBonus()
        return progression.totalXP - xpBefore
    }

    @discardableResult
    func recordCategorySession(categoryID: TimerCategory.Kind, now: Date = Date()) -> Int {
        refreshDailyCategoryCountsIfNeeded(today: Calendar.current.startOfDay(for: now))

        let today = Calendar.current.startOfDay(for: now)
        let newCount = (todayCategorySessionCounts[categoryID] ?? 0) + 1
        todayCategorySessionCounts[categoryID] = newCount
        persistCategorySessionCounts(for: today)

        if newCount >= 3, !categoryComboBonusAwardedToday.contains(categoryID) {
            categoryComboBonusAwardedToday.insert(categoryID)
            grantBonusXP(20)
            persistCategoryComboBonuses(for: today)
        }

        return newCount
    }

    func comboCount(for categoryID: TimerCategory.Kind) -> Int {
        refreshDailyCategoryCountsIfNeeded()
        return todayCategorySessionCounts[categoryID] ?? 0
    }

    func hasEarnedComboBonus(for categoryID: TimerCategory.Kind) -> Bool {
        refreshDailyCategoryCountsIfNeeded()
        return categoryComboBonusAwardedToday.contains(categoryID)
    }

    func refreshDailyFocusTotal() {
        refreshDailyTotalsIfNeeded()
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
    func grantXP(_ amount: Int, source: XpSource) -> LevelUpResult? {
        guard amount > 0 else { return nil }

        progression.totalXP += amount
        xp = progression.totalXP

        guard progression.level < 100 else {
            saveProgression()
            return nil
        }

        progression.xpInCurrentLevel += amount
        var oldLevel = progression.level

        while progression.level < 100 && progression.xpInCurrentLevel >= xpNeededToLevelUp(from: progression.level) {
            progression.xpInCurrentLevel -= xpNeededToLevelUp(from: progression.level)
            progression.level += 1
        }

        let levelChanged = progression.level != oldLevel
        if levelChanged {
            let result = LevelUpResult(oldLevel: oldLevel, newLevel: progression.level)
            lastLevelUp = result
            pendingLevelUp = result.newLevel
            oldLevel = progression.level
        }

        lastKnownLevel = progression.level
        saveProgression()
        persist()
        return lastLevelUp
    }

    @discardableResult
    func registerCompletedSession(minutes: Int) -> LevelUpResult? {
        guard minutes > 0 else { return nil }
        return grantXP(minutes * 2, source: .focusSession(minutes: minutes))
    }

    @discardableResult
    func registerQuestCompleted(id: String, xp: Int) -> LevelUpResult? {
        guard xp > 0 else { return nil }
        return grantXP(xp, source: .questCompleted(id: id, xp: xp))
    }

    @discardableResult
    func registerStreakBonus() -> LevelUpResult? {
        grantXP(10, source: .streakBonus)
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

    func grantBonusXP(_ amount: Int) {
        _ = grantXP(amount, source: .questCompleted(id: "bonus", xp: amount))
    }

    func resetAll() {
        focusSeconds = 0
        selfCareSeconds = 0
        sessionsCompleted = 0
        progression = ProgressionState(level: 1, xpInCurrentLevel: 0, totalXP: 0, streakDays: 0, lastActiveDate: nil)
        xp = progression.totalXP
        totalFocusSecondsToday = 0
        userDefaults.set(Calendar.current.startOfDay(for: Date()), forKey: Keys.totalFocusDate)
        lastKnownLevel = progression.level
        pendingLevelUp = nil
        sessionHistory = []
        todayCategorySessionCounts = [:]
        categoryComboBonusAwardedToday = []
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
        guard level < 100 else { return Int.max }
        return 40 + 4 * max(0, level - 1)
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
        static let categorySessionCounts = "categorySessionCounts"
        static let categorySessionCountsDate = "categorySessionCountsDate"
        static let categoryComboBonusesAwarded = "categoryComboBonusesAwarded"
    }

    private var todaySessions: [SessionRecord] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return sessionHistory.filter { session in
            calendar.isDate(session.date, inSameDayAs: today)
        }
    }

    private func persist() {
        refreshDailyCategoryCountsIfNeeded()
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
        persistCategorySessionCounts()
        persistCategoryComboBonuses()
    }

    private func persistSessionHistory() {
        if let data = try? JSONEncoder().encode(sessionHistory) {
            userDefaults.set(data, forKey: Keys.sessionHistory)
        }
    }

    private func persistCategorySessionCounts(for date: Date = Calendar.current.startOfDay(for: Date())) {
        let encoded = todayCategorySessionCounts.reduce(into: [String: Int]()) { partialResult, pair in
            partialResult[pair.key.rawValue] = pair.value
        }
        if let data = try? JSONEncoder().encode(encoded) {
            userDefaults.set(data, forKey: Keys.categorySessionCounts)
        }
        userDefaults.set(date, forKey: Keys.categorySessionCountsDate)
    }

    private func persistCategoryComboBonuses(for date: Date = Calendar.current.startOfDay(for: Date())) {
        let encoded = categoryComboBonusAwardedToday.map { $0.rawValue }
        if let data = try? JSONEncoder().encode(encoded) {
            userDefaults.set(data, forKey: Keys.categoryComboBonusesAwarded)
        }
        userDefaults.set(date, forKey: Keys.categorySessionCountsDate)
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
        refreshDailyCategoryCountsIfNeeded(today: today)
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

    private func refreshDailyCategoryCountsIfNeeded(today: Date = Calendar.current.startOfDay(for: Date())) {
        let storedDate = userDefaults.object(forKey: Keys.categorySessionCountsDate) as? Date
        guard !Calendar.current.isDate(storedDate ?? .distantPast, inSameDayAs: today) else { return }

        todayCategorySessionCounts = [:]
        categoryComboBonusAwardedToday = []
        persistCategorySessionCounts(for: today)
        persistCategoryComboBonuses(for: today)
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
        grantBonusXP(120)
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

    @Published var secondsRemaining: Int
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

    enum TimerState {
        case idle
        case running
        case paused
        case finished
    }

    @Published var state: TimerState = .idle

    @Published private(set) var notificationAuthorized: Bool = false
    let statsStore: SessionStatsStore
    private var cancellables = Set<AnyCancellable>()

    private var timer: Timer?
    @AppStorage("hydrateNudgesEnabled") private var hydrateNudgesEnabled: Bool = true
    private let notificationCenter = UNUserNotificationCenter.current()
    private let userDefaults = UserDefaults.standard
    private var hasInitialized = false

    init(
        statsStore: SessionStatsStore = SessionStatsStore(),
        initialMode: FocusTimerMode = .focus
    ) {
        // Assign non-dependent stored properties first
        self.statsStore = statsStore

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
        self.secondsRemaining = initialCategory.durationSeconds

        hasInitialized = true

        // Defer side-effectful calls until after full initialization
        requestNotificationAuthorization()

        statsStore.$lastLevelUp
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.lastLevelUp = $0 }
            .store(in: &cancellables)
    }

    var currentLevel: Int { statsStore.progression.level }
    var xpInCurrentLevel: Int { statsStore.progression.xpInCurrentLevel }
    var xpNeededForNextLevel: Int { statsStore.xpNeededToLevelUp(from: statsStore.progression.level) }
    var levelProgressFraction: Double {
        let needed = max(1, xpNeededForNextLevel == Int.max ? 1 : xpNeededForNextLevel)
        return Double(xpInCurrentLevel) / Double(needed)
    }

    var selectedCategoryData: TimerCategory? {
        categories.first { $0.id == selectedCategory }
    }

    var comboCountForSelectedCategory: Int {
        statsStore.comboCount(for: selectedCategory)
    }

    var hasEarnedComboForSelectedCategory: Bool {
        statsStore.hasEarnedComboBonus(for: selectedCategory)
    }

    private var currentDuration: Int {
        durationForSelectedCategory()
    }

    var progress: Double {
        let total = Double(currentDuration)
        guard total > 0 else { return 0 }
        let value = 1 - (Double(secondsRemaining) / total)
        return min(max(value, 0), 1)
    }

    var isRunning: Bool { state == .running }

    var hydrationNudgesEnabled: Bool { hydrateNudgesEnabled }

    /// Starts the timer if currently idle or paused.
    func start() {
        guard state == .idle || state == .paused else { return }

        if secondsRemaining == 0 {
            secondsRemaining = currentDuration
            hasFinishedOnce = false
        }

        invalidateTimer()
        state = .running
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        scheduleCompletionNotification()

        timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            if self.secondsRemaining > 0 {
                self.secondsRemaining -= 1
            } else {
                self.finishSession()
            }
        }

        if let timer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    /// Pauses the timer if currently running.
    func pause() {
        guard state == .running else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        cancelCompletionNotifications()
        invalidateTimer()
        state = .paused
    }

    /// Resets the timer to the selected category duration.
    func reset() {
        cancelCompletionNotifications()
        invalidateTimer()
        secondsRemaining = currentDuration
        hasFinishedOnce = false
        state = .idle
    }

    func selectCategory(_ category: TimerCategory) {
        guard category.id != selectedCategory else { return }
        guard state == .idle || state == .finished else { return }

        selectedCategory = category.id
        selectedMode = category.id.mode
        secondsRemaining = category.durationSeconds
        hasFinishedOnce = false
        state = .idle
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
            secondsRemaining = clamped
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

    private func invalidateTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func finishSession() {
        cancelCompletionNotifications()
        invalidateTimer()
        state = .finished
        hasFinishedOnce = true
        statsStore.refreshDailyFocusTotal()
        let previousFocusTotal = statsStore.totalFocusSecondsToday
        let xpBefore = statsStore.progression.totalXP
        _ = statsStore.recordSession(mode: selectedMode, duration: currentDuration)
        _ = statsStore.recordCategorySession(categoryID: selectedCategory)
        let streakLevelUp = statsStore.registerActiveToday()
        let totalXPGained = statsStore.progression.totalXP - xpBefore
        if streakLevelUp != nil {
            lastLevelUp = streakLevelUp
        } else {
            lastLevelUp = statsStore.lastLevelUp
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        withAnimation(.easeInOut(duration: 0.25)) {
            lastCompletedSession = SessionSummary(
                mode: selectedMode,
                duration: currentDuration,
                xpGained: totalXPGained,
                timestamp: Date()
            )
        }
        secondsRemaining = 0
        handleHydrationThresholds(previousTotal: previousFocusTotal, newTotal: statsStore.totalFocusSecondsToday)
        sendImmediateHydrationReminder()
    }

    private func resetForModeChange() {
        cancelCompletionNotifications()
        invalidateTimer()
        secondsRemaining = currentDuration
        hasFinishedOnce = false
        state = .idle
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

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(secondsRemaining), repeats: false)
        let request = UNNotificationRequest(identifier: "focus_timer_completion", content: content, trigger: trigger)
        notificationCenter.add(request)
    }

    private func cancelCompletionNotifications() {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: ["focus_timer_completion"])
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
