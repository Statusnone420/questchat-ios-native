import Foundation
import Combine

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

