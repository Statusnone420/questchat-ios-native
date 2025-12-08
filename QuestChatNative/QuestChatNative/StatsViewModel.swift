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

    struct DailyStatsSummary {
        let questsCompleted: Int
        let totalQuests: Int
        let focusMinutes: Int
        let focusGoalMinutes: Int
        let reachedFocusGoal: Bool

        let mood: MoodStatus?
        let sleepQuality: SleepQuality?
        let hydrationOunces: Int
        let hydrationGoalOunces: Int
        let gutStatus: GutStatus?
        let averageHP: Int?

        var questProgress: Double {
            guard totalQuests > 0 else { return 0 }
            return Double(questsCompleted) / Double(totalQuests)
        }

        var focusProgress: Double {
            guard focusGoalMinutes > 0 else { return 0 }
            let progress = Double(focusMinutes) / Double(focusGoalMinutes)
            return min(progress, 1)
        }

        var hydrationProgress: Double {
            guard hydrationGoalOunces > 0 else { return 0 }
            return min(1.0, Double(hydrationOunces) / Double(hydrationGoalOunces))
        }

        var overallProgress: Double {
            (questProgress + focusProgress) / 2
        }
    }

    @Published private(set) var last7Days: [HealthDaySummary] = []
    @Published var seasonAchievements: [SeasonAchievementItemViewModel] = []
    @Published var unlockedAchievementToShow: SeasonAchievementItemViewModel?
    @Published private(set) var latestUnlockedSeasonAchievement: SeasonAchievementItemViewModel?
    @Published var activeTitle: String?
    @Published private(set) var baseLevelTitle: String?
    @Published private(set) var unlockedAchievementTitles: Set<String> = []

    private let healthStore: HealthBarIRLStatsStore
    private let hydrationSettingsStore: HydrationSettingsStore
    private let seasonAchievementsStore: SeasonAchievementsStore
    private let playerTitleStore: PlayerTitleStore
    private let statsStore: SessionStatsStore
    private let sleepHistoryStore: SleepHistoryStore
    private let dailyRatingsStore: DailyHealthRatingsStore
    private let weekdayFormatter: DateFormatter
    private let userDefaults: UserDefaults
    private let calendar = Calendar.current
    private var cancellables = Set<AnyCancellable>()

    init(
        healthStore: HealthBarIRLStatsStore,
        hydrationSettingsStore: HydrationSettingsStore,
        seasonAchievementsStore: SeasonAchievementsStore,
        playerTitleStore: PlayerTitleStore,
        statsStore: SessionStatsStore,
        sleepHistoryStore: SleepHistoryStore,
        dailyRatingsStore: DailyHealthRatingsStore,
        userDefaults: UserDefaults = .standard
    ) {
        self.healthStore = healthStore
        self.hydrationSettingsStore = hydrationSettingsStore
        self.seasonAchievementsStore = seasonAchievementsStore
        self.playerTitleStore = playerTitleStore
        self.statsStore = statsStore
        self.sleepHistoryStore = sleepHistoryStore
        self.dailyRatingsStore = dailyRatingsStore
        self.userDefaults = userDefaults
        weekdayFormatter = DateFormatter()
        weekdayFormatter.locale = .current
        weekdayFormatter.dateFormat = "E"

        refresh()
        logIRLSnapshots()
        rebuildSeasonAchievements()
        playerTitleStore.$equippedOverrideTitle
            .combineLatest(playerTitleStore.$baseLevelTitle)
            .receive(on: DispatchQueue.main)
            .map { override, base in
                override ?? base
            }
            .assign(to: &$activeTitle)

        playerTitleStore.$baseLevelTitle
            .receive(on: DispatchQueue.main)
            .assign(to: &$baseLevelTitle)

        playerTitleStore.$unlockedTitles
            .receive(on: DispatchQueue.main)
            .assign(to: &$unlockedAchievementTitles)
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
        let intake = todaySummary?.hydrationOunces ?? 0
        return clampProgress(Double(intake) / Double(goal))
    }

    var sleepProgress: Double {
        // Visual-only: map the 1–5 slider directly to 0.0–1.0 so 5 shows full, 4 is slightly less, etc.
        // HP backend still uses bucketed SleepQuality via HealthRatingMapper elsewhere.
        let rating = dailyRatingsStore.ratings().sleep
        guard let rating else { return 0 }
        let normalized = (Double(rating) - 1.0) / 4.0
        return clampProgress(normalized)
    }

    var moodProgress: Double {
        // Visual-only: map the 1–5 slider directly to 0.0–1.0 so 5 shows full, 4 is slightly less, etc.
        // HP backend still uses bucketed MoodStatus via HealthRatingMapper elsewhere.
        let rating = dailyRatingsStore.ratings().mood
        guard let rating else { return 0 }
        let normalized = (Double(rating) - 1.0) / 4.0
        return clampProgress(normalized)
    }

    var momentumLabel: String {
        statsStore.momentumLabel()
    }

    var momentumDescription: String {
        statsStore.momentumDescription()
    }

    var momentumMultiplier: Double {
        statsStore.momentumMultiplier()
    }

    var yesterdaySummary: DailyStatsSummary? {
        let yesterday = yesterdayDate
        let progress = statsStore.dailyProgress(for: yesterday)
        let totalQuests = max(progress.totalQuests ?? progress.questsCompleted, progress.questsCompleted)
        let focusGoalMinutes = progress.focusGoalMinutes ?? defaultFocusGoalMinutes

        guard hasActivity(on: yesterday, progress: progress) else { return nil }

        let daySummary = healthStore.days.first { calendar.isDate($0.date, inSameDayAs: yesterday) }
        let hydrationOunces = daySummary?.hydrationOunces ?? 0
        let hydrationGoalOunces = hydrationSettingsStore.dailyWaterGoalOunces
        let mood = daySummary?.lastMood
        let sleepQuality = yesterdaysSleepQuality
        let averageHP = daySummary.flatMap { Int($0.averageHP.rounded()) }
        let gutStatus = daySummary?.lastGut

        return DailyStatsSummary(
            questsCompleted: progress.questsCompleted,
            totalQuests: totalQuests,
            focusMinutes: progress.focusMinutes,
            focusGoalMinutes: focusGoalMinutes,
            reachedFocusGoal: progress.reachedFocusGoal,
            mood: mood,
            sleepQuality: sleepQuality,
            hydrationOunces: hydrationOunces,
            hydrationGoalOunces: hydrationGoalOunces,
            gutStatus: gutStatus,
            averageHP: averageHP
        )
    }

    var yesterdayStreakDots: [SessionStatsStore.WeeklyGoalDayStatus] {
        statsStore.weeklyGoalProgress(asOf: yesterdayDate)
    }

    var wasStreakMaintainedYesterday: Bool? {
        let progress = statsStore.dailyProgress(for: yesterdayDate)
        guard hasActivity(on: yesterdayDate, progress: progress) else { return nil }
        return progress.reachedFocusGoal
    }

    var yesterdayUnlockedAchievements: [SeasonAchievementItemViewModel] {
        seasonAchievements.compactMap { item in
            guard
                let progress = seasonAchievementsStore.progressById[item.id],
                let unlockedAt = progress.unlockedAt,
                calendar.isDate(unlockedAt, inSameDayAs: yesterdayDate)
            else { return nil }

            return item
        }
    }

    func label(for date: Date) -> String {
        weekdayFormatter.string(from: date)
    }

    private var defaultFocusGoalMinutes: Int { statsStore.todayPlan?.focusGoalMinutes ?? 40 }

    private var yesterdayDate: Date {
        let today = calendar.startOfDay(for: Date())
        return calendar.date(byAdding: .day, value: -1, to: today) ?? today
    }

    private var yesterdaysSleepQuality: SleepQuality? {
        let date = yesterdayDate
        if let quality = sleepHistoryStore.quality(on: date) { return quality }
        guard
            let storedDate = userDefaults.object(forKey: HealthTrackingStorageKeys.sleepQualityDate) as? Date,
            calendar.isDate(storedDate, inSameDayAs: date)
        else { return nil }
        return SleepQuality(rawValue: userDefaults.integer(forKey: HealthTrackingStorageKeys.sleepQualityValue))
    }

    // Removed `todaysSleepQuality` property. DailyHealthRatingsStore is now canonical source for today's ratings.

    private func refresh() {
        let sorted = healthStore.days.sorted { $0.date > $1.date }
        last7Days = Array(sorted.prefix(7))
    }

    private func logIRLSnapshots() {
        let today = calendar.startOfDay(for: Date())
        let yesterday = yesterdayDate

        func describe(_ summary: HealthDaySummary?) -> String {
            guard let summary else { return "<none>" }
            return "date=\(summary.date), hydrationCount=\(summary.hydrationCount), hydrationOunces=\(summary.hydrationOunces), gut=\(summary.lastGut.rawValue), mood=\(summary.lastMood.rawValue), focusCount=\(summary.focusCount), selfCareCount=\(summary.selfCareCount), avgHP=\(Int(summary.averageHP.rounded()))"
        }

        let todaySnapshot = healthStore.days.first { calendar.isDate($0.date, inSameDayAs: today) }
        let yesterdaySnapshot = healthStore.days.first { calendar.isDate($0.date, inSameDayAs: yesterday) }

        print("[StatsViewModel] Today IRL snapshot: \(describe(todaySnapshot))")
        print("[StatsViewModel] Yesterday IRL snapshot: \(describe(yesterdaySnapshot))")
    }

    private func rebuildSeasonAchievements() {
        var mostRecent: (Date, SeasonAchievementItemViewModel)?

        seasonAchievements = seasonAchievementsStore.achievements.map { achievement in
            let progress = seasonAchievementsStore.progress(for: achievement)
            let item = SeasonAchievementItemViewModel(
                id: achievement.id,
                title: achievement.title,
                subtitle: achievement.subtitle,
                iconName: achievement.iconName,
                progressValue: progress.currentValue,
                progressTarget: achievement.threshold,
                isUnlocked: progress.isUnlocked
            )

            if progress.isUnlocked {
                playerTitleStore.unlock(title: achievement.title)
            }

            if let unlockedAt = progress.unlockedAt {
                if let current = mostRecent {
                    if unlockedAt > current.0 { mostRecent = (unlockedAt, item) }
                } else {
                    mostRecent = (unlockedAt, item)
                }
            }

            return item
        }

        latestUnlockedSeasonAchievement = mostRecent?.1
    }

    func simulateAchievementUnlock() {
        guard let firstLocked = seasonAchievements.first(where: { !$0.isUnlocked }) else { return }
        unlockedAchievementToShow = firstLocked
    }

    func equipBaseLevelTitle() {
        playerTitleStore.clearOverride()
    }

    func equipOverrideTitle(_ title: String) {
        playerTitleStore.equipOverride(title: title)
    }

    private func handleSeasonAchievementUnlocked(id: String) {
        guard let item = seasonAchievements.first(where: { $0.id == id }) else { return }
        unlockedAchievementToShow = item

        if let achievement = seasonAchievementsStore.achievements.first(where: { $0.id == id }) {
            playerTitleStore.unlock(title: achievement.title)
        }
    }

    func equipTitle(for achievement: SeasonAchievementItemViewModel) {
        playerTitleStore.equipOverride(title: achievement.title)
    }

    func achievement(for id: String) -> SeasonAchievement? {
        seasonAchievementsStore.achievements.first { $0.id == id }
    }

    func progress(for achievement: SeasonAchievement) -> SeasonAchievementProgress {
        seasonAchievementsStore.progress(for: achievement)
    }

#if DEBUG
    var hasLockedSeasonAchievements: Bool {
        seasonAchievements.contains { !$0.isUnlocked }
    }

    func unlockAllSeasonAchievementsForDebug(postNotifications: Bool = false) {
        seasonAchievementsStore.unlockAllSeasonAchievementsForDebug(postNotifications: postNotifications)
    }
#endif

    private var todaySummary: HealthDaySummary? {
        let today = calendar.startOfDay(for: Date())
        return healthStore.days.first { calendar.isDate($0.date, inSameDayAs: today) }
    }

    private func hasActivity(on date: Date, progress: DailyProgress) -> Bool {
        let hasSessions = statsStore.sessionHistory.contains { calendar.isDate($0.date, inSameDayAs: date) }
        return hasSessions || progress.focusMinutes > 0 || progress.questsCompleted > 0 || progress.reachedFocusGoal
    }

    private func clampProgress(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }
    
    func setBaseLevelTitle(_ title: String) {
        // Update the base level title in the store and clear any override so base wins by default.
        playerTitleStore.updateBaseLevelTitle(title)
        equipBaseLevelTitle()
    }

}
