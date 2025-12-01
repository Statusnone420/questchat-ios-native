import Foundation
import Combine
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
        switch self {
        case .focus: 25 * 60
        case .selfCare: 5 * 60
        }
    }

    var accentSystemImage: String {
        switch self {
        case .focus: "flame.fill"
        case .selfCare: "heart.fill"
        }
    }
}

/// Stores session stats and persists them in UserDefaults for now.
final class SessionStatsStore: ObservableObject {
    @Published private(set) var focusSeconds: Int
    @Published private(set) var selfCareSeconds: Int
    @Published private(set) var sessionsCompleted: Int
    @Published private(set) var xp: Int

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        focusSeconds = userDefaults.integer(forKey: Keys.focusSeconds)
        selfCareSeconds = userDefaults.integer(forKey: Keys.selfCareSeconds)
        sessionsCompleted = userDefaults.integer(forKey: Keys.sessionsCompleted)
        xp = userDefaults.integer(forKey: Keys.xp)
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
        persist()
    }

    func resetAll() {
        focusSeconds = 0
        selfCareSeconds = 0
        sessionsCompleted = 0
        xp = 0
        persist()
    }

    private let userDefaults: UserDefaults

    private enum Keys {
        static let focusSeconds = "focusSeconds"
        static let selfCareSeconds = "selfCareSeconds"
        static let sessionsCompleted = "sessionsCompleted"
        static let xp = "xp"
    }

    private func persist() {
        userDefaults.set(focusSeconds, forKey: Keys.focusSeconds)
        userDefaults.set(selfCareSeconds, forKey: Keys.selfCareSeconds)
        userDefaults.set(sessionsCompleted, forKey: Keys.sessionsCompleted)
        userDefaults.set(xp, forKey: Keys.xp)
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
