import Foundation
import Combine

final class OnboardingViewModel: ObservableObject {
    enum OnboardingStep {
        case welcome
        case name
        case hydration
        case dailyVitals
        case howItWorks
    }

    enum Keys {
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
        static let playerDisplayName = "playerDisplayName"
    }

    @Published var currentStep: OnboardingStep = .welcome
    @Published var playerName: String
    @Published var selectedHydrationGoalCups: Int
    @Published private(set) var hasCompletedOnboarding: Bool

    let hydrationSettingsStore: HydrationSettingsStore
    let dailyRatingsStore: DailyHealthRatingsStore
    let healthBarViewModel: HealthBarViewModel
    let focusViewModel: FocusViewModel
    let playerStateStore: PlayerStateStore
    private let userDefaults: UserDefaults
    private let onCompletion: (() -> Void)?

    init(
        hydrationSettingsStore: HydrationSettingsStore,
        dailyRatingsStore: DailyHealthRatingsStore,
        healthBarViewModel: HealthBarViewModel,
        focusViewModel: FocusViewModel,
        playerStateStore: PlayerStateStore,
        userDefaults: UserDefaults = .standard,
        onCompletion: (() -> Void)? = nil
    ) {
        self.hydrationSettingsStore = hydrationSettingsStore
        self.dailyRatingsStore = dailyRatingsStore
        self.healthBarViewModel = healthBarViewModel
        self.focusViewModel = focusViewModel
        self.playerStateStore = playerStateStore
        self.userDefaults = userDefaults
        self.onCompletion = onCompletion

        let storedName = userDefaults.string(forKey: Keys.playerDisplayName) ?? QuestChatStrings.PlayerCard.defaultName
        playerName = storedName

        let storedGoal = hydrationSettingsStore.dailyWaterGoalOunces
        if storedGoal > 0 {
            selectedHydrationGoalCups = max(1, storedGoal / 8)
        } else {
            selectedHydrationGoalCups = 8
        }
        hasCompletedOnboarding = userDefaults.bool(forKey: Keys.hasCompletedOnboarding)
    }

    func goToNextStep() {
        switch currentStep {
        case .welcome:
            currentStep = .name
        case .name:
            currentStep = .hydration
        case .hydration:
            currentStep = .dailyVitals
        case .dailyVitals:
            currentStep = .howItWorks
        case .howItWorks:
            completeOnboarding()
        }
    }

    func completeDailyVitalsStep() {
        seedDailyVitalsIfNeeded()
        currentStep = .howItWorks
    }

    func skip() {
        hasCompletedOnboarding = true
        userDefaults.set(true, forKey: Keys.hasCompletedOnboarding)
        onCompletion?()
    }

    func completeOnboarding() {
        userDefaults.set(playerName.isEmpty ? QuestChatStrings.PlayerCard.defaultName : playerName, forKey: Keys.playerDisplayName)
        hydrationSettingsStore.dailyWaterGoalOunces = selectedHydrationGoalCups * 8

        seedDailyVitalsIfNeeded()

        // Mark onboarding as complete FIRST, before granting XP
        hasCompletedOnboarding = true
        userDefaults.set(true, forKey: Keys.hasCompletedOnboarding)
        
        // Manually trigger quest completion for vitals set during onboarding
        // This ensures quests complete even if vitals were set before bindings fired
        triggerVitalsQuestCompletion()
        
        // Grant welcome bonus XP after onboarding is marked complete
        // This ensures quest checks and level-up modals work properly
        grantWelcomeBonusXP()
        
        onCompletion?()
    }
    
    /// Grant XP for completing onboarding setup.
    /// This triggers after onboarding is marked complete, so quest checks and modals work.
    private func grantWelcomeBonusXP() {
        // Award 100 XP as a "getting started" bonus
        // This typically brings a new player to level 2 (0 → 100 XP → level 2)
        playerStateStore.grantQuestXP(amount: 100)
    }
    
    /// Manually trigger quest completion for vitals that were set during onboarding.
    /// This ensures quests complete even if values were set/changed during onboarding
    /// without going through the PlayerCardView bindings.
    private func triggerVitalsQuestCompletion() {
        let ratings = dailyRatingsStore.ratings()
        
        // Complete individual vitals quests if values are set
        if ratings.mood != nil {
            DependencyContainer.shared.questsViewModel.completeQuestIfNeeded(id: "DAILY_HB_MORNING_CHECKIN")
        }
        if ratings.gut != nil {
            DependencyContainer.shared.questsViewModel.completeQuestIfNeeded(id: "DAILY_HB_GUT_CHECK")
        }
        if ratings.sleep != nil {
            DependencyContainer.shared.questsViewModel.completeQuestIfNeeded(id: "DAILY_HB_SLEEP_LOG")
        }
        
        // If all three core vitals are set, trigger the HP checkin completed event
        if ratings.mood != nil && ratings.gut != nil && ratings.sleep != nil {
            DependencyContainer.shared.questsViewModel.handleQuestEvent(.hpCheckinCompleted)
        }
    }

    func seedDailyVitalsIfNeeded(defaultRating: Int = 3) {
        let ratings = dailyRatingsStore.ratings()

        if ratings.mood == nil {
            setMoodRating(defaultRating)
        }

        if ratings.gut == nil {
            setGutRating(defaultRating)
        }

        if ratings.sleep == nil {
            setSleepRating(defaultRating)
        }

        if ratings.activity == nil {
            setActivityRating(defaultRating)
        }
    }

    private func setMoodRating(_ rating: Int?) {
        dailyRatingsStore.setMood(rating)
        let status = HealthRatingMapper.moodStatus(for: rating)
        healthBarViewModel.setMoodStatus(status)
    }

    private func setGutRating(_ rating: Int?) {
        dailyRatingsStore.setGut(rating)
        let status = HealthRatingMapper.gutStatus(for: rating)
        healthBarViewModel.setGutStatus(status)
    }

    private func setSleepRating(_ rating: Int?) {
        dailyRatingsStore.setSleep(rating)
        focusViewModel.sleepQuality = HealthRatingMapper.sleepQuality(for: rating ?? defaultSleepRating) ?? .okay
    }

    private func setActivityRating(_ rating: Int?) {
        dailyRatingsStore.setActivity(rating)
        focusViewModel.activityLevel = HealthRatingMapper.activityLevel(for: rating)
    }

    private var defaultSleepRating: Int { 3 }
}
