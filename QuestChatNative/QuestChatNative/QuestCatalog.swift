import Foundation

enum QuestType {
    case daily
    case weekly
}

enum QuestCategory {
    case timer
    case healthBar
    case meta
    case easyWin
    case focus
    case hydration
    case hpCore
    case choresWork
}

enum QuestDifficulty {
    case tiny
    case easy
    case small
    case medium
    case hard
    case big
}

enum QuestCompletionMode {
    case automatic
    case manualDebug
}

struct QuestDefinition {
    let id: String
    let type: QuestType
    let category: QuestCategory
    let difficulty: QuestDifficulty
    let xpReward: Int
    let title: String
    let subtitle: String
    let isOncePerDay: Bool
    let tier: Quest.Tier
    let completionMode: QuestCompletionMode

    init(
        id: String,
        type: QuestType,
        category: QuestCategory,
        difficulty: QuestDifficulty,
        xpReward: Int,
        title: String,
        subtitle: String,
        isOncePerDay: Bool,
        tier: Quest.Tier,
        completionMode: QuestCompletionMode = .automatic
    ) {
        self.id = id
        self.type = type
        self.category = category
        self.difficulty = difficulty
        self.xpReward = xpReward
        self.title = title
        self.subtitle = subtitle
        self.isOncePerDay = isOncePerDay
        self.tier = tier
        self.completionMode = completionMode
    }
}


