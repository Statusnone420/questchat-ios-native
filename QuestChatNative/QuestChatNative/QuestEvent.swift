import Foundation

enum QuestEvent {
    case questsTabOpened
    case focusSessionStarted(durationMinutes: Int)
    case focusSessionCompleted(durationMinutes: Int)
    case choresTimerCompleted(durationMinutes: Int)
    case hpCheckinCompleted
    case hydrationIntakeLogged(totalOuncesToday: Int)
    case hydrationGoalReached
}
