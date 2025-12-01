import Foundation
import Combine

final class HydrationSettingsStore: ObservableObject {
    @Published var ouncesPerWaterTap: Int
    @Published var ouncesPerComfortTap: Int
    @Published var dailyWaterGoalOunces: Int

    private let storageKey = "hydrationSettings"
    private let userDefaults: UserDefaults
    private var cancellables = Set<AnyCancellable>()

    private struct Settings: Codable {
        let ouncesPerWaterTap: Int
        let ouncesPerComfortTap: Int
        let dailyWaterGoalOunces: Int
    }

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults

        if let data = userDefaults.data(forKey: storageKey),
           let settings = try? JSONDecoder().decode(Settings.self, from: data) {
            ouncesPerWaterTap = settings.ouncesPerWaterTap
            ouncesPerComfortTap = settings.ouncesPerComfortTap
            dailyWaterGoalOunces = settings.dailyWaterGoalOunces
        } else {
            ouncesPerWaterTap = 8
            ouncesPerComfortTap = 8
            dailyWaterGoalOunces = 64
        }

        Publishers.CombineLatest3($ouncesPerWaterTap, $ouncesPerComfortTap, $dailyWaterGoalOunces)
            .sink { [weak self] water, comfort, goal in
                self?.persist(
                    Settings(
                        ouncesPerWaterTap: water,
                        ouncesPerComfortTap: comfort,
                        dailyWaterGoalOunces: goal
                    )
                )
            }
            .store(in: &cancellables)
    }

    private func persist(_ settings: Settings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        userDefaults.set(data, forKey: storageKey)
    }
}
