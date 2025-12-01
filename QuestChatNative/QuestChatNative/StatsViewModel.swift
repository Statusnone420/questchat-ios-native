import Foundation
import Combine

final class StatsViewModel: ObservableObject {
    @Published private(set) var last7Days: [HealthDaySummary] = []

    private let healthStore: HealthBarIRLStatsStore
    private let hydrationSettingsStore: HydrationSettingsStore
    private let weekdayFormatter: DateFormatter

    init(healthStore: HealthBarIRLStatsStore, hydrationSettingsStore: HydrationSettingsStore) {
        self.healthStore = healthStore
        self.hydrationSettingsStore = hydrationSettingsStore
        weekdayFormatter = DateFormatter()
        weekdayFormatter.locale = .current
        weekdayFormatter.dateFormat = "E"

        refresh()
        healthStore.$days
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.refresh()
            }
            .store(in: &cancellables)
    }

    func label(for date: Date) -> String {
        weekdayFormatter.string(from: date)
    }

    private func refresh() {
        let sorted = healthStore.days.sorted { $0.date > $1.date }
        last7Days = Array(sorted.prefix(7))
    }

    private var cancellables = Set<AnyCancellable>()
}
