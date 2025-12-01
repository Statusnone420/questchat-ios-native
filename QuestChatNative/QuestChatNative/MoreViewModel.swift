import Foundation
import Combine

final class MoreViewModel: ObservableObject {
    @Published var ouncesPerWaterTap: Int
    @Published var ouncesPerComfortTap: Int
    @Published var dailyWaterGoalOunces: Int

    private let hydrationSettingsStore: HydrationSettingsStore
    private var cancellables = Set<AnyCancellable>()

    init(hydrationSettingsStore: HydrationSettingsStore) {
        self.hydrationSettingsStore = hydrationSettingsStore
        ouncesPerWaterTap = hydrationSettingsStore.ouncesPerWaterTap
        ouncesPerComfortTap = hydrationSettingsStore.ouncesPerComfortTap
        dailyWaterGoalOunces = hydrationSettingsStore.dailyWaterGoalOunces

        Publishers.CombineLatest3($ouncesPerWaterTap, $ouncesPerComfortTap, $dailyWaterGoalOunces)
            .sink { [weak self] water, comfort, goal in
                guard let self else { return }
                self.hydrationSettingsStore.ouncesPerWaterTap = water
                self.hydrationSettingsStore.ouncesPerComfortTap = comfort
                self.hydrationSettingsStore.dailyWaterGoalOunces = goal
            }
            .store(in: &cancellables)
    }
}
