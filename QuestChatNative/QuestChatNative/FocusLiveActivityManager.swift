import ActivityKit
import Foundation

@available(iOS 16.1, *)
enum FocusLiveActivityManager {
    private static var activity: Activity<FocusSessionAttributes>?
    private static var currentContentState: FocusSessionAttributes.ContentState?

    static func start(title: String, totalSeconds: Int) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let startDate = Date()
        let endDate = startDate.addingTimeInterval(TimeInterval(totalSeconds))
        let attributes = FocusSessionAttributes(sessionId: UUID(), totalSeconds: totalSeconds)
        let contentState = FocusSessionAttributes.ContentState(
            startDate: startDate,
            endDate: endDate,
            isPaused: false,
            remainingSeconds: totalSeconds,
            title: title
        )
        currentContentState = contentState

        do {
            let content = ActivityContent(state: contentState, staleDate: nil)
            activity = try Activity.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
        } catch {
            print("Failed to start Focus Live Activity: \(error.localizedDescription)")
        }
    }

    static func update(remainingSeconds: Int, totalSeconds: Int, title: String) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        guard let activity else { return }

        let startDate = currentContentState?.startDate ?? Date()
        let endDate = startDate.addingTimeInterval(TimeInterval(totalSeconds))
        let contentState = FocusSessionAttributes.ContentState(
            startDate: startDate,
            endDate: endDate,
            isPaused: false,
            remainingSeconds: remainingSeconds,
            title: title
        )
        currentContentState = contentState

        Task {
            let content = ActivityContent(state: contentState, staleDate: nil)
            await activity.update(content)
        }
    }

    static func end() {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        guard let activity else { return }

        let finalState: FocusSessionAttributes.ContentState
        if let current = currentContentState {
            finalState = FocusSessionAttributes.ContentState(
                startDate: current.startDate,
                endDate: current.endDate,
                isPaused: false,
                remainingSeconds: 0,
                title: current.title
            )
        } else {
            finalState = FocusSessionAttributes.ContentState(
                startDate: Date(),
                endDate: Date(),
                isPaused: false,
                remainingSeconds: 0,
                title: ""
            )
        }

        Task {
            let content = ActivityContent(state: finalState, staleDate: nil)
            await activity.end(content, dismissalPolicy: .immediate)
            Self.activity = nil
            Self.currentContentState = nil
        }
    }

    // 🔧 New helper – called on app/tab appear to clean up zombies
    static func cleanupStaleActivities() {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        Task {
            for existing in Activity<FocusSessionAttributes>.activities {
                let finalState = FocusSessionAttributes.ContentState(
                    startDate: Date(),
                    endDate: Date(),
                    isPaused: false,
                    remainingSeconds: 0,
                    title: ""
                )
                let content = ActivityContent(state: finalState, staleDate: nil)
                await existing.end(content, dismissalPolicy: .immediate)
            }
        }
    }
}
