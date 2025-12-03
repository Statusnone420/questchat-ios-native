import Foundation
import ActivityKit

@available(iOS 16.1, *)
struct FocusTimerAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var startDate: Date
        var title: String
        var endDate: Date
        var isPaused: Bool
    }

    // Static identity info for the activity
    var sessionType: String
}

@available(iOS 16.2, *)
final class FocusTimerLiveActivityManager {

    static let shared = FocusTimerLiveActivityManager()

    private var activity: Activity<FocusTimerAttributes>?

    private init() {}

    /// Start a Live Activity for the timer.
    /// - Parameters:
    ///   - endDate: when the timer finishes
    ///   - sessionType: an identifier like "deepFocus", "workSprint", etc.
    ///   - title: user-facing title like "Deep focus"
    func start(endDate: Date, sessionType: String, title: String) async -> Activity<FocusTimerAttributes>? {
        let authInfo = ActivityAuthorizationInfo()
        print("🔍 LiveActivity auth – enabled:", authInfo.areActivitiesEnabled)

        guard authInfo.areActivitiesEnabled else {
            print("❌ Live Activities not enabled for this device/app.")
            return nil
        }

        await endAllActivities()

        let attributes = FocusTimerAttributes(sessionType: sessionType)
        let startDate = Date()
        let contentState = FocusTimerAttributes.ContentState(
            startDate: startDate,
            title: title,
            endDate: endDate,
            isPaused: false
        )
        let content = ActivityContent(state: contentState, staleDate: endDate)

        do {
            print("🚀 Requesting Live Activity – title:", title, "end:", endDate)
            activity = try Activity.request(
                attributes: attributes,
                content: content
            )
            print("✅ Live Activity started:", String(describing: activity))
            return activity
        } catch {
            print("❌ Failed to start Live Activity:", error)
            return nil
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

    private func endAllActivities() async {
        for activity in Activity<FocusTimerAttributes>.activities {
            await activity.end(dismissalPolicy: .immediate)
        }
        await MainActor.run {
            self.activity = nil
        }
    }
}
