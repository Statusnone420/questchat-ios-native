import Foundation
import Combine

final class StatsViewModel: ObservableObject {
    struct SeasonAchievementItemViewModel: Identifiable {
        let id: String
        let title: String
        let subtitle: String
        let iconName: String
        let progressValue: Int
        let progressTarget: Int
        let isUnlocked: Bool

        var progressFraction: Double {
            guard progressTarget > 0 else { return 0 }
            return min(1.0, Double(progressValue) / Double(progressTarget))
        }
    }

    @Published private(set) var last7Days: [HealthDaySummary] = []
    @Published var seasonAchievements: [SeasonAchievementItemViewModel] = []
    @Published var unlockedAchievementToShow: SeasonAchievementItemViewModel?

    private let healthStore: HealthBarIRLStatsStore
    private let hydrationSettingsStore: HydrationSettingsStore
    private let seasonAchievementsStore: SeasonAchievementsStore
    private let weekdayFormatter: DateFormatter
    private let userDefaults: UserDefaults
    private let calendar = Calendar.current
    private var cancellables = Set<AnyCancellable>()

    init(
        healthStore: HealthBarIRLStatsStore,
        hydrationSettingsStore: HydrationSettingsStore,
        seasonAchievementsStore: SeasonAchievementsStore,
        userDefaults: UserDefaults = .standard
    ) {
        self.healthStore = healthStore
        self.hydrationSettingsStore = hydrationSettingsStore
        self.seasonAchievementsStore = seasonAchievementsStore
        self.userDefaults = userDefaults
        weekdayFormatter = DateFormatter()
        weekdayFormatter.locale = .current
        weekdayFormatter.dateFormat = "E"

        refresh()
        rebuildSeasonAchievements()
        healthStore.$days
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.refresh()
            }
            .store(in: &cancellables)

        healthStore.$currentHP
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        hydrationSettingsStore.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        seasonAchievementsStore.$progressById
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.rebuildSeasonAchievements() }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .seasonAchievementUnlocked, object: seasonAchievementsStore)
            .compactMap { $0.userInfo?["achievementId"] as? String }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] achievementId in
                self?.handleSeasonAchievementUnlocked(id: achievementId)
            }
            .store(in: &cancellables)
    }

    var hpProgress: Double { healthStore.hpPercentage }

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

    private func rebuildSeasonAchievements() {
        seasonAchievements = seasonAchievementsStore.achievements.map { achievement in
            let progress = seasonAchievementsStore.progress(for: achievement)
            return SeasonAchievementItemViewModel(
                id: achievement.id,
                title: achievement.title,
                subtitle: achievement.subtitle,
                iconName: achievement.iconName,
                progressValue: progress.currentValue,
                progressTarget: achievement.threshold,
                isUnlocked: progress.isUnlocked
            )
        }
    }

    func simulateAchievementUnlock() {
        guard let firstLocked = seasonAchievements.first(where: { !$0.isUnlocked }) else { return }
        unlockedAchievementToShow = firstLocked
    }

    private func handleSeasonAchievementUnlocked(id: String) {
        guard let item = seasonAchievements.first(where: { $0.id == id }) else { return }
        unlockedAchievementToShow = item
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

}
