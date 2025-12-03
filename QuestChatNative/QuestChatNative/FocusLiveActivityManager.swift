import ActivityKit
import Foundation

@available(iOS 17.0, *)
enum FocusLiveActivityManager {
    private static var activity: Activity<FocusSessionAttributes>?

    static func start(title: String, totalSeconds: Int) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let attributes = FocusSessionAttributes(sessionId: UUID(), totalSeconds: totalSeconds)
        let contentState = FocusSessionAttributes.ContentState(
            startDate: Date(),
            endDate: Date().addingTimeInterval(TimeInterval(totalSeconds)),
            isPaused: false,
            remainingSeconds: totalSeconds,
            title: title
        )

        do {
            activity = try Activity.request(
                attributes: attributes,
                contentState: contentState,
                pushType: nil
            )
        } catch {
            print("Failed to start Focus Live Activity: \(error.localizedDescription)")
        }
    }

    static func update(remainingSeconds: Int, totalSeconds: Int, title: String) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        guard let activity else { return }

        let contentState = FocusSessionAttributes.ContentState(
            startDate: Date(),
            endDate: Date().addingTimeInterval(TimeInterval(remainingSeconds)),
            isPaused: false,
            remainingSeconds: remainingSeconds,
            title: title
        )

        Task {
            await activity.update(using: contentState)
        }
    }

    static func end() {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        Task {
            await activity?.end(dismissalPolicy: .immediate)
            activity = nil
        }
    }

    // 🔧 New helper – called on app/tab appear to clean up zombies
    static func cleanupStaleActivities() {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        Task {
            for existing in Activity<FocusSessionAttributes>.activities {
                await existing.end(dismissalPolicy: .immediate)
            }
        }
    }
}
