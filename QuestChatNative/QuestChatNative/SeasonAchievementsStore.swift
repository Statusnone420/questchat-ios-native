import Foundation
import Combine

extension Notification.Name {
    static let seasonAchievementUnlocked = Notification.Name("seasonAchievementUnlocked")
}

final class SeasonAchievementsStore: ObservableObject {
    @Published private(set) var achievements: [SeasonAchievement]
    @Published private(set) var progressById: [String: SeasonAchievementProgress]
    
    private let progressKey = "season_achievements_progress_v1"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private var streaks: [SeasonAchievementConditionType: Int] = [:]
    private var lastProgressDates: [SeasonAchievementConditionType: Date] = [:]

    enum FourRealmsCategory: String, CaseIterable {
        case work
        case home
        case health
        case chill
    }

    private var fourRealmsByDay: [Date: Set<FourRealmsCategory>] = [:]

    init(achievements: [SeasonAchievement] = SeasonAchievement.allSeasonOne) {
        self.achievements = achievements
        // Attempt to load persisted progress and merge with current achievements
        let defaults = UserDefaults.standard
        if let data = defaults.data(forKey: progressKey),
           let saved = try? decoder.decode([String: SeasonAchievementProgress].self, from: data) {
            // Build merged dictionary ensuring every current achievement has an entry
            var merged: [String: SeasonAchievementProgress] = [:]
            for ach in achievements {
                if let existing = saved[ach.id] {
                    merged[ach.id] = existing
                } else {
                    merged[ach.id] = SeasonAchievementsStore.defaultProgress(for: ach)
                }
            }
            // Optionally drop progress for achievements that no longer exist (ignored by not copying extras)
            self.progressById = merged
        } else {
            self.progressById = Self.initialProgress(for: achievements)
        }
        // Persist after initialization to ensure key exists and any migrations are saved
        persistProgress()
    }

    func progress(for achievement: SeasonAchievement) -> SeasonAchievementProgress {
        progressById[achievement.id] ?? SeasonAchievementProgress(
            id: achievement.id,
            achievementId: achievement.id,
            currentValue: 0,
            unlockedAt: nil,
            lastUpdatedAt: nil
        )
    }

    /// Call this when a game event occurs (e.g., hydration goal met).
    /// - Returns: The first achievement that just unlocked, if any.
    @discardableResult
    func applyProgress(
        conditionType: SeasonAchievementConditionType,
        amount: Int = 1,
        date: Date? = nil
    ) -> SeasonAchievement? {
        var unlockedAchievement: SeasonAchievement?
        let day = date.map(truncateToDay)
        let calendar = Calendar.current

        for achievement in achievements where achievement.conditionType == conditionType {
            guard var progress = progressById[achievement.id] else { continue }
            guard !progress.isUnlocked else { continue }

            let updatedValue: Int

            switch conditionType {
            case .dailyFocusMinutesStreak, .questsTabOpenedDaysStreak, .moodAboveMehDaysStreak:
                guard let day else { continue }
                updatedValue = updateStreak(for: conditionType, on: day)
            case .hpAboveThresholdDays, .hydrationDaysReached:
                if let day, let lastDate = lastProgressDates[conditionType], calendar.isDate(lastDate, inSameDayAs: day) {
                    continue
                }
                if let day { lastProgressDates[conditionType] = day }
                updatedValue = progress.currentValue + amount
            case .fourRealmsWeek:
                updatedValue = achievement.threshold
            default:
                updatedValue = progress.currentValue + amount
            }

            progress.currentValue = min(updatedValue, achievement.threshold)
            progress.lastUpdatedAt = Date()

            if progress.currentValue >= achievement.threshold {
                progress.currentValue = achievement.threshold
                progress.unlockedAt = Date()
                unlockedAchievement = achievement
            }

            progressById[achievement.id] = progress
        }

        // Save progress after applying updates
        persistProgress()

        if let unlocked = unlockedAchievement {
            NotificationCenter.default.post(
                name: .seasonAchievementUnlocked,
                object: self,
                userInfo: ["achievementId": unlocked.id]
            )
        }

        return unlockedAchievement
    }

    private static func initialProgress(for achievements: [SeasonAchievement]) -> [String: SeasonAchievementProgress] {
        Dictionary(uniqueKeysWithValues: achievements.map { achievement in
            (achievement.id, defaultProgress(for: achievement))
        })
    }
    
