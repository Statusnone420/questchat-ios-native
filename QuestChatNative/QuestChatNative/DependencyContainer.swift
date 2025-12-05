import Foundation
import SwiftUI

final class DependencyContainer {
    static let shared = DependencyContainer()

    let playerTitleStore: PlayerTitleStore
    let playerStateStore: PlayerStateStore
    let sessionStatsStore: SessionStatsStore
    let healthStatsStore: HealthBarIRLStatsStore
    let hydrationSettingsStore: HydrationSettingsStore
    let reminderSettingsStore: ReminderSettingsStore
    let reminderEventsStore: ReminderEventsStore
    let sleepHistoryStore: SleepHistoryStore
    let seasonAchievementsStore: SeasonAchievementsStore
    let questEngine: QuestEngine

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
        reminderSettingsStore = ReminderSettingsStore()
        reminderEventsStore = ReminderEventsStore()
        sleepHistoryStore = SleepHistoryStore()
        seasonAchievementsStore = SeasonAchievementsStore()
        questEngine = QuestEngine()

        // View models that depend on stores
        healthBarViewModel = HealthBarViewModel(
            statsStore: healthStatsStore,
            sessionStatsStore: sessionStatsStore,
            hydrationSettingsStore: hydrationSettingsStore,
            sleepHistoryStore: sleepHistoryStore
        )
        focusViewModel = FocusViewModel(
            statsStore: sessionStatsStore,
            playerStateStore: playerStateStore,
            playerTitleStore: playerTitleStore,
            healthStatsStore: healthStatsStore,
            healthBarViewModel: healthBarViewModel,
            hydrationSettingsStore: hydrationSettingsStore,
            reminderSettingsStore: reminderSettingsStore,
            reminderEventsStore: reminderEventsStore,
            seasonAchievementsStore: seasonAchievementsStore,
            sleepHistoryStore: sleepHistoryStore
        )
        questsViewModel = QuestsViewModel(statsStore: sessionStatsStore, questEngine: questEngine)
        statsViewModel = StatsViewModel(
            healthStore: healthStatsStore,
            hydrationSettingsStore: hydrationSettingsStore,
            seasonAchievementsStore: seasonAchievementsStore,
            playerTitleStore: playerTitleStore,
            statsStore: sessionStatsStore,
            sleepHistoryStore: sleepHistoryStore
        )
        moreViewModel = MoreViewModel(
            hydrationSettingsStore: hydrationSettingsStore,
            reminderSettingsStore: reminderSettingsStore
        )

        let resetter = GameDataResetter(
            healthStatsStore: healthStatsStore,
            xpStore: sessionStatsStore,
            sessionStatsStore: sessionStatsStore
        )
        settingsViewModel = SettingsViewModel(resetter: resetter)
    }

    func makeOnboardingViewModel(onCompletion: (() -> Void)? = nil) -> OnboardingViewModel {
        OnboardingViewModel(
            hydrationSettingsStore: hydrationSettingsStore,
            healthBarViewModel: healthBarViewModel,
            focusViewModel: focusViewModel,
            onCompletion: onCompletion
        )
    }

    func makeHealthBarViewModel() -> HealthBarViewModel {
        healthBarViewModel
    }

    func makeHealthBarView() -> HealthBarView {
        HealthBarView(
            viewModel: makeHealthBarViewModel(),
            focusViewModel: focusViewModel,
            selectedTab: .constant(.health)
        )
    }
}