enum QuestCatalog {
    static let expandedDailyQuests: [QuestDefinition] = [
        QuestDefinition(
            id: "DAILY_TIMER_DEEP_WORK",
            type: .daily,
            category: .timer,
            difficulty: .medium,
            xpReward: 40,
            title: "Deep Work Session",
            subtitle: "Complete one Work timer for 40+ minutes.",
            isOncePerDay: true,
            tier: .habit
        ),
        QuestDefinition(
            id: "DAILY_TIMER_QUICK_WORK",
            type: .daily,
            category: .timer,
            difficulty: .easy,
            xpReward: 20,
            title: "Quick Win Work",
            subtitle: "Finish a Work timer for 15+ minutes.",
            isOncePerDay: true,
            tier: .habit
        ),
        QuestDefinition(
            id: "DAILY_TIMER_CHORES_BURST",
            type: .daily,
            category: .timer,
            difficulty: .easy,
            xpReward: 20,
            title: "Chores Burst",
            subtitle: "Finish a Chores timer for 10+ minutes.",
            isOncePerDay: true,
            tier: .habit
        ),
        QuestDefinition(
            id: "DAILY_TIMER_HOME_RESET",
            type: .daily,
            category: .timer,
            difficulty: .medium,
            xpReward: 35,
            title: "Home Base Reset",
            subtitle: "Finish a Chores timer for 25+ minutes.",
            isOncePerDay: true,
            tier: .habit
        ),
        QuestDefinition(
            id: "DAILY_TIMER_SELF_CARE",
            type: .daily,
            category: .timer,
            difficulty: .medium,
            xpReward: 35,
            title: "Self-Care Session",
            subtitle: "Finish a Self-Care timer for 20+ minutes.",
            isOncePerDay: true,
            tier: .habit
        ),
        QuestDefinition(
            id: "DAILY_TIMER_MINDFUL_BREAK",
            type: .daily,
            category: .timer,
            difficulty: .easy,
            xpReward: 20,
            title: "Mindful Break",
            subtitle: "Finish a Self-Care timer for 10+ minutes.",
            isOncePerDay: true,
            tier: .habit
        ),
        QuestDefinition(
            id: "DAILY_TIMER_FOCUS_CHAIN",
            type: .daily,
            category: .timer,
            difficulty: .medium,
            xpReward: 35,
            title: "Focus Chain",
            subtitle: "Complete any non-Chill timer 20+ minutes long with no pauses.",
            isOncePerDay: true,
            tier: .habit
        ),
        QuestDefinition(
            id: "DAILY_TIMER_EVENING_RESET",
            type: .daily,
            category: .timer,
            difficulty: .medium,
            xpReward: 35,
            title: "Evening Reset Run",
            subtitle: "Finish a Chores/Self-Care timer 15+ minutes that ends after 6:00pm.",
            isOncePerDay: true,
            tier: .habit
        ),
        QuestDefinition(
            id: "DAILY_TIMER_BOSS_BATTLE",
            type: .daily,
            category: .timer,
            difficulty: .hard,
            xpReward: 60,
            title: "Boss Battle Session",
            subtitle: "Complete a Work timer for 60+ minutes.",
            isOncePerDay: true,
            tier: .bonus
        ),
        QuestDefinition(
            id: "DAILY_TIMER_CHILL_CHOICE",
            type: .daily,
            category: .timer,
            difficulty: .medium,
            xpReward: 35,
            title: "Chill Without Guilt",
            subtitle: "Finish a Chill timer for 20+ minutes.",
            isOncePerDay: true,
            tier: .habit
        ),
        QuestDefinition(
            id: "DAILY_HB_MORNING_CHECKIN",
            type: .daily,
            category: .healthBar,
            difficulty: .easy,
            xpReward: 15,
            title: "Morning Check-In",
            subtitle: "Log today’s mood for the first time.",
            isOncePerDay: true,
            tier: .habit
        ),
        QuestDefinition(
            id: "DAILY_HB_SLEEP_LOG",
            type: .daily,
            category: .healthBar,
            difficulty: .easy,
            xpReward: 15,
            title: "Sleep Log",
            subtitle: "Log last night’s sleep hours.",
            isOncePerDay: true,
            tier: .habit
        ),
        QuestDefinition(
            id: "DAILY_HB_FIRST_POTION",
            type: .daily,
            category: .healthBar,
            difficulty: .easy,
            xpReward: 15,
            title: "First Potion of the Day",
            subtitle: "Log any hydration > 0 ml.",
            isOncePerDay: true,
            tier: .habit
        ),
        QuestDefinition(
            id: "DAILY_HB_HALF_HYDRATED",
            type: .daily,
            category: .healthBar,
            difficulty: .medium,
            xpReward: 30,
            title: "Halfway Hydrated",
            subtitle: "Reach 50% of today’s hydration goal.",
            isOncePerDay: true,
            tier: .habit
        ),
        QuestDefinition(
            id: "DAILY_HB_HYDRATION_COMPLETE",
            type: .daily,
            category: .healthBar,
            difficulty: .medium,
            xpReward: 40,
            title: "Hydration Complete",
            subtitle: "Reach 100% of hydration goal.",
            isOncePerDay: true,
            tier: .habit
        ),
        QuestDefinition(
            id: "DAILY_HB_POSTURE_CHECK",
            type: .daily,
            category: .healthBar,
            difficulty: .easy,
            xpReward: 20,
            title: "Posture Check",
            subtitle: "Complete one posture check.",
            isOncePerDay: true,
            tier: .habit
        ),
        QuestDefinition(
            id: "DAILY_HB_GENTLE_MOVEMENT",
            type: .daily,
            category: .healthBar,
            difficulty: .easy,
            xpReward: 20,
            title: "Gentle Movement",
            subtitle: "Run a movement/stretch Self-Care timer 5+ minutes.",
            isOncePerDay: true,
            tier: .habit
        ),
        QuestDefinition(
            id: "DAILY_HB_GUT_CHECK",
            type: .daily,
            category: .healthBar,
            difficulty: .easy,
            xpReward: 20,
            title: "Gut Check-In",
            subtitle: "Log today’s gut health slider.",
            isOncePerDay: true,
            tier: .habit
        ),
        QuestDefinition(
            id: "DAILY_HB_GREEN_BAR",
            type: .daily,
            category: .healthBar,
            difficulty: .medium,
            xpReward: 30,
            title: "Green HealthBar",
            subtitle: "Have mood ≥ neutral, sleep ≥ threshold, hydration ≥ 50%.",
            isOncePerDay: true,
            tier: .habit
        ),
        QuestDefinition(
            id: "DAILY_META_SETUP_COMPLETE",
            type: .daily,
            category: .meta,
            difficulty: .easy,
            xpReward: 20,
            title: "Daily Setup Complete",
            subtitle: "Finish the Daily Setup flow (sleep + mood + hydration).",
            isOncePerDay: true,
            tier: .core
        ),
        QuestDefinition(
            id: "DAILY_META_CHOOSE_FOCUS",
            type: .daily,
            category: .meta,
            difficulty: .easy,
            xpReward: 15,
            title: "Choose Today’s Main Quest",
            subtitle: "Set today’s focus area (Work/Self-Care/Chill/Grind).",
            isOncePerDay: true,
            tier: .core
        ),
        QuestDefinition(
            id: "DAILY_META_PLAYER_CARD",
            type: .daily,
            category: .meta,
            difficulty: .easy,
            xpReward: 15,
            title: "Player Card Check-In",
            subtitle: "Open the Player Card screen.",
            isOncePerDay: true,
            tier: .core
        ),
        QuestDefinition(
            id: "DAILY_META_STATS_TODAY",
            type: .daily,
            category: .meta,
            difficulty: .easy,
            xpReward: 15,
            title: "Peek at the Numbers",
            subtitle: "Open Stats for Today.",
            isOncePerDay: true,
            tier: .core
        ),
        QuestDefinition(
            id: "DAILY_META_ADJUST_GOALS",
            type: .daily,
            category: .meta,
            difficulty: .medium,
            xpReward: 25,
            title: "Adjust Your Goals",
            subtitle: "Change ≥ 1 daily goal slider.",
            isOncePerDay: true,
            tier: .habit,
            completionMode: .manualDebug
        ),
        QuestDefinition(
            id: "DAILY_META_REVIEW_YESTERDAY",
            type: .daily,
            category: .meta,
            difficulty: .medium,
            xpReward: 25,
            title: "Review Yesterday’s Run",
            subtitle: "Open Stats and view yesterday.",
            isOncePerDay: true,
            tier: .habit
        ),
        QuestDefinition(
            id: "DAILY_EASY_TINY_TIDY",
            type: .daily,
            category: .easyWin,
            difficulty: .easy,
            xpReward: 15,
            title: "Tiny Tidy",
            subtitle: "Complete a Chores timer for 3+ minutes.",
            isOncePerDay: true,
            tier: .bonus
        ),
        QuestDefinition(
            id: "DAILY_EASY_ONE_NICE_THING",
            type: .daily,
            category: .easyWin,
            difficulty: .easy,
            xpReward: 15,
            title: "One Nice Thing",
            subtitle: "Complete any timer for 5+ minutes.",
            isOncePerDay: true,
            tier: .bonus
        ),
        QuestDefinition(
            id: "DAILY_EASY_HYDRATION_SIP",
            type: .daily,
            category: .easyWin,
            difficulty: .easy,
            xpReward: 15,
            title: "Hydration Sip",
            subtitle: "Log ≥ 100 ml of hydration.",
            isOncePerDay: true,
            tier: .bonus
        ),
        QuestDefinition(
            id: "DAILY_EASY_FIRST_QUEST",
            type: .daily,
            category: .easyWin,
            difficulty: .easy,
            xpReward: 15,
            title: "First Quest of the Day",
            subtitle: "Complete your first quest today.",
            isOncePerDay: true,
            tier: .bonus
        ),
        QuestDefinition(
            id: "DAILY_EASY_TWO_CHAIN",
            type: .daily,
            category: .easyWin,
            difficulty: .easy,
            xpReward: 20,
            title: "Two-Quest Chain",
            subtitle: "Complete 2 quests within a short window.",
            isOncePerDay: true,
            tier: .bonus
        ),
        QuestDefinition(
            id: "DAILY_EASY_OPEN_GATES",
            type: .daily,
            category: .easyWin,
            difficulty: .easy,
            xpReward: 20,
            title: "Open the Gates",
            subtitle: "Open the app after 20 hours away.",
            isOncePerDay: true,
            tier: .bonus
        )
    ]

