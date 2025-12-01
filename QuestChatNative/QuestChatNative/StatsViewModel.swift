import Foundation
import Combine

final class StatsViewModel: ObservableObject {
    @Published private(set) var last7Days: [HealthDaySummary] = []

    private let healthStore: HealthBarIRLStatsStore
    private let hydrationSettingsStore: HydrationSettingsStore
    private let weekdayFormatter: DateFormatter
    private let userDefaults: UserDefaults
    private let calendar = Calendar.current

    init(
        healthStore: HealthBarIRLStatsStore,
        hydrationSettingsStore: HydrationSettingsStore,
        userDefaults: UserDefaults = .standard
    ) {
        self.healthStore = healthStore
        self.hydrationSettingsStore = hydrationSettingsStore
        self.userDefaults = userDefaults
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

        hydrationSettingsStore.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    var hpProgress: Double {
        guard let latestHP = todaySummary?.hpValues.last else { return 0 }
        return clampProgress(Double(latestHP) / 100)
    }

    var hydrationProgress: Double {
        let goal = hydrationSettingsStore.dailyWaterGoalOunces
        guard goal > 0 else { return 0 }
        let intake = (todaySummary?.hydrationCount ?? 0) * hydrationSettingsStore.ouncesPerWaterTap
        return clampProgress(Double(intake) / Double(goal))
    }

    var sleepProgress: Double {
        guard let sleepQuality = todaysSleepQuality else { return 0 }
        let normalized = Double(sleepQuality.rawValue) / Double(SleepQuality.allCases.count - 1)
        return clampProgress(normalized)
    }

    var moodProgress: Double {
        let mood = todaySummary?.lastMood ?? .none
        let value: Double = {
            switch mood {
            case .none:
                return 0
            case .bad:
                return 0.25
            case .neutral:
                return 0.5
            case .good:
                return 1
            }
        }()

        return clampProgress(value)
    }

    func label(for date: Date) -> String {
        weekdayFormatter.string(from: date)
    }

    private func refresh() {
        let sorted = healthStore.days.sorted { $0.date > $1.date }
        last7Days = Array(sorted.prefix(7))
    }

    private var todaySummary: HealthDaySummary? {
        let today = calendar.startOfDay(for: Date())
        return healthStore.days.first { calendar.isDate($0.date, inSameDayAs: today) }
    }

    private var todaysSleepQuality: SleepQuality? {
        guard
            let storedDate = userDefaults.object(forKey: HealthTrackingStorageKeys.sleepQualityDate) as? Date,
            calendar.isDate(storedDate, inSameDayAs: Date())
        else { return nil }

        return SleepQuality(rawValue: userDefaults.integer(forKey: HealthTrackingStorageKeys.sleepQualityValue))
    }

    private func clampProgress(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }

    private var cancellables = Set<AnyCancellable>()
}
