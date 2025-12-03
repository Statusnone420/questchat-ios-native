import ActivityKit
import Foundation

@available(iOS 17.0, *)
struct FocusSessionAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var remainingSeconds: Int
        var totalSeconds: Int
        var title: String
        var endTime: Date?
        var isRunning: Bool
        var level: Int
        var overallProgress: Double
        var hpPercent: Double
        var hydrationPercent: Double
        var moodPercent: Double
        var staminaPercent: Double
        var categorySymbolName: String
    }

    var sessionId: UUID
}
