import Foundation
import Combine

final class OnboardingViewModel: ObservableObject {
    enum OnboardingStep {
        case welcome
        case name
        case hydration
        case moodGutSleep
        case howItWorks
    }

    enum Keys {
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
        static let playerDisplayName = "playerDisplayName"
    }

    @Published var currentStep: OnboardingStep = .welcome
    @Published var playerName: String
    @Published var selectedHydrationGoalCups: Int
    @Published var selectedMoodState: MoodStatus
    @Published var selectedGutState: GutStatus
    @Published var selectedSleepValue: SleepQuality
    @Published private(set) var hasCompletedOnboarding: Bool

    private let hydrationSettingsStore: HydrationSettingsStore
    private let healthBarViewModel: HealthBarViewModel
    private let focusViewModel: FocusViewModel
    private let userDefaults: UserDefaults
    private let onCompletion: (() -> Void)?

    init(
        hydrationSettingsStore: HydrationSettingsStore,
        healthBarViewModel: HealthBarViewModel,
        focusViewModel: FocusViewModel,
        userDefaults: UserDefaults = .standard,
        onCompletion: (() -> Void)? = nil
    ) {
        self.hydrationSettingsStore = hydrationSettingsStore
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

        let gut = healthBarViewModel.inputs.gutStatus
        selectedGutState = gut == .none ? .none : gut

        let mood = healthBarViewModel.inputs.moodStatus
        selectedMoodState = mood == .none ? .none : mood

        selectedSleepValue = focusViewModel.sleepQuality
        hasCompletedOnboarding = userDefaults.bool(forKey: Keys.hasCompletedOnboarding)
    }

    func goToNextStep() {
        switch currentStep {
        case .welcome:
            currentStep = .name
        case .name:
            currentStep = .hydration
        case .hydration:
            currentStep = .moodGutSleep
        case .moodGutSleep:
            currentStep = .howItWorks
        case .howItWorks:
            completeOnboarding()
        }
    }

    func skip() {
        hasCompletedOnboarding = true
        userDefaults.set(true, forKey: Keys.hasCompletedOnboarding)
        onCompletion?()
    }

    func completeOnboarding() {
        userDefaults.set(playerName.isEmpty ? QuestChatStrings.PlayerCard.defaultName : playerName, forKey: Keys.playerDisplayName)
        hydrationSettingsStore.dailyWaterGoalOunces = selectedHydrationGoalCups * 8
        healthBarViewModel.setGutStatus(selectedGutState)
        healthBarViewModel.setMoodStatus(selectedMoodState)
        focusViewModel.sleepQuality = selectedSleepValue

        hasCompletedOnboarding = true
        userDefaults.set(true, forKey: Keys.hasCompletedOnboarding)
        onCompletion?()
    }
}
