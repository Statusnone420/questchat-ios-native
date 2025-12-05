import Foundation

final class DependencyContainer {
    static let shared = DependencyContainer()

    let playerTitleStore: PlayerTitleStore
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
        playerTitleStore = PlayerTitleStore()
        playerStateStore = PlayerStateStore()
        sessionStatsStore = SessionStatsStore(playerStateStore: playerStateStore, playerTitleStore: playerTitleStore)
        healthStatsStore = HealthBarIRLStatsStore()
        hydrationSettingsStore = HydrationSettingsStore()
        seasonAchievementsStore = SeasonAchievementsStore()

        // View models that depend on stores
        healthBarViewModel = HealthBarViewModel()
        focusViewModel = FocusViewModel(
            statsStore: sessionStatsStore,
            playerStateStore: playerStateStore,
            playerTitleStore: playerTitleStore,
            healthStatsStore: healthStatsStore,
            healthBarViewModel: healthBarViewModel,
            hydrationSettingsStore: hydrationSettingsStore,
            seasonAchievementsStore: seasonAchievementsStore
        )
        questsViewModel = QuestsViewModel(statsStore: sessionStatsStore)
        statsViewModel = StatsViewModel(
            healthStore: healthStatsStore,
            hydrationSettingsStore: hydrationSettingsStore,
            seasonAchievementsStore: seasonAchievementsStore,
            playerTitleStore: playerTitleStore,
            statsStore: sessionStatsStore
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

