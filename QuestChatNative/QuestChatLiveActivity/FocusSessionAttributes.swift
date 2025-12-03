import ActivityKit
import Foundation

@available(iOS 17.0, *)
struct FocusSessionAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var startDate: Date
        var endDate: Date
        var isPaused: Bool
        var remainingSeconds: Int
        var title: String
    }

    var sessionId: UUID
    var totalSeconds: Int
}
