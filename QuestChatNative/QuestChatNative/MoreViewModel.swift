import Foundation
import Combine

final class MoreViewModel: ObservableObject {
    @Published var ouncesPerWaterTap: Int
    @Published var ouncesPerComfortTap: Int
    @Published var dailyWaterGoalOunces: Int
    @Published var hydrationReminderSettings: ReminderSettings
    @Published var postureReminderSettings: ReminderSettings

    private let hydrationSettingsStore: HydrationSettingsStore
    private let reminderSettingsStore: ReminderSettingsStore
    private var cancellables = Set<AnyCancellable>()

    init(hydrationSettingsStore: HydrationSettingsStore, reminderSettingsStore: ReminderSettingsStore) {
        self.hydrationSettingsStore = hydrationSettingsStore
        self.reminderSettingsStore = reminderSettingsStore
        ouncesPerWaterTap = hydrationSettingsStore.ouncesPerWaterTap
        ouncesPerComfortTap = hydrationSettingsStore.ouncesPerComfortTap
        dailyWaterGoalOunces = hydrationSettingsStore.dailyWaterGoalOunces
        hydrationReminderSettings = reminderSettingsStore.hydrationSettings
        postureReminderSettings = reminderSettingsStore.postureSettings

        Publishers.CombineLatest3($ouncesPerWaterTap, $ouncesPerComfortTap, $dailyWaterGoalOunces)
            .sink { [weak self] water, comfort, goal in
                guard let self else { return }
                self.hydrationSettingsStore.ouncesPerWaterTap = water
                self.hydrationSettingsStore.ouncesPerComfortTap = comfort
                self.hydrationSettingsStore.dailyWaterGoalOunces = goal
            }
            .store(in: &cancellables)

        $hydrationReminderSettings
            .sink { [weak self] settings in
                self?.reminderSettingsStore.updateSettings(settings, for: .hydration)
            }
            .store(in: &cancellables)

        $postureReminderSettings
            .sink { [weak self] settings in
                self?.reminderSettingsStore.updateSettings(settings, for: .posture)
            }
            .store(in: &cancellables)
    }
}