    static let legacyDailyQuests: [QuestDefinition] = [
        QuestDefinition(
            id: "daily-checkin",
            type: .daily,
            category: .meta,
            difficulty: .tiny,
            xpReward: 10,
            title: "Load today’s quest log",
            subtitle: "Open the quest log and decide what actually matters.",
            isOncePerDay: true,
            tier: .core
        ),
        QuestDefinition(
            id: "plan-focus-session",
            type: .daily,
            category: .timer,
            difficulty: .medium,
            xpReward: 35,
            title: "Plan one focus session",
            subtitle: "Start a focus timer that runs for at least 15 minutes today.",
            isOncePerDay: true,
            tier: .core
        ),
        QuestDefinition(
            id: "healthbar-checkin",
            type: .daily,
            category: .healthBar,
            difficulty: .medium,
            xpReward: 35,
            title: "HealthBar check-in",
            subtitle: "Update your mood, gut, and sleep before you go heads-down.",
            isOncePerDay: true,
            tier: .core
        ),
        QuestDefinition(
            id: "chore-blitz",
            type: .daily,
            category: .timer,
            difficulty: .medium,
            xpReward: 35,
            title: "Chore blitz",
            subtitle: "Run a Chores timer for at least 10 minutes to clear a small dungeon.",
            isOncePerDay: true,
            tier: .core
        ),
        QuestDefinition(
            id: "finish-focus-session",
            type: .daily,
            category: .timer,
            difficulty: .medium,
            xpReward: 35,
            title: "Finish one focus session",
            subtitle: "Complete a focus timer that lasts 25 minutes or longer.",
            isOncePerDay: true,
            tier: .habit
        ),
        QuestDefinition(
            id: "focus-25-min",
            type: .daily,
            category: .timer,
            difficulty: .big,
            xpReward: 60,
            title: "Hit 25 focus minutes today",
            subtitle: "Accumulate at least 25 minutes of focus time.",
            isOncePerDay: true,
            tier: .bonus
        ),
        QuestDefinition(
            id: "hydrate-checkpoint",
            type: .daily,
            category: .healthBar,
            difficulty: .small,
            xpReward: 20,
            title: "Hydrate checkpoint",
            subtitle: "Drink at least 16 oz of water before a session starts.",
            isOncePerDay: true,
            tier: .habit
        ),
        QuestDefinition(
            id: "hydration-goal",
            type: .daily,
            category: .healthBar,
            difficulty: .big,
            xpReward: 60,
            title: "Hit your hydration goal today",
            subtitle: "Stay on top of water throughout the day.",
            isOncePerDay: true,
            tier: .bonus
        ),
        QuestDefinition(
            id: "irl-patch",
            type: .daily,
            category: .healthBar,
            difficulty: .small,
            xpReward: 20,
            title: "IRL patch update",
            subtitle: "Stretch for 2 minutes and do a posture check.",
            isOncePerDay: true,
            tier: .habit
        ),
        QuestDefinition(
            id: "tidy-spot",
            type: .daily,
            category: .easyWin,
            difficulty: .small,
            xpReward: 20,
            title: "Tidy one small area",
            subtitle: "Reset your desk, sink, or a small zone.",
            isOncePerDay: true,
            tier: .habit
        ),
        QuestDefinition(
            id: "step-outside",
            type: .daily,
            category: .easyWin,
            difficulty: .small,
            xpReward: 20,
            title: "Step outside or change rooms",
            subtitle: "Move your body and reset your head for a few minutes.",
            isOncePerDay: true,
            tier: .habit
        ),
        QuestDefinition(
            id: "quick-self-care",
            type: .daily,
            category: .easyWin,
            difficulty: .small,
            xpReward: 20,
            title: "Do one quick self-care check",
            subtitle: "Breathe, sip water, or take a bathroom break.",
            isOncePerDay: true,
            tier: .habit
        )
    ]

