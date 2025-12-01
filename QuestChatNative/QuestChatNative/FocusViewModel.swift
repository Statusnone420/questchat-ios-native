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
    let id: UUID
    let name: String
    let emoji: String
    let description: String
    let defaultDurationMinutes: Int
    var durationMinutes: Int
    let mode: FocusTimerMode

    init(
        id: UUID = UUID(),
        name: String,
        emoji: String,
        description: String,
        defaultDurationMinutes: Int,
        mode: FocusTimerMode,
        durationMinutes: Int? = nil
    ) {
        self.id = id
        self.name = name
        self.emoji = emoji
        self.description = description
        self.defaultDurationMinutes = defaultDurationMinutes
        self.durationMinutes = durationMinutes ?? defaultDurationMinutes
        self.mode = mode
    }
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
    @Published private(set) var todayCategorySessionCounts: [UUID: Int]
    @Published private(set) var categoryComboBonusAwardedToday: Set<UUID>
    @Published var pendingLevelUp: Int?
    @Published private(set) var dailyConfig: DailyConfig?
    @Published var shouldShowDailySetup: Bool = false
    @Published private(set) var lastWeeklyGoalBonusAwardedDate: Date?

    private(set) var lastKnownLevel: Int

    var level: Int {
        (xp / 100) + 1
    }

    var xpIntoCurrentLevel: Int {
        xp % 100
    }

    var xpForNextLevel: Int {
        100
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
        xp = storedXP

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
                if let id = UUID(uuidString: pair.key) {
                    partialResult[id] = pair.value
                }
            }
        } else {
            todayCategorySessionCounts = [:]
        }

        if let data = userDefaults.data(forKey: Keys.categoryComboBonusesAwarded),
           let decoded = try? JSONDecoder().decode([String].self, from: data)
        {
            categoryComboBonusAwardedToday = Set(decoded.compactMap { UUID(uuidString: $0) })
        } else {
            categoryComboBonusAwardedToday = []
        }

        let storedMomentum = userDefaults.double(forKey: Keys.momentum)
        let clampedMomentum = max(0, min(storedMomentum, 1))
        momentum = clampedMomentum

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
        let initialLevel = (storedXP / 100) + 1
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

        let xpAwarded: Int
        switch mode {
        case .focus:
            focusSeconds += duration
            totalFocusSecondsToday += duration
            xpAwarded = 15
        case .selfCare:
            selfCareSeconds += duration
            xpAwarded = 8
        }

        xp += xpAwarded
        sessionsCompleted += 1
        recordSessionHistory(mode: mode, duration: duration)
        handleLevelChange()

        var totalXPAwarded = xpAwarded

        if momentum >= 1.0 {
            let bonusXP = Int((Double(xpAwarded) * momentumBonusMultiplier).rounded())
            if bonusXP > 0 {
                grantBonusXP(bonusXP)
                totalXPAwarded += bonusXP
            }
            momentum = 0
        }

        momentum = min(1.0, momentum + momentumIncrement)
        lastSessionDate = now
        lastMomentumUpdate = now
        persist()
        evaluateWeeklyGoalBonus()
        return totalXPAwarded
    }

    @discardableResult
    func recordCategorySession(categoryID: UUID, now: Date = Date()) -> Int {
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

    func comboCount(for categoryID: UUID) -> Int {
        refreshDailyCategoryCountsIfNeeded()
        return todayCategorySessionCounts[categoryID] ?? 0
    }

    func hasEarnedComboBonus(for categoryID: UUID) -> Bool {
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

    func grantBonusXP(_ amount: Int) {
        guard amount > 0 else { return }
        xp += amount
        handleLevelChange()
        persist()
    }

    func resetAll() {
        focusSeconds = 0
        selfCareSeconds = 0
        sessionsCompleted = 0
        xp = 0
        totalFocusSecondsToday = 0
        userDefaults.set(Calendar.current.startOfDay(for: Date()), forKey: Keys.totalFocusDate)
        lastKnownLevel = level
        pendingLevelUp = nil
        sessionHistory = []
        todayCategorySessionCounts = [:]
        categoryComboBonusAwardedToday = []
        momentum = 0
        lastSessionDate = nil
        lastMomentumUpdate = nil
        lastWeeklyGoalBonusAwardedDate = nil
        persist()
    }

    var currentMomentum: Double {
        // Return a computed value without mutating @Published properties to avoid publishing during view updates
        return computeDecayedMomentum(now: Date())
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
        userDefaults.set(focusSeconds, forKey: Keys.focusSeconds)
        userDefaults.set(selfCareSeconds, forKey: Keys.selfCareSeconds)
        userDefaults.set(sessionsCompleted, forKey: Keys.sessionsCompleted)
        userDefaults.set(xp, forKey: Keys.xp)
        userDefaults.set(lastKnownLevel, forKey: Keys.lastKnownLevel)
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
            partialResult[pair.key.uuidString] = pair.value
        }
        if let data = try? JSONEncoder().encode(encoded) {
            userDefaults.set(data, forKey: Keys.categorySessionCounts)
        }
        userDefaults.set(date, forKey: Keys.categorySessionCountsDate)
    }

    private func persistCategoryComboBonuses(for date: Date = Calendar.current.startOfDay(for: Date())) {
        let encoded = categoryComboBonusAwardedToday.map { $0.uuidString }
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

    var currentStreakDays: Int {
        let calendar = Calendar.current
        let uniqueDays = Set(sessionHistory.map { calendar.startOfDay(for: $0.date) })

        guard !uniqueDays.isEmpty else { return 0 }

        let sortedDays = uniqueDays.sorted(by: >)
        var streak = 1
        var previousDay = sortedDays[0]

        for day in sortedDays.dropFirst() {
            if let dayDifference = calendar.dateComponents([.day], from: day, to: previousDay).day, dayDifference == 1 {
                streak += 1
                previousDay = day
            } else {
                break
            }
        }

        return streak
    }

    private func handleLevelChange() {
        let newLevel = level
        guard newLevel != lastKnownLevel else { return }

        if newLevel > lastKnownLevel {
            withAnimation {
                pendingLevelUp = newLevel
            }
        }

        lastKnownLevel = newLevel
    }

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
        didSet { resetForModeChange() }
    }
    @Published var categories: [TimerCategory]
    @Published var selectedCategoryID: TimerCategory.ID
    @Published var lastCompletedSession: SessionSummary?
    @Published var activeHydrationNudge: HydrationNudge?

    enum TimerState {
        case idle
        case running
        case paused
        case finished
    }

    @Published var state: TimerState = .idle

    @Published private(set) var notificationAuthorized: Bool = false
    let statsStore: SessionStatsStore

    private var timer: Timer?
    @AppStorage("hydrateNudgesEnabled") private var hydrateNudgesEnabled: Bool = true
    private let notificationCenter = UNUserNotificationCenter.current()
    private let userDefaults = UserDefaults.standard

    init(
        statsStore: SessionStatsStore = SessionStatsStore(),
        initialMode: FocusTimerMode = .focus
    ) {
        // Assign non-dependent stored properties first
        self.statsStore = statsStore

        // Build categories using local variables to avoid referencing self before init completes
        let seeded = FocusViewModel.seededCategories()
        let loadedCategories: [TimerCategory] = seeded.map { base in
            var category = base
            // Use a temporary UserDefaults instance directly instead of self.userDefaults
            let key = "timerCategory_duration_\(category.id.uuidString)"
            let storedMinutes = UserDefaults.standard.integer(forKey: key)
            category.durationMinutes = storedMinutes > 0 ? storedMinutes : category.defaultDurationMinutes
            return category
        }
        self.categories = loadedCategories

        // Pick initial category using local data
        let initialCategory = loadedCategories.first { $0.mode == initialMode } ?? loadedCategories[0]
        self.selectedCategoryID = initialCategory.id
        self.selectedMode = initialCategory.mode
        self.secondsRemaining = initialCategory.durationMinutes * 60

        // Defer side-effectful calls until after full initialization
        requestNotificationAuthorization()
    }

    var selectedCategory: TimerCategory? {
        categories.first { $0.id == selectedCategoryID }
    }

    var comboCountForSelectedCategory: Int {
        statsStore.comboCount(for: selectedCategoryID)
    }

    var hasEarnedComboForSelectedCategory: Bool {
        statsStore.hasEarnedComboBonus(for: selectedCategoryID)
    }

    private var currentDuration: Int {
        selectedCategory.map { $0.durationMinutes * 60 } ?? selectedMode.defaultDurationMinutes * 60
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
        guard category.id != selectedCategoryID else { return }
        guard state == .idle || state == .finished else { return }

        selectedCategoryID = category.id
        selectedMode = category.mode
        secondsRemaining = category.durationMinutes * 60
        hasFinishedOnce = false
        state = .idle
    }

    func updateDuration(for category: TimerCategory, to minutes: Int) {
        guard !(state == .running && category.id == selectedCategoryID) else { return }

        let clamped = min(max(minutes, 5), 120)
        guard let index = categories.firstIndex(where: { $0.id == category.id }) else { return }

        categories[index].durationMinutes = clamped
        saveDuration(clamped, for: category)

        if category.id == selectedCategoryID && state == .idle {
            secondsRemaining = clamped * 60
        }
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
        let xpBefore = statsStore.xp
        _ = statsStore.recordSession(mode: selectedMode, duration: currentDuration)
        _ = statsStore.recordCategorySession(categoryID: selectedCategoryID)
        let totalXPGained = statsStore.xp - xpBefore
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

    private func durationKey(for category: TimerCategory) -> String {
        "timerCategory_duration_\(category.id.uuidString)"
    }

    private func loadDuration(for category: TimerCategory) -> Int {
        let storedMinutes = userDefaults.integer(forKey: durationKey(for: category))
        return storedMinutes > 0 ? storedMinutes : category.defaultDurationMinutes
    }

    private func saveDuration(_ minutes: Int, for category: TimerCategory) {
        userDefaults.set(minutes, forKey: durationKey(for: category))
    }
}

extension FocusViewModel {
    static func seededCategories() -> [TimerCategory] {
        [
            TimerCategory(
                name: QuestChatStrings.TimerCategories.deepFocusTitle,
                emoji: "💡",
                description: QuestChatStrings.TimerCategories.deepFocusSubtitle,
                defaultDurationMinutes: 25,
                mode: .focus
            ),
            TimerCategory(
                name: QuestChatStrings.TimerCategories.workSprintTitle,
                emoji: "🧠",
                description: QuestChatStrings.TimerCategories.workSprintSubtitle,
                defaultDurationMinutes: 45,
                mode: .focus
            ),
            TimerCategory(
                name: QuestChatStrings.TimerCategories.choresTitle,
                emoji: "🧹",
                description: QuestChatStrings.TimerCategories.choresSubtitle,
                defaultDurationMinutes: 15,
                mode: .focus
            ),
            TimerCategory(
                name: QuestChatStrings.TimerCategories.selfCareTitle,
                emoji: "💆‍♀️",
                description: QuestChatStrings.TimerCategories.selfCareSubtitle,
                defaultDurationMinutes: 5,
                mode: .selfCare
            ),
            TimerCategory(
                name: QuestChatStrings.TimerCategories.gamingResetTitle,
                emoji: "🎮",
                description: QuestChatStrings.TimerCategories.gamingResetSubtitle,
                defaultDurationMinutes: 10,
                mode: .selfCare
            ),
            TimerCategory(
                name: QuestChatStrings.TimerCategories.quickBreakTitle,
                emoji: "☕️",
                description: QuestChatStrings.TimerCategories.quickBreakSubtitle,
                defaultDurationMinutes: 8,
                mode: .selfCare
            ),
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

