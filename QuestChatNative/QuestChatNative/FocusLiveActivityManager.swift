import ActivityKit
import Foundation

@available(iOS 17.0, *)
enum FocusLiveActivityManager {
    private static var activity: Activity<FocusSessionAttributes>?

    static func start(title: String, totalSeconds: Int) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let attributes = FocusSessionAttributes(sessionId: UUID())
        let contentState = FocusSessionAttributes.ContentState(
            remainingSeconds: totalSeconds,
            totalSeconds: totalSeconds,
            title: title,
            endTime: Date().addingTimeInterval(TimeInterval(totalSeconds))
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

        let originalEndTime = activity.content.state.endTime

        let contentState = FocusSessionAttributes.ContentState(
            remainingSeconds: remainingSeconds,
            totalSeconds: totalSeconds,
            title: title,
            endTime: originalEndTime
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
}
