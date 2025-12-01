import Foundation
import SwiftUI
import UIKit
import UserNotifications

/// A Pomodoro-style focus timer that remains accurate across app lifecycle events
/// and schedules a local notification upon completion.
@MainActor
final class FocusTimerViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var remainingSeconds: Int
    @Published var isRunning: Bool = false
    @Published var selectedDurationMinutes: Int {
        didSet {
            persistSelectedDuration()
            if !isRunning {
                remainingSeconds = selectedDurationMinutes * 60
            }
        }
    }

    // MARK: - Private Properties

    private var timer: Timer?
    private var focusEndDate: Date?
    private let notificationCenter = UNUserNotificationCenter.current()
    private let durationStorageKey = "focusDurationMinutes"
    private let notificationIdentifier = "focusTimerCompletion"

    // MARK: - Initialization

    init() {
        let storedMinutes = UserDefaults.standard.integer(forKey: durationStorageKey)
        let initialMinutes = Self.validatedDuration(storedMinutes == 0 ? 25 : storedMinutes)
        selectedDurationMinutes = initialMinutes
        remainingSeconds = initialMinutes * 60

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppWillResignActive),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
    }

    deinit {
        invalidateTimer()
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Timer Controls

    func start() {
        guard !isRunning else { return }

        if remainingSeconds <= 0 {
            remainingSeconds = selectedDurationMinutes * 60
        }

        focusEndDate = Date().addingTimeInterval(TimeInterval(remainingSeconds))
        isRunning = true

        scheduleTimer()
        requestNotificationPermissionIfNeeded { [weak self] granted in
            guard let self else { return }
            if granted, let focusEndDate {
                self.scheduleCompletionNotification(for: focusEndDate)
            }
        }
    }

    func pause() {
        guard isRunning else { return }
        invalidateTimer()
        isRunning = false
        focusEndDate = nil
        cancelScheduledNotification()
    }

    func reset() {
        invalidateTimer()
        isRunning = false
        remainingSeconds = selectedDurationMinutes * 60
        focusEndDate = nil
        cancelScheduledNotification()
    }

    // MARK: - App Lifecycle

    @objc
    func handleAppDidBecomeActive() {
        guard let focusEndDate else { return }
        recalculateRemainingSeconds(targetDate: focusEndDate)
        if isRunning {
            scheduleTimer()
        }
    }

    @objc
    func handleAppWillResignActive() {
        // Intentionally left blank; focusEndDate keeps tracking while backgrounded.
    }

    // MARK: - Private Helpers

    private func scheduleTimer() {
        invalidateTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            guard let focusEndDate else {
                self.handleTimerFinished()
                return
            }
            recalculateRemainingSeconds(targetDate: focusEndDate)
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    private func recalculateRemainingSeconds(targetDate: Date) {
        let secondsLeft = max(Int(targetDate.timeIntervalSinceNow.rounded()), 0)
        remainingSeconds = secondsLeft

        if secondsLeft <= 0 {
            handleTimerFinished()
        }
    }

    private func handleTimerFinished() {
        invalidateTimer()
        isRunning = false
        remainingSeconds = 0
        focusEndDate = nil
        sendCompletionFeedback()
    }

    private func invalidateTimer() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Notification Handling

    private func requestNotificationPermissionIfNeeded(completion: @escaping (Bool) -> Void) {
        notificationCenter.getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .authorized, .provisional:
                completion(true)
            case .notDetermined:
                self.notificationCenter.requestAuthorization(options: [.alert, .sound]) { granted, _ in
                    completion(granted)
                }
            default:
                completion(false)
            }
        }
    }

    private func scheduleCompletionNotification(for date: Date) {
        cancelScheduledNotification()

        let content = UNMutableNotificationContent()
        content.title = "Focus session complete! 🎉"
        content.body = "Nice work. Take a short break or start another quest."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(date.timeIntervalSinceNow, 1), repeats: false)
        let request = UNNotificationRequest(identifier: notificationIdentifier, content: content, trigger: trigger)

        notificationCenter.add(request, withCompletionHandler: nil)
    }

    private func cancelScheduledNotification() {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [notificationIdentifier])
    }

    private func sendCompletionFeedback() {
        cancelScheduledNotification()

        let feedbackGenerator = UINotificationFeedbackGenerator()
        feedbackGenerator.notificationOccurred(.success)

        // Deliver a foreground notification as a subtle cue.
        let content = UNMutableNotificationContent()
        content.title = "Focus session complete! 🎉"
        content.body = "Nice work. Take a short break or start another quest."
        content.sound = .default

        let request = UNNotificationRequest(identifier: notificationIdentifier, content: content, trigger: nil)
        notificationCenter.add(request, withCompletionHandler: nil)
    }

    private func persistSelectedDuration() {
        UserDefaults.standard.set(selectedDurationMinutes, forKey: durationStorageKey)
    }

    private static func validatedDuration(_ minutes: Int) -> Int {
        let validSteps = stride(from: 5, through: 60, by: 5)
        guard validSteps.contains(minutes) else { return 25 }
        return minutes
    }
}