    static let legacyWeeklyQuests: [QuestDefinition] = [
        QuestDefinition(
            id: "weekly-focus-marathon",
            type: .weekly,
            category: .timer,
            difficulty: .hard,
            xpReward: 100,
            title: "Weekly focus marathon",
            subtitle: "Hit 120 focus minutes this week.",
            isOncePerDay: false,
            tier: .bonus
        ),
        QuestDefinition(
            id: "weekly-session-grinder",
            type: .weekly,
            category: .timer,
            difficulty: .hard,
            xpReward: 100,
            title: "Session grinder",
            subtitle: "Complete 15 focus sessions this week.",
            isOncePerDay: false,
            tier: .bonus
        ),
        QuestDefinition(
            id: "weekly-daily-quest-slayer",
            type: .weekly,
            category: .meta,
            difficulty: .medium,
            xpReward: 60,
            title: "Daily quest slayer",
            subtitle: "Complete 20 daily quests this week.",
            isOncePerDay: false,
            tier: .habit
        ),
        QuestDefinition(
            id: "weekly-health-check",
            type: .weekly,
            category: .healthBar,
            difficulty: .medium,
            xpReward: 60,
            title: "Health check-in",
            subtitle: "Log mood, gut, and sleep on 4 days this week.",
            isOncePerDay: false,
            tier: .habit
        ),
        QuestDefinition(
            id: "weekly-hydration-hero",
            type: .weekly,
            category: .healthBar,
            difficulty: .medium,
            xpReward: 60,
            title: "Hydration hero",
            subtitle: "Hit your hydration goal on 4 days this week.",
            isOncePerDay: false,
            tier: .habit
        ),
        QuestDefinition(
            id: "weekly-digital-dust",
            type: .weekly,
            category: .meta,
            difficulty: .medium,
            xpReward: 60,
            title: "Digital dust buster",
            subtitle: "Clear a digital cobweb on 3 days this week.",
            isOncePerDay: false,
            tier: .habit,
            completionMode: .manualDebug
        )
    ]

