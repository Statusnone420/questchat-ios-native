import Foundation
import ActivityKit

@available(iOS 16.1, *)
struct FocusTimerAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var title: String
        var endDate: Date?
        var isPaused: Bool
        var remainingSeconds: Int
    }

    // Static identity info for the activity
    var sessionType: String
}

@available(iOS 16.1, *)
final class FocusTimerLiveActivityManager {

    static let shared = FocusTimerLiveActivityManager()

    private var activity: Activity<FocusTimerAttributes>?

    private init() {}

    /// Start or update a Live Activity for the timer.
    /// If the activity already exists, this refreshes the content instead of creating a duplicate.
    /// - Parameters:
    ///   - remainingSeconds: seconds left in the session
    ///   - isRunning: whether the timer is actively counting down
    ///   - isNewSession: set to true only when moving from idle -> running
    ///   - sessionType: an identifier like "deepFocus", "workSprint", etc.
    ///   - title: user-facing title like "Deep focus"
    func start(
        remainingSeconds: Int,
        isRunning: Bool,
        isNewSession: Bool,
        sessionType: String,
        title: String
    ) {
        let authInfo = ActivityAuthorizationInfo()
        print("🔍 LiveActivity auth – enabled:", authInfo.areActivitiesEnabled)

        guard authInfo.areActivitiesEnabled else {
            print("❌ Live Activities not enabled for this device/app.")
            return
        }

        let contentState = FocusTimerAttributes.ContentState(
            title: title,
            endDate: isRunning ? Date().addingTimeInterval(TimeInterval(remainingSeconds)) : nil,
            isPaused: !isRunning,
            remainingSeconds: max(remainingSeconds, 0)
        )

        if isNewSession {
            Task { await activity?.end(dismissalPolicy: .immediate) }
            let attributes = FocusTimerAttributes(sessionType: sessionType)
            do {
                print("🚀 Requesting Live Activity – title:", title)
                activity = try Activity.request(
                    attributes: attributes,
                    contentState: contentState,
                    pushType: nil
                )
                print("✅ Live Activity started:", String(describing: activity))
            } catch {
                print("❌ Failed to start Live Activity:", error)
            }
        } else {
            guard let activity else { return }
            Task {
                print("🔄 Updating Live Activity – running: \(!contentState.isPaused), remaining: \(contentState.remainingSeconds)")
                await activity.update(using: contentState)
            }
        }
    }

    func end() {
        Task {
            print("🧹 Ending Live Activity")
            await activity?.end(dismissalPolicy: .immediate)
            activity = nil
        }
    }

    func cancel() {
        Task {
            print("🛑 Cancelling Live Activity")
            await activity?.end(dismissalPolicy: .immediate)
            activity = nil
        }
    }
}