    private static func defaultProgress(for achievement: SeasonAchievement) -> SeasonAchievementProgress {
        SeasonAchievementProgress(
            id: achievement.id,
            achievementId: achievement.id,
            currentValue: 0,
            unlockedAt: nil,
            lastUpdatedAt: nil
        )
    }

    private func recordFourRealmsCategoryCompletion(
        category: FourRealmsCategory,
        date: Date
    ) {
        let day = truncateToDay(date)
        var set = fourRealmsByDay[day] ?? []
        set.insert(category)
        fourRealmsByDay[day] = set

        pruneFourRealmsHistory()
        evaluateFourRealmsAchievement()
    }

    func recordFourRealmsSessionCompletion(
        mode: TimerCategory.Kind,
        date: Date
    ) {
        guard let category = FourRealmsCategory(kind: mode) else { return }
        recordFourRealmsCategoryCompletion(category: category, date: date)
    }

    private func truncateToDay(_ date: Date) -> Date {
        Calendar.current.startOfDay(for: date)
    }

    private func updateStreak(for conditionType: SeasonAchievementConditionType, on day: Date) -> Int {
        let calendar = Calendar.current
        let lastDate = lastProgressDates[conditionType]
        var streak = streaks[conditionType] ?? 0

        if let lastDate {
            if calendar.isDate(lastDate, inSameDayAs: day) {
                // Same day; keep the streak as-is.
            } else if let diff = calendar.dateComponents([.day], from: lastDate, to: day).day, diff == 1 {
                streak += 1
            } else {
                streak = 1
            }
        } else {
            streak = 1
        }

        streaks[conditionType] = streak
        lastProgressDates[conditionType] = day
        return streak
    }

    private func pruneFourRealmsHistory() {
        let calendar = Calendar.current
        guard let cutoff = calendar.date(byAdding: .day, value: -21, to: Date()) else { return }
        let startOfCutoff = calendar.startOfDay(for: cutoff)
        fourRealmsByDay = fourRealmsByDay.filter { $0.key >= startOfCutoff }
    }

    private func evaluateFourRealmsAchievement() {
        guard !fourRealmsByDay.isEmpty else { return }
        let calendar = Calendar.current
        let sortedDays = fourRealmsByDay.keys.sorted()
        guard let firstDay = sortedDays.first, let lastDay = sortedDays.last else { return }

        var windowStart = firstDay
        while windowStart <= lastDay {
            var currentDay = windowStart
            var isValidWindow = true

            for _ in 0..<7 {
                guard let categories = fourRealmsByDay[currentDay], categories.count == FourRealmsCategory.allCases.count else {
                    isValidWindow = false
                    break
                }

                guard let nextDay = calendar.date(byAdding: .day, value: 1, to: currentDay) else { return }
                currentDay = nextDay
            }

            if isValidWindow {
                applyProgress(conditionType: .fourRealmsWeek, amount: 1, date: windowStart)
                break
            }

            guard let nextStart = calendar.date(byAdding: .day, value: 1, to: windowStart) else { return }
            windowStart = nextStart
        }
    }
    
    private func persistProgress() {
        if let data = try? encoder.encode(progressById) {
            UserDefaults.standard.set(data, forKey: progressKey)
        }
    }
    
#if DEBUG
    func resetAllSeasonProgress() {
        self.progressById = Self.initialProgress(for: achievements)
        UserDefaults.standard.removeObject(forKey: progressKey)
        persistProgress()
    }

    func unlockAllSeasonAchievementsForDebug(postNotifications: Bool = false) {
        var didChange = false

        for achievement in achievements {
            guard var progress = progressById[achievement.id] else { continue }
            guard !progress.isUnlocked else { continue }

            progress.currentValue = achievement.threshold
            progress.unlockedAt = Date()
            progress.lastUpdatedAt = Date()
            progressById[achievement.id] = progress
            didChange = true

            if postNotifications {
                NotificationCenter.default.post(
                    name: .seasonAchievementUnlocked,
                    object: self,
                    userInfo: ["achievementId": achievement.id]
                )
            }
        }

        if didChange {
            persistProgress()
        }
    }
#endif
}

private extension SeasonAchievementsStore.FourRealmsCategory {
    init?(kind mode: TimerCategory.Kind) {
        switch mode {
        case .create, .focusMode:
            self = .work
        case .chores:
            self = .home
        case .selfCare:
            self = .health
        case .gamingReset, .move:
            self = .chill
        }
    }
}
