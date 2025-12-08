import Foundation
import ActivityKit

@available(iOS 16.1, *)
struct FocusTimerAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var title: String
        var endDate: Date
        var isPaused: Bool
    }

    // Static identity info for the activity
    var sessionType: String
}

@available(iOS 16.1, *)
final class FocusTimerLiveActivityManager {

    static let shared = FocusTimerLiveActivityManager()

    private var activity: Activity<FocusTimerAttributes>?
    private var currentState: FocusTimerAttributes.ContentState?

    private init() {}

    /// Start a Live Activity for the timer.
    /// - Parameters:
    ///   - endDate: when the timer finishes
    ///   - sessionType: an identifier like "deepFocus", "workSprint", etc.
    ///   - title: user-facing title like "Deep focus"
    func start(endDate: Date, sessionType: String, title: String) {
        let authInfo = ActivityAuthorizationInfo()
        print("🔍 LiveActivity auth – enabled:", authInfo.areActivitiesEnabled)

        guard authInfo.areActivitiesEnabled else {
            print("❌ Live Activities not enabled for this device/app.")
            return
        }

        let attributes = FocusTimerAttributes(sessionType: sessionType)
        let contentState = FocusTimerAttributes.ContentState(
            title: title,
            endDate: endDate,
            isPaused: false
        )
        self.currentState = contentState

        do {
            print("🚀 Requesting Live Activity – title:", title, "end:", endDate)
            if #available(iOS 16.2, *) {
                let content = ActivityContent(state: contentState, staleDate: endDate)
                activity = try Activity.request(
                    attributes: attributes,
                    content: content,
                    pushType: nil
                )
            } else {
                activity = try Activity.request(
                    attributes: attributes,
                    contentState: contentState,
                    pushType: nil
                )
            }
            print("✅ Live Activity started:", String(describing: activity))
        } catch {
            print("❌ Failed to start Live Activity:", error)
        }
    }

    /// Update the Live Activity's content state. Pass only the values you want to change.
    func update(title: String? = nil, endDate: Date? = nil, isPaused: Bool? = nil) {
        guard let activity = self.activity else {
            print("ℹ️ No active Live Activity to update")
            return
        }
        guard var state = self.currentState else {
            print("ℹ️ Missing current state; cannot update")
            return
        }

        // Apply changes
        state.title = title ?? state.title
        state.endDate = endDate ?? state.endDate
        state.isPaused = isPaused ?? state.isPaused

        // Save locally
        self.currentState = state

        if #available(iOS 16.2, *) {
            let stale = state.isPaused ? nil : state.endDate
            let content = ActivityContent(state: state, staleDate: stale)
            Task {
                await activity.update(content)
            }
        } else {
            Task {
                await activity.update(using: state)
            }
        }
    }

    /// Convenience: pause the timer
    func pause() {
        update(isPaused: true)
    }

    /// Convenience: resume the timer
    func resume() {
        update(isPaused: false)
    }

    func end() {
        Task {
            print("🧹 Ending Live Activity")
            if #available(iOS 16.2, *) {
                let finalState = self.currentState ?? FocusTimerAttributes.ContentState(
                    title: "",
                    endDate: Date(),
                    isPaused: true
                )
                let content = ActivityContent(state: finalState, staleDate: nil)
                await activity?.end(content, dismissalPolicy: .immediate)
            } else {
                await activity?.end(dismissalPolicy: .immediate)
            }
            activity = nil
            self.currentState = nil
        }
    }

    func cancel() {
        Task {
            print("🛑 Cancelling Live Activity")
            if #available(iOS 16.2, *) {
                let finalState = self.currentState ?? FocusTimerAttributes.ContentState(
                    title: "",
                    endDate: Date(),
                    isPaused: true
                )
                let content = ActivityContent(state: finalState, staleDate: nil)
                await activity?.end(content, dismissalPolicy: .immediate)
            } else {
                await activity?.end(dismissalPolicy: .immediate)
            }
            activity = nil
            self.currentState = nil
        }
    }
}