    static let expandedWeeklyQuests: [QuestDefinition] = [
        QuestDefinition(
            id: "WEEK_WORK_WARRIOR",
            type: .weekly,
            category: .timer,
            difficulty: .medium,
            xpReward: 120,
            title: "Work Week Warrior",
            subtitle: "Complete 5 Work timers of 25+ minutes this week.",
            isOncePerDay: false,
            tier: .bonus
        ),
        QuestDefinition(
            id: "WEEK_DEEP_WORK",
            type: .weekly,
            category: .timer,
            difficulty: .hard,
            xpReward: 200,
            title: "Deep Work Week",
            subtitle: "Accumulate 200+ Work minutes this week.",
            isOncePerDay: false,
            tier: .bonus
        ),
        QuestDefinition(
            id: "WEEK_CLUTTER_CRUSHER",
            type: .weekly,
            category: .timer,
            difficulty: .medium,
            xpReward: 120,
            title: "Clutter Crusher",
            subtitle: "Accumulate 90+ Chores minutes this week.",
            isOncePerDay: false,
            tier: .bonus
        ),
        QuestDefinition(
            id: "WEEK_SELFCARE_CHAMPION",
            type: .weekly,
            category: .timer,
            difficulty: .medium,
            xpReward: 120,
            title: "Self-Care Champion",
            subtitle: "Complete 4 Self-Care timers of 15+ minutes on different days.",
            isOncePerDay: false,
            tier: .bonus
        ),
        QuestDefinition(
            id: "WEEK_EVENING_RESET",
            type: .weekly,
            category: .timer,
            difficulty: .medium,
            xpReward: 120,
            title: "Evening Reset Ritual",
            subtitle: "On 3 days, complete a Chores/Self-Care timer 15+ minutes after 6pm.",
            isOncePerDay: false,
            tier: .bonus
        ),
        QuestDefinition(
            id: "WEEK_HYDRATION_HERO_PLUS",
            type: .weekly,
            category: .healthBar,
            difficulty: .medium,
            xpReward: 120,
            title: "Hydration Hero Week",
            subtitle: "Hit your hydration goal on 4 days.",
            isOncePerDay: false,
            tier: .habit
        ),
        QuestDefinition(
            id: "WEEK_HYDRATION_DEMON",
            type: .weekly,
            category: .healthBar,
            difficulty: .hard,
            xpReward: 200,
            title: "Hydration Demon Week",
            subtitle: "Hit hydration goal on 6+ days.",
            isOncePerDay: false,
            tier: .bonus
        ),
        QuestDefinition(
            id: "WEEK_MOOD_TRACKER",
            type: .weekly,
            category: .healthBar,
            difficulty: .medium,
            xpReward: 120,
            title: "Mood Tracker",
            subtitle: "Log mood on 5 days.",
            isOncePerDay: false,
            tier: .habit
        ),
        QuestDefinition(
            id: "WEEK_SLEEP_SENTINEL",
            type: .weekly,
            category: .healthBar,
            difficulty: .medium,
            xpReward: 120,
            title: "Sleep Sentinel",
            subtitle: "Log sleep on 5 days.",
            isOncePerDay: false,
            tier: .habit
        ),
        QuestDefinition(
            id: "WEEK_BALANCED_BAR",
            type: .weekly,
            category: .healthBar,
            difficulty: .medium,
            xpReward: 140,
            title: "Balanced Bar",
            subtitle: "On 3 days, keep mood, sleep, and hydration above thresholds.",
            isOncePerDay: false,
            tier: .habit
        ),
        QuestDefinition(
            id: "WEEK_DAILY_SETUP_STREAK",
            type: .weekly,
            category: .meta,
            difficulty: .medium,
            xpReward: 140,
            title: "Daily Setup Streak",
            subtitle: "Complete Daily Setup on 5 days.",
            isOncePerDay: false,
            tier: .habit
        ),
        QuestDefinition(
            id: "WEEK_QUEST_FINISHER",
            type: .weekly,
            category: .meta,
            difficulty: .medium,
            xpReward: 120,
            title: "Quest Finisher",
            subtitle: "Complete 20+ daily quests this week.",
            isOncePerDay: false,
            tier: .habit
        ),
        QuestDefinition(
            id: "WEEK_MINI_BOSS",
            type: .weekly,
            category: .meta,
            difficulty: .hard,
            xpReward: 200,
            title: "Mini-Boss Week",
            subtitle: "Finish 3+ Hard difficulty quests.",
            isOncePerDay: false,
            tier: .bonus
        ),
        QuestDefinition(
            id: "WEEK_THREE_GOOD_DAYS",
            type: .weekly,
            category: .meta,
            difficulty: .medium,
            xpReward: 140,
            title: "Three Good Days",
            subtitle: "Have 3 days with 4+ quests completed.",
            isOncePerDay: false,
            tier: .habit
        ),
        QuestDefinition(
            id: "WEEK_WEEKEND_WARRIOR",
            type: .weekly,
            category: .meta,
            difficulty: .medium,
            xpReward: 140,
            title: "Weekend Warrior",
            subtitle: "On Sat/Sun, complete 2 quests and 1 timer 20+ minutes.",
            isOncePerDay: false,
            tier: .habit
        )
    ]

    static var allDailyQuests: [QuestDefinition] { expandedDailyQuests + legacyDailyQuests }
    static var allWeeklyQuests: [QuestDefinition] { expandedWeeklyQuests + legacyWeeklyQuests }
}
