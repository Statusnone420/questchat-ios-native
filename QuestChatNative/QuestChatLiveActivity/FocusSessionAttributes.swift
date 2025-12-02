import ActivityKit
import Foundation

@available(iOS 17.0, *)
struct FocusSessionAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var remainingSeconds: Int
        var totalSeconds: Int
        var title: String
        var endTime: Date
    }

    var sessionId: UUID
}
