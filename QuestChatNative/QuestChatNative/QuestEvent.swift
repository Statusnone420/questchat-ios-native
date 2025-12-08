import Foundation

enum StatsScope: Hashable {
    case today
    case yesterday
}

enum QuestEvent {
    case questsTabOpened
    case focusSessionStarted(durationMinutes: Int)
    case focusSessionCompleted(durationMinutes: Int)
    case timerCompleted(category: TimerCategory.Kind, durationMinutes: Int, endedAt: Date)
    case focusMinutesUpdated(totalMinutesToday: Int)
    case focusSessionsUpdated(totalSessionsToday: Int)
    case choresTimerCompleted(durationMinutes: Int)
    case hpCheckinCompleted
    case hydrationLogged(amountMl: Int, totalMlToday: Int, percentOfGoal: Double)
    case hydrationGoalReached
    case hydrationGoalDayCompleted
    case dailySetupCompleted
    case statsViewed(scope: StatsScope)
    case hydrationReminderFired
    case postureReminderFired
    case playerCardViewed
}
