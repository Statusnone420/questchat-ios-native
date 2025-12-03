import ActivityKit
import Foundation

/// Live Activity coordination for the focus timer.
/// Maintains a single Activity instance and keeps it in sync with the in-app timer state
/// (start, pause, resume, finish/reset) so the lock screen and Dynamic Island never drift.
protocol FocusLiveActivityManaging {
    func startOrUpdate(
        title: String,
        totalDurationSeconds: Int,
        remainingSeconds: Int,
        endDate: Date?,
        isPaused: Bool
    )
    func end()
    func cleanupStaleActivities()
}

final class FocusLiveActivityManager: FocusLiveActivityManaging {
    @available(iOS 17.0, *)
    private var currentModernActivity: Activity<FocusSessionAttributes>? {
        get { modernActivityStorage }
        set { modernActivityStorage = newValue }
    }

    @available(iOS 17.0, *)
    private var modernActivityStorage: Activity<FocusSessionAttributes>?

    @available(iOS 16.1, *)
    private let legacyManager = FocusTimerLiveActivityManager.shared

    func startOrUpdate(
        title: String,
        totalDurationSeconds: Int,
        remainingSeconds: Int,
        endDate: Date?,
        isPaused: Bool
    ) {
        guard #available(iOS 16.1, *) else { return }

        if #available(iOS 17.0, *) {
            startOrUpdateModern(
                title: title,
                totalDurationSeconds: totalDurationSeconds,
                remainingSeconds: remainingSeconds,
                endDate: endDate,
                isPaused: isPaused
            )
        } else {
            legacyManager.startOrUpdate(
                endDate: endDate,
                sessionType: title,
                title: title,
                remainingSeconds: remainingSeconds,
                totalDurationSeconds: totalDurationSeconds,
                isPaused: isPaused
            )
        }
    }

    func end() {
        guard #available(iOS 16.1, *) else { return }

        if #available(iOS 17.0, *) {
            Task {
                await currentModernActivity?.end(dismissalPolicy: .immediate)
                currentModernActivity = nil
            }
        } else {
            legacyManager.end()
        }
    }

    func cleanupStaleActivities() {
        guard #available(iOS 16.1, *) else { return }

        if #available(iOS 17.0, *) {
            Task {
                // Only keep a single modern activity alive and clear any stray ones left behind by crashes.
                for activity in Activity<FocusSessionAttributes>.activities {
                    if currentModernActivity == nil {
                        currentModernActivity = activity
                        continue
                    }
                    await activity.end(dismissalPolicy: .immediate)
                }
            }
        } else {
            Task {
                for activity in Activity<FocusTimerAttributes>.activities {
                    await activity.end(dismissalPolicy: .immediate)
                }
            }
        }
    }

    @available(iOS 17.0, *)
    private func startOrUpdateModern(
        title: String,
        totalDurationSeconds: Int,
        remainingSeconds: Int,
        endDate: Date?,
        isPaused: Bool
    ) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let state = FocusSessionAttributes.ContentState(
            remainingSeconds: remainingSeconds,
            totalDurationSeconds: totalDurationSeconds,
            title: title,
            endTime: endDate,
            isPaused: isPaused
        )

        if let activity = currentModernActivity {
            Task { await activity.update(using: state) }
            return
        }

        let attributes = FocusSessionAttributes(sessionId: UUID())
        Task {
            do {
                currentModernActivity = try Activity.request(
                    attributes: attributes,
                    contentState: state,
                    pushType: nil
                )
            } catch {
                print("Failed to start Focus Live Activity: \(error.localizedDescription)")
            }
        }
    }
}
