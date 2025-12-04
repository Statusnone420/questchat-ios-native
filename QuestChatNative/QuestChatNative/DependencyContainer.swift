import Foundation

final class DependencyContainer {
    static let shared = DependencyContainer()

    let playerStateStore: PlayerStateStore
    let sessionStatsStore: SessionStatsStore
    let healthStatsStore: HealthBarIRLStatsStore
    let hydrationSettingsStore: HydrationSettingsStore

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

        // View models that depend on stores
        healthBarViewModel = HealthBarViewModel()
        focusViewModel = FocusViewModel(
            statsStore: sessionStatsStore,
            playerStateStore: playerStateStore,
            healthStatsStore: healthStatsStore,
            healthBarViewModel: healthBarViewModel,
            hydrationSettingsStore: hydrationSettingsStore
        )
        questsViewModel = QuestsViewModel(statsStore: sessionStatsStore)
        statsViewModel = StatsViewModel(
            healthStore: healthStatsStore,
            hydrationSettingsStore: hydrationSettingsStore
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
