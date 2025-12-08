import Foundation

enum SeasonAchievementConditionType: String, Hashable {
    case hydrationDaysReached
    case focusSessionsLong
    case dailyFocusMinutesStreak
    case hpAboveThresholdDays
    case questsTabOpenedDaysStreak
    case choreBlitzSessions
    case moodAboveMehDaysStreak
    case fourRealmsWeek
}

struct SeasonAchievement: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let iconName: String
    let conditionType: SeasonAchievementConditionType
    let threshold: Int
    let seasonId: String
    let xpReward: Int
    let isSecret: Bool
}

struct SeasonAchievementProgress: Identifiable, Hashable, Codable {
    let id: String
    let achievementId: String
    var currentValue: Int
    var unlockedAt: Date?
    var lastUpdatedAt: Date?

    var isUnlocked: Bool {
        unlockedAt != nil
    }
}

extension SeasonAchievement {
    static let currentSeasonId = "S1"

    var requirementText: String { subtitle }

    var descriptionText: String { subtitle }

    var rewardTitle: String? { title }

    static let allSeasonOne: [SeasonAchievement] = [
        SeasonAchievement(
            id: "hydration_demon",
            title: "Hydration Demon",
            subtitle: "Hit your hydration goal on 20 days in one season.",
            iconName: "💧",
            conditionType: .hydrationDaysReached,
            threshold: 20,
            seasonId: currentSeasonId,
            xpReward: 500,
            isSecret: false
        ),
        SeasonAchievement(
            id: "deep_focus_diver",
            title: "Deep Focus Diver",
            subtitle: "Complete 25 focus sessions of at least 40 minutes in one season.",
            iconName: "brain.head.profile",
            conditionType: .focusSessionsLong,
            threshold: 25,
            seasonId: currentSeasonId,
            xpReward: 800,
            isSecret: false
        ),
        SeasonAchievement(
            id: "distraction_dodger",
            title: "Distraction Dodger",
            subtitle: "Do 7 days in a row with at least 60 focus minutes.",
            iconName: "shield.fill",
            conditionType: .dailyFocusMinutesStreak,
            threshold: 7,
            seasonId: currentSeasonId,
            xpReward: 900,
            isSecret: false
        ),
        SeasonAchievement(
            id: "irl_healthbar_guardian",
            title: "IRL HealthBar Guardian",
            subtitle: "Keep your HP above 70% for 15 days in one season.",
            iconName: "heart.fill",
            conditionType: .hpAboveThresholdDays,
            threshold: 15,
            seasonId: currentSeasonId,
            xpReward: 650,
            isSecret: false
        ),
        SeasonAchievement(
            id: "daily_questkeeper",
            title: "Daily Questkeeper",
            subtitle: "Open the Quests tab 7 days in a row.",
            iconName: "list.bullet.rectangle",
            conditionType: .questsTabOpenedDaysStreak,
            threshold: 7,
            seasonId: currentSeasonId,
            xpReward: 400,
            isSecret: false
        ),
        SeasonAchievement(
            id: "dungeon_janitor",
            title: "Dungeon Janitor",
            subtitle: "Complete 20 chore blitz sessions of at least 10 minutes in one season.",
            iconName: "🧹",
            conditionType: .choreBlitzSessions,
            threshold: 20,
            seasonId: currentSeasonId,
            xpReward: 550,
            isSecret: false
        ),
        SeasonAchievement(
            id: "ray_of_sunshine",
            title: "Ray of Sunshine",
            subtitle: "Keep your mood above ‘meh’ for 3 days in a row.",
            iconName: "sun.max.fill",
            conditionType: .moodAboveMehDaysStreak,
            threshold: 3,
            seasonId: currentSeasonId,
            xpReward: 350,
            isSecret: false
        ),
        SeasonAchievement(
            id: "four_realms_explorer",
            title: "Four Realms Explorer",
            subtitle: "Every day for a week, run at least one Work, Home, Health, and Chill session of 30+ minutes.",
            iconName: "globe.asia.australia.fill",
            conditionType: .fourRealmsWeek,
            threshold: 1,
            seasonId: currentSeasonId,
            xpReward: 1000,
            isSecret: false
        )
    ]
}
