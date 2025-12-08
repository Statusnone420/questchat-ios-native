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
    private let userDefaults: UserDefaults
    private let onCompletion: (() -> Void)?

    init(
        hydrationSettingsStore: HydrationSettingsStore,
        dailyRatingsStore: DailyHealthRatingsStore,
        healthBarViewModel: HealthBarViewModel,
        focusViewModel: FocusViewModel,
        userDefaults: UserDefaults = .standard,
        onCompletion: (() -> Void)? = nil
    ) {
        self.hydrationSettingsStore = hydrationSettingsStore
        self.dailyRatingsStore = dailyRatingsStore
        self.healthBarViewModel = healthBarViewModel
        self.focusViewModel = focusViewModel
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

        hasCompletedOnboarding = true
        userDefaults.set(true, forKey: Keys.hasCompletedOnboarding)
        onCompletion?()
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
