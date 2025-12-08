import Foundation

enum HealthTrackingStorageKeys {
    // Deprecated for today's values — DailyHealthRatingsStore is now the single source of truth. Kept for historical reads (e.g., yesterday).
    static let sleepQualityValue = "sleepQualityValue"
    static let sleepQualityDate = "sleepQualityDate"
    static let sleepQualityLogged = "sleepQualityLogged"

    // Deprecated for today's values — use DailyHealthRatingsStore instead.
    static let activityLevelValue = "activityLevelValue"
    static let activityLevelDate = "activityLevelDate"
    static let activityLevelLogged = "activityLevelLogged"

    static let waterGoalAwardDate = "waterGoalAwardDate"
    static let healthComboAwardDate = "healthComboAwardDate"
    static let hpCheckinQuestDate = "hpCheckinQuestDate"
    static let hydrationGoalQuestDate = "hydrationGoalQuestDate"
}
