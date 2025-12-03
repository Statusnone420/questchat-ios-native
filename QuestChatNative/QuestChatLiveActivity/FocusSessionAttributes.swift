import ActivityKit
import Foundation

@available(iOS 17.0, *)
struct FocusSessionAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var remainingSeconds: Int
        var totalDurationSeconds: Int
        var title: String
        /// When the timer is running this drives the system countdown; when paused this will be nil.
        var endTime: Date?
        var isPaused: Bool
    }

    var sessionId: UUID
}
