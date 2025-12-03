import Foundation
import ActivityKit

@available(iOS 16.1, *)
struct FocusTimerAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var title: String
        var endDate: Date?
        var remainingSeconds: Int
        var totalDurationSeconds: Int
        var isPaused: Bool
    }

    // Static identity info for the activity
    var sessionType: String
}

@available(iOS 16.1, *)
final class FocusTimerLiveActivityManager {

    static let shared = FocusTimerLiveActivityManager()

    private var activity: Activity<FocusTimerAttributes>?

    private init() {}

    /// Starts or updates a Live Activity for the timer, keeping only one active at a time.
    func startOrUpdate(
        endDate: Date?,
        sessionType: String,
        title: String,
        remainingSeconds: Int,
        totalDurationSeconds: Int,
        isPaused: Bool
    ) {
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
            remainingSeconds: remainingSeconds,
            totalDurationSeconds: totalDurationSeconds,
            isPaused: isPaused
        )

        if let activity {
            Task { await activity.update(using: contentState) }
            return
        }

        do {
            print("🚀 Requesting Live Activity – title:", title, "end:", String(describing: endDate))
            activity = try Activity.request(
                attributes: attributes,
                contentState: contentState,
                pushType: nil
            )
            print("✅ Live Activity started:", String(describing: activity))
        } catch {
            print("❌ Failed to start Live Activity:", error)
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
