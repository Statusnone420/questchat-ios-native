import Foundation
import Combine

extension Notification.Name {
    static let seasonAchievementUnlocked = Notification.Name("seasonAchievementUnlocked")
}

final class SeasonAchievementsStore: ObservableObject {
    @Published private(set) var achievements: [SeasonAchievement]
    @Published private(set) var progressById: [String: SeasonAchievementProgress]

    init(achievements: [SeasonAchievement] = SeasonAchievement.allSeasonOne) {
        self.achievements = achievements
        self.progressById = Self.initialProgress(for: achievements)
        // TODO: persistence
    }

    func progress(for achievement: SeasonAchievement) -> SeasonAchievementProgress {
        progressById[achievement.id] ?? SeasonAchievementProgress(
            id: achievement.id,
            achievementId: achievement.id,
            currentValue: 0,
            unlockedAt: nil,
            lastUpdatedAt: nil
        )
    }

    /// Call this when a game event occurs (e.g., hydration goal met).
    /// - Returns: The first achievement that just unlocked, if any.
    @discardableResult
    func applyProgress(for conditionType: SeasonAchievementConditionType, increment: Int = 1) -> SeasonAchievement? {
        var unlockedAchievement: SeasonAchievement?

        for achievement in achievements where achievement.conditionType == conditionType {
            guard var progress = progressById[achievement.id] else { continue }
            guard !progress.isUnlocked else { continue }

            progress.currentValue += increment
            progress.lastUpdatedAt = Date()

            if progress.currentValue >= achievement.threshold {
                progress.currentValue = achievement.threshold
                progress.unlockedAt = Date()
                unlockedAchievement = achievement
            }

            progressById[achievement.id] = progress
        }

        if let unlocked = unlockedAchievement {
            NotificationCenter.default.post(
                name: .seasonAchievementUnlocked,
                object: self,
                userInfo: ["achievementId": unlocked.id]
            )
        }

        return unlockedAchievement
    }

    private static func initialProgress(for achievements: [SeasonAchievement]) -> [String: SeasonAchievementProgress] {
        Dictionary(uniqueKeysWithValues: achievements.map { achievement in
            (achievement.id, SeasonAchievementProgress(
                id: achievement.id,
                achievementId: achievement.id,
                currentValue: 0,
                unlockedAt: nil,
                lastUpdatedAt: nil
            ))
        })
    }
}

