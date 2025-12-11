import Foundation
import SwiftUI
import Combine

final class DependencyContainer {
    static let shared = DependencyContainer()

    let playerTitleStore: PlayerTitleStore
    let playerStateStore: PlayerStateStore
    let sessionStatsStore: SessionStatsStore
    let healthStatsStore: HealthBarIRLStatsStore
    let hydrationSettingsStore: HydrationSettingsStore
    let reminderSettingsStore: ReminderSettingsStore
    let reminderEventsStore: ReminderEventsStore
    let hydrationReminderManager: HydrationReminderManager
    let sleepHistoryStore: SleepHistoryStore
    let activityHistoryStore: ActivityHistoryStore
    let dailyHealthRatingsStore: DailyHealthRatingsStore
    let seasonAchievementsStore: SeasonAchievementsStore
    let talentTreeStore: TalentTreeStore
    let questEngine: QuestEngine
    let potionManager: PotionManager

    let focusViewModel: FocusViewModel
    let healthBarViewModel: HealthBarViewModel
    let questsViewModel: QuestsViewModel
    let statsViewModel: StatsViewModel
    let moreViewModel: MoreViewModel
    let settingsViewModel: SettingsViewModel

    private var cancellables = Set<AnyCancellable>()

    private init() {
        // Core stores
        playerTitleStore = PlayerTitleStore()
        playerStateStore = PlayerStateStore()
        talentTreeStore = TalentTreeStore()
        sessionStatsStore = SessionStatsStore(
            playerStateStore: playerStateStore,
            playerTitleStore: playerTitleStore,
            talentTreeStore: talentTreeStore
        )
        healthStatsStore = HealthBarIRLStatsStore()
        hydrationSettingsStore = HydrationSettingsStore()
        reminderSettingsStore = ReminderSettingsStore()
        reminderEventsStore = ReminderEventsStore()
        hydrationReminderManager = HydrationReminderManager(reminderSettingsStore: reminderSettingsStore)
        sleepHistoryStore = SleepHistoryStore()
        activityHistoryStore = ActivityHistoryStore()
        dailyHealthRatingsStore = DailyHealthRatingsStore()
        seasonAchievementsStore = SeasonAchievementsStore()
        questEngine = QuestEngine()
        potionManager = PotionManager.shared
        potionManager.start()

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
            hydrationReminderManager: hydrationReminderManager,
            hydrationSettingsStore: hydrationSettingsStore,
            reminderSettingsStore: reminderSettingsStore,
            reminderEventsStore: reminderEventsStore,
            seasonAchievementsStore: seasonAchievementsStore,
            sleepHistoryStore: sleepHistoryStore,
            activityHistoryStore: activityHistoryStore
        )
        questsViewModel = QuestsViewModel(statsStore: sessionStatsStore, questEngine: questEngine)
        statsViewModel = StatsViewModel(
            healthStore: healthStatsStore,
            hydrationSettingsStore: hydrationSettingsStore,
            seasonAchievementsStore: seasonAchievementsStore,
            playerTitleStore: playerTitleStore,
            statsStore: sessionStatsStore,
            sleepHistoryStore: sleepHistoryStore,
            dailyRatingsStore: dailyHealthRatingsStore
        )
        moreViewModel = MoreViewModel(
            hydrationSettingsStore: hydrationSettingsStore,
            reminderSettingsStore: reminderSettingsStore
        )

        let resetter = GameDataResetter(
            healthStatsStore: healthStatsStore,
            xpStore: sessionStatsStore,
            sessionStatsStore: sessionStatsStore,
            dailyHealthRatingsStore: dailyHealthRatingsStore
        )
        settingsViewModel = SettingsViewModel(resetter: resetter)

        // Bind after all properties are initialized
        bindTalentTreeAchievements()
        bindSeasonAchievementXPRewards()
    }

    func makeOnboardingViewModel(onCompletion: (() -> Void)? = nil) -> OnboardingViewModel {
        OnboardingViewModel(
            hydrationSettingsStore: hydrationSettingsStore,
            dailyRatingsStore: dailyHealthRatingsStore,
            healthBarViewModel: healthBarViewModel,
            focusViewModel: focusViewModel,
            playerStateStore: playerStateStore,
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
            statsStore: sessionStatsStore,
            statsViewModel: statsViewModel,
            selectedTab: .constant(.health)
        )
    }

    func makeDailyHealthRatingsStore() -> DailyHealthRatingsStore {
        dailyHealthRatingsStore
    }

    func makeTalentsViewModel() -> TalentsViewModel {
        TalentsViewModel(store: talentTreeStore, statsStore: sessionStatsStore)
    }

    private func bindTalentTreeAchievements() {
        talentTreeStore.$currentRanks
            .combineLatest(talentTreeStore.$nodes)
            .sink { [weak self] ranks, nodes in
                guard let self else { return }
                guard !nodes.isEmpty else { return }

                let allUnlocked = nodes.allSatisfy { (ranks[$0.id] ?? 0) > 0 }
                if allUnlocked {
                    seasonAchievementsStore.applyProgress(conditionType: .allTalentsUnlocked, amount: 1)
                }
            }
            .store(in: &cancellables)
    }
    
    private func bindSeasonAchievementXPRewards() {
        print("[DependencyContainer] 🔌 Subscribing to season achievement unlocks via SessionStatsStore...")
        NotificationCenter.default.publisher(for: .seasonAchievementUnlocked, object: seasonAchievementsStore)
            .compactMap { [weak self] notification -> SeasonAchievement? in
                guard let self else { return nil }
                print("[DependencyContainer] 📢 Received season achievement unlock notification")
                guard
                    let achievementId = notification.userInfo?["achievementId"] as? String,
                    let achievement = self.seasonAchievementsStore.achievements.first(where: { $0.id == achievementId })
                else {
                    print("[DependencyContainer] ⚠️ Could not find achievement in notification")
                    return nil
                }
                print("[DependencyContainer] ✅ Found achievement: \(achievement.title) (\(achievement.xpReward) XP)")
                return achievement
            }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] achievement in
                guard let self else { return }
                let xpBefore = self.sessionStatsStore.xp
                let levelBefore = self.sessionStatsStore.level
                print("[DependencyContainer] 🎁 Granting \(achievement.xpReward) XP via SessionStatsStore")
                print("[DependencyContainer]    Before: XP=\(xpBefore), Level=\(levelBefore)")
                
                self.sessionStatsStore.grantXP(
                    achievement.xpReward,
                    reason: .seasonAchievement(id: achievement.id, xp: achievement.xpReward)
                )
                
                let xpAfter = self.sessionStatsStore.xp
                let levelAfter = self.sessionStatsStore.level
                print("[DependencyContainer]    After: XP=\(xpAfter), Level=\(levelAfter)")
                if levelAfter > levelBefore {
                    print("[DependencyContainer]    🎉 LEVEL UP! \(levelBefore) → \(levelAfter)")
                }
            }
            .store(in: &cancellables)
        print("[DependencyContainer] ✅ Season achievement XP subscription established!")
    }
}
