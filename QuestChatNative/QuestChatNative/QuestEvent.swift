import Foundation

enum QuestEvent {
    case questsTabOpened
    case focusSessionStarted(durationMinutes: Int)
    case focusSessionCompleted(durationMinutes: Int)
    case timerCompleted(category: TimerCategory.Kind, durationMinutes: Int, endedAt: Date)
    case focusMinutesUpdated(totalMinutesToday: Int)
    case focusSessionsUpdated(totalSessionsToday: Int)
    case choresTimerCompleted(durationMinutes: Int)
    case hpCheckinCompleted
    case hydrationIntakeLogged(totalOuncesToday: Int)
    case hydrationGoalReached
    case hydrationGoalDayCompleted
    case dailySetupCompleted
}
