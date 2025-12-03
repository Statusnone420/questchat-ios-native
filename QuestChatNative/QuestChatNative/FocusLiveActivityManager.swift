import ActivityKit
import Foundation

@available(iOS 17.0, *)
enum FocusLiveActivityManager {
    struct Snapshot {
        let title: String
        let totalSeconds: Int
        let remainingSeconds: Int
        let isRunning: Bool
        let level: Int
        let overallProgress: Double
        let hpPercent: Double
        let hydrationPercent: Double
        let moodPercent: Double
        let staminaPercent: Double
        let categorySymbolName: String
    }

    private static var activity: Activity<FocusSessionAttributes>?

    static func startNewSession(with snapshot: Snapshot) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        // End any stale activity to guarantee a single source of truth.
        Task { await activity?.end(dismissalPolicy: .immediate) }

        let attributes = FocusSessionAttributes(sessionId: UUID())
        let contentState = makeContentState(from: snapshot, endDate: Date().addingTimeInterval(TimeInterval(snapshot.remainingSeconds)))

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

    static func resume(with snapshot: Snapshot) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        guard let activity else { return }

        let endDate = Date().addingTimeInterval(TimeInterval(snapshot.remainingSeconds))
        let contentState = makeContentState(from: snapshot, endDate: endDate)

        Task { await activity.update(using: contentState) }
    }

    static func pause(with snapshot: Snapshot) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        guard let activity else { return }

        // Clearing endDate freezes the countdown on the lock screen and island.
        let contentState = makeContentState(from: snapshot, endDate: nil)
        Task { await activity.update(using: contentState) }
    }

    static func refresh(with snapshot: Snapshot) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        guard let activity else { return }

        let endDate = snapshot.isRunning ? Date().addingTimeInterval(TimeInterval(snapshot.remainingSeconds)) : nil
        let contentState = makeContentState(from: snapshot, endDate: endDate)
        Task { await activity.update(using: contentState) }
    }

    static func end() {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        Task {
            await activity?.end(dismissalPolicy: .immediate)
            activity = nil
        }
    }

    // 🔧 New helper – called on app/tab appear to clean up zombies
    static func cleanupStaleActivities() {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        Task {
            for existing in Activity<FocusSessionAttributes>.activities {
                await existing.end(dismissalPolicy: .immediate)
            }
            activity = nil
        }
    }

    private static func makeContentState(from snapshot: Snapshot, endDate: Date?) -> FocusSessionAttributes.ContentState {
        FocusSessionAttributes.ContentState(
            remainingSeconds: max(snapshot.remainingSeconds, 0),
            totalSeconds: max(snapshot.totalSeconds, 1),
            title: snapshot.title,
            endTime: endDate,
            isRunning: snapshot.isRunning,
            level: snapshot.level,
            overallProgress: max(0, min(snapshot.overallProgress, 1)),
            hpPercent: max(0, min(snapshot.hpPercent, 1)),
            hydrationPercent: max(0, min(snapshot.hydrationPercent, 1)),
            moodPercent: max(0, min(snapshot.moodPercent, 1)),
            staminaPercent: max(0, min(snapshot.staminaPercent, 1)),
            categorySymbolName: snapshot.categorySymbolName
        )
    }
}
