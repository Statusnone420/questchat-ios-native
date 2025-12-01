import Foundation
import Combine
import SwiftUI
import UserNotifications

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

        let storedLevel = userDefaults.integer(forKey: Keys.lastKnownLevel)
        let initialLevel = (storedXP / 100) + 1
        lastKnownLevel = storedLevel > 0 ? storedLevel : initialLevel
        pendingLevelUp = nil
    }

    func recordSession(mode: FocusTimerMode, duration: Int) {
        switch mode {
        case .focus:
            focusSeconds += duration
            xp += 15
        case .selfCare:
            selfCareSeconds += duration
            xp += 8
        }
        sessionsCompleted += 1
        recordSessionHistory(mode: mode, duration: duration)
        handleLevelChange()
        persist()
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
    }

    private func persist() {
        userDefaults.set(focusSeconds, forKey: Keys.focusSeconds)
        userDefaults.set(selfCareSeconds, forKey: Keys.selfCareSeconds)
        userDefaults.set(sessionsCompleted, forKey: Keys.sessionsCompleted)
        userDefaults.set(xp, forKey: Keys.xp)
        userDefaults.set(lastKnownLevel, forKey: Keys.lastKnownLevel)
        persistSessionHistory()
    }

    private func persistSessionHistory() {
        if let data = try? JSONEncoder().encode(sessionHistory) {
            userDefaults.set(data, forKey: Keys.sessionHistory)
        }
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
    @Published var isRunning: Bool = false
    @Published var secondsRemaining: Int
    @Published var hasFinishedOnce: Bool = false
    @Published var selectedMode: FocusTimerMode = .focus {
        didSet { resetForModeChange() }
    }

    @Published private(set) var notificationAuthorized: Bool = false
    let statsStore: SessionStatsStore

    private var timerCancellable: AnyCancellable?
    private let notificationCenter = UNUserNotificationCenter.current()

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
        return 1 - (Double(secondsRemaining) / total)
    }

    /// Starts or pauses the timer depending on the current state.
    func startOrPause() {
        if isRunning {
            stopTimer()
        } else {
            if secondsRemaining == 0 {
                secondsRemaining = selectedMode.duration
                hasFinishedOnce = false
            }
            startTimer()
        }
    }

    /// Resets the timer back to the full duration and clears completion state.
    func reset() {
        stopTimer()
        secondsRemaining = selectedMode.duration
        hasFinishedOnce = false
    }

    private func startTimer() {
        isRunning = true
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

    private func stopTimer() {
        isRunning = false
        cancelCompletionNotifications()
        timerCancellable?.cancel()
        timerCancellable = nil
    }

    private func finishSession() {
        stopTimer()
        hasFinishedOnce = true
        statsStore.recordSession(mode: selectedMode, duration: selectedMode.duration)
        secondsRemaining = 0
        sendImmediateHydrationReminder()
    }

    private func resetForModeChange() {
        stopTimer()
        secondsRemaining = selectedMode.duration
        hasFinishedOnce = false
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
        guard notificationAuthorized else { return }
        let content = UNMutableNotificationContent()
        content.title = "Great work!"
        content.body = "Reward unlocked: stretch, hydrate, and maintain good posture."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "focus_timer_hydrate", content: content, trigger: trigger)
        notificationCenter.add(request)
    }
}
