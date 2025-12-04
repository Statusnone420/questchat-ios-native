import Foundation

final class DependencyContainer {
    static let shared = DependencyContainer()

    let playerStateStore: PlayerStateStore
    let sessionStatsStore: SessionStatsStore
    let healthStatsStore: HealthBarIRLStatsStore
    let hydrationSettingsStore: HydrationSettingsStore
    let seasonAchievementsStore: SeasonAchievementsStore

    let focusViewModel: FocusViewModel
    let healthBarViewModel: HealthBarViewModel
    let questsViewModel: QuestsViewModel
    let statsViewModel: StatsViewModel
    let moreViewModel: MoreViewModel
    let settingsViewModel: SettingsViewModel

    private init() {
        // Core stores
        playerStateStore = PlayerStateStore()
        sessionStatsStore = SessionStatsStore(playerStateStore: playerStateStore)
        healthStatsStore = HealthBarIRLStatsStore()
        hydrationSettingsStore = HydrationSettingsStore()
        seasonAchievementsStore = SeasonAchievementsStore()

        // View models that depend on stores
        healthBarViewModel = HealthBarViewModel()
        focusViewModel = FocusViewModel(
            statsStore: sessionStatsStore,
            playerStateStore: playerStateStore,
            healthStatsStore: healthStatsStore,
            healthBarViewModel: healthBarViewModel,
            hydrationSettingsStore: hydrationSettingsStore,
            seasonAchievementsStore: seasonAchievementsStore
        )
        questsViewModel = QuestsViewModel(statsStore: sessionStatsStore)
        statsViewModel = StatsViewModel(
            healthStore: healthStatsStore,
            hydrationSettingsStore: hydrationSettingsStore,
            seasonAchievementsStore: seasonAchievementsStore
        )
        moreViewModel = MoreViewModel(hydrationSettingsStore: hydrationSettingsStore)

        let resetter = GameDataResetter(
            healthStatsStore: healthStatsStore,
            xpStore: sessionStatsStore,
            sessionStatsStore: sessionStatsStore
        )
        settingsViewModel = SettingsViewModel(resetter: resetter)
    }
}
