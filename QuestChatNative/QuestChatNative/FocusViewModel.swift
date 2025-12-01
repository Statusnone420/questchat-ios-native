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
        case .focus: "Deep Focus"
        case .selfCare: "Self Care"
        }
    }

    /// Default duration in seconds for the timer mode.
    var duration: Int {
        let userDefaults = UserDefaults.standard
        switch self {
        case .focus:
            let storedMinutes = userDefaults.integer(forKey: Keys.focusDurationMinutes)
            let minutes = storedMinutes > 0 ? storedMinutes : Keys.defaultFocusDurationMinutes
            return minutes * 60
        case .selfCare:
            let storedMinutes = userDefaults.integer(forKey: Keys.selfCareDurationMinutes)
            let minutes = storedMinutes > 0 ? storedMinutes : Keys.defaultSelfCareDurationMinutes
            return minutes * 60
        }
    }

    var accentSystemImage: String {
        switch self {
        case .focus: "flame.fill"
        case .selfCare: "heart.fill"
        }
    }

    private enum Keys {
        static let focusDurationMinutes = "focusDurationMinutes"
        static let selfCareDurationMinutes = "selfCareDurationMinutes"
        static let defaultFocusDurationMinutes = 25
        static let defaultSelfCareDurationMinutes = 5
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

    @Published private(set) var focusSeconds: Int
    @Published private(set) var selfCareSeconds: Int
    @Published private(set) var sessionsCompleted: Int
    @Published private(set) var xp: Int
    @Published private(set) var sessionHistory: [SessionRecord]
    @Published private(set) var totalFocusSecondsToday: Int
    @Published var pendingLevelUp: Int?

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
    }

    @discardableResult
    func recordSession(mode: FocusTimerMode, duration: Int) -> Int {
        refreshDailyTotalsIfNeeded()

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
        persist()
        return xpAwarded
    }

    func refreshDailyFocusTotal() {
        refreshDailyTotalsIfNeeded()
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
        persist()
    }

    private let userDefaults: UserDefaults

    private enum Keys {
        static let focusSeconds = "focusSeconds"
        static let selfCareSeconds = "selfCareSeconds"
        static let sessionsCompleted = "sessionsCompleted"
        static let xp = "xp"
        static let sessionHistory = "sessionHistory"
        static let lastKnownLevel = "lastKnownLevel"
        static let totalFocusSecondsToday = "totalFocusSecondsToday"
        static let totalFocusDate = "totalFocusDate"
    }

    private var todaySessions: [SessionRecord] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return sessionHistory.filter { session in
            calendar.isDate(session.date, inSameDayAs: today)
        }
    }

    private func persist() {
        userDefaults.set(focusSeconds, forKey: Keys.focusSeconds)
        userDefaults.set(selfCareSeconds, forKey: Keys.selfCareSeconds)
        userDefaults.set(sessionsCompleted, forKey: Keys.sessionsCompleted)
        userDefaults.set(xp, forKey: Keys.xp)
        userDefaults.set(lastKnownLevel, forKey: Keys.lastKnownLevel)
        userDefaults.set(totalFocusSecondsToday, forKey: Keys.totalFocusSecondsToday)
        userDefaults.set(Calendar.current.startOfDay(for: Date()), forKey: Keys.totalFocusDate)
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
                return "Nice streak! Grab water and reset your posture."
            case .sixtyMinutes:
                return "Hydrate and stretch—your focus streak is over an hour!"
            case .ninetyMinutes:
                return "Amazing focus. Take a hydration + posture break before continuing."
            }
        }
    }

    @Published var isRunning: Bool = false
    @Published var secondsRemaining: Int
    @Published var hasFinishedOnce: Bool = false
    @Published var selectedMode: FocusTimerMode = .focus {
        didSet { resetForModeChange(cancelFocusBlock: !isAutomatedModeSwitch) }
    }
    @Published var lastCompletedSession: SessionSummary?
    @Published var activeHydrationNudge: HydrationNudge?
    @Published var isFocusBlockEnabled: Bool = false {
        didSet {
            if !isFocusBlockEnabled {
                deactivateFocusBlock()
            }
        }
    }
    @Published private(set) var isFocusBlockActive: Bool = false
    @Published private(set) var currentCycleIndex: Int = 0

    @Published private(set) var notificationAuthorized: Bool = false
    let statsStore: SessionStatsStore

    private var timerCancellable: AnyCancellable?
    @AppStorage("hydrateNudgesEnabled") private var hydrateNudgesEnabled: Bool = true
    private let notificationCenter = UNUserNotificationCenter.current()
    private let userDefaults = UserDefaults.standard
    private var isAutomatedModeSwitch = false

    let focusBlockTotalCycles: Int = 3

    init(
        statsStore: SessionStatsStore = SessionStatsStore(),
        initialMode: FocusTimerMode = .focus
    ) {
        self.statsStore = statsStore
        selectedMode = initialMode
        secondsRemaining = initialMode.duration
        requestNotificationAuthorization()
    }

    var progress: Double {
        let total = Double(selectedMode.duration)
        guard total > 0 else { return 0 }
        let value = 1 - (Double(secondsRemaining) / total)
        return min(max(value, 0), 1)
    }

    var hydrationNudgesEnabled: Bool { hydrateNudgesEnabled }

    /// Starts or pauses the timer depending on the current state.
    func startOrPause() {
        if isRunning {
            stopTimer(triggerHaptic: true)
        } else {
            if secondsRemaining == 0 {
                secondsRemaining = selectedMode.duration
                hasFinishedOnce = false
            }
            if isFocusBlockEnabled {
                beginFocusBlockIfNeeded()
            }
            startTimer()
        }
    }

    /// Resets the timer back to the full duration and clears completion state.
    func reset() {
        stopTimer()
        secondsRemaining = selectedMode.duration
        hasFinishedOnce = false
        deactivateFocusBlock()
    }

    private func startTimer() {
        isRunning = true
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        scheduleCompletionNotification()
        timerCancellable = Timer
            .publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                if self.secondsRemaining > 0 {
                    self.secondsRemaining -= 1
                } else {
                    self.finishSession()
                }
            }
    }

    private func stopTimer(triggerHaptic: Bool = false) {
        if triggerHaptic {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
        isRunning = false
        cancelCompletionNotifications()
        timerCancellable?.cancel()
        timerCancellable = nil
    }

    private func finishSession() {
        stopTimer()
        hasFinishedOnce = true
        statsStore.refreshDailyFocusTotal()
        let previousFocusTotal = statsStore.totalFocusSecondsToday
        let xpGained = statsStore.recordSession(mode: selectedMode, duration: selectedMode.duration)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        withAnimation(.easeInOut(duration: 0.25)) {
            lastCompletedSession = SessionSummary(
                mode: selectedMode,
                duration: selectedMode.duration,
                xpGained: xpGained,
                timestamp: Date()
            )
        }
        secondsRemaining = 0
        handleHydrationThresholds(previousTotal: previousFocusTotal, newTotal: statsStore.totalFocusSecondsToday)
        sendImmediateHydrationReminder()
        handleFocusBlockProgression()
    }

    private func resetForModeChange(cancelFocusBlock: Bool) {
        stopTimer()
        secondsRemaining = selectedMode.duration
        hasFinishedOnce = false
        if cancelFocusBlock {
            deactivateFocusBlock()
        }
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
        content.title = "Timer complete"
        content.body = "Hydrate and check your posture. Your session just wrapped up!"
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
        content.title = "Great work!"
        content.body = "Reward unlocked: stretch, hydrate, and maintain good posture."
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
        content.title = "Hydrate + posture check"
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

    // MARK: - Focus block automation

    private func beginFocusBlockIfNeeded() {
        guard !isFocusBlockActive else { return }
        isFocusBlockActive = true
        currentCycleIndex = 0
        setMode(.focus, automated: true)
        secondsRemaining = selectedMode.duration
        hasFinishedOnce = false
    }

    private func handleFocusBlockProgression() {
        guard isFocusBlockActive else { return }

        switch selectedMode {
        case .focus:
            transitionToSelfCare()
        case .selfCare:
            currentCycleIndex += 1
            if currentCycleIndex < focusBlockTotalCycles {
                startNextFocusCycle()
            } else {
                completeFocusBlock()
            }
        }
    }

    private func transitionToSelfCare() {
        setMode(.selfCare, automated: true)
        secondsRemaining = selectedMode.duration
        hasFinishedOnce = false
        startTimer()
    }

    private func startNextFocusCycle() {
        setMode(.focus, automated: true)
        secondsRemaining = selectedMode.duration
        hasFinishedOnce = false
        startTimer()
    }

    private func completeFocusBlock() {
        deactivateFocusBlock()
    }

    private func deactivateFocusBlock() {
        isFocusBlockActive = false
        currentCycleIndex = 0
    }

    private func setMode(_ mode: FocusTimerMode, automated: Bool) {
        isAutomatedModeSwitch = automated
        selectedMode = mode
        isAutomatedModeSwitch = false
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
