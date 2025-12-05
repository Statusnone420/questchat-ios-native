import Foundation
import Combine
import SwiftUI

final class HealthBarViewModel: ObservableObject {
    @Published private(set) var inputs: DailyHealthInputs
    @Published private(set) var hp: Int = 40
    @Published private(set) var currentHP: Int = 40

    private let defaultMaxHP: Double = 100

    private let storage: HealthBarStorageProtocol
    private let healthStatsStore: HealthBarIRLStatsStore?
    private let statsStore: SessionStatsStore?
    private let hydrationSettingsStore: HydrationSettingsStore?
    private let sleepHistoryStore: SleepHistoryStore?
    private var cancellables = Set<AnyCancellable>()

    init(
        storage: HealthBarStorageProtocol = DefaultHealthBarStorage(),
        statsStore: HealthBarIRLStatsStore? = nil,
        sessionStatsStore: SessionStatsStore? = nil,
        hydrationSettingsStore: HydrationSettingsStore? = nil,
        sleepHistoryStore: SleepHistoryStore? = nil
    ) {
        self.storage = storage
        self.healthStatsStore = statsStore
        self.statsStore = sessionStatsStore
        self.hydrationSettingsStore = hydrationSettingsStore
        self.sleepHistoryStore = sleepHistoryStore
        inputs = storage.loadTodayInputs()
        currentHP = statsStore?.currentHP ?? HealthBarCalculator.hp(for: inputs)
        recalculate()

        bindStores()
    }

    func logHydration() {
        inputs.hydrationCount += 1
        recalculate()
        save()
    }

    func logSelfCareSession() {
        inputs.selfCareSessions += 1
        recalculate()
        save()
    }

    func logFocusSprint() {
        inputs.focusSprints += 1
        recalculate()
        save()
    }

    func setGutStatus(_ status: GutStatus) {
        inputs.gutStatus = status
        recalculate()
        save()
    }

    func setMoodStatus(_ status: MoodStatus) {
        inputs.moodStatus = status
        recalculate()
        save()
    }

    var maxHP: Int { healthStatsStore?.maxHP ?? Int(defaultMaxHP) }

    var hpSegments: Int { 12 }

    var xpInCurrentLevel: Int { statsStore?.xpIntoCurrentLevel ?? 0 }

    var xpToNextLevel: Int { statsStore?.xpNeededToLevelUp(from: level) ?? 0 }

    var xpProgress: Double {
        let needed = max(1, xpToNextLevel == Int.max ? 1 : xpToNextLevel)
        return Double(min(xpInCurrentLevel, needed)) / Double(needed)
    }

    var level: Int { statsStore?.level ?? 1 }

    var gutStatusText: String {
        switch inputs.gutStatus {
        case .none: return "Not set"
        case .great: return "Great"
        case .meh: return "Meh"
        case .rough: return "Rough"
        }
    }

    var moodStatusText: String {
        switch inputs.moodStatus {
        case .none: return "Not set"
        case .good: return "Good"
        case .neutral: return "Neutral"
        case .bad: return "Bad"
        }
    }

    var sleepStatusText: String {
        todaysSleepQuality?.label ?? "Not set"
    }

    var hydrationProgress: Double {
        let goal = hydrationSettingsStore?.dailyWaterGoalOunces ?? 0
        guard goal > 0 else { return 0 }
        let intake = (inputs.hydrationCount) * (hydrationSettingsStore?.ouncesPerWaterTap ?? 0)
        return clampProgress(Double(intake) / Double(goal))
    }

    var sleepProgress: Double {
        guard let sleepQuality = todaysSleepQuality else { return 0 }
        let normalized = Double(sleepQuality.rawValue) / Double(SleepQuality.allCases.count - 1)
        return clampProgress(normalized)
    }

    var moodProgress: Double {
        let value: Double = {
            switch inputs.moodStatus {
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

    var staminaProgress: Double {
        let target = 4.0
        return clampProgress(Double(inputs.focusSprints) / target)
    }

    var hydrationSummaryText: String {
        let intake = waterIntakeOuncesToday
        let goal = hydrationSettingsStore?.dailyWaterGoalOunces ?? 0
        let goalText = goal > 0 ? " / \(goal) oz" : " oz"
        return "\(intake)\(goalText)"
    }

    var hydrationCupsText: String? {
        let intake = waterIntakeOuncesToday
        let goal = hydrationSettingsStore?.dailyWaterGoalOunces ?? 0
        guard intake > 0 || goal > 0 else { return nil }

        let intakeCups = Double(intake) / 8
        let goalCups = goal > 0 ? Double(goal) / 8 : nil
        if let goalCups { return String(format: "%.0f / %.0f cups", intakeCups, goalCups) }
        return String(format: "%.0f cups", intakeCups)
    }

    var staminaLabel: String {
        "\(inputs.focusSprints) focus sprints"
    }

    var hpProgress: Double { healthStatsStore?.hpPercentage ?? hpPercentage }

    private var todaysSleepQuality: SleepQuality? {
        let today = Calendar.current.startOfDay(for: Date())
        return sleepHistoryStore?.quality(on: today)
    }

    private var waterIntakeOuncesToday: Int {
        (inputs.hydrationCount) * (hydrationSettingsStore?.ouncesPerWaterTap ?? 0)
    }

    var hpPercentage: Double {
        let clamped = max(0, min(Double(currentHP), Double(maxHP)))
        return clamped / Double(maxHP)
    }

    var healthBarColor: Color {
        switch hpPercentage {
        case ..<0.34:
            return .red
        case ..<0.67:
            return .yellow
        default:
            return .green
        }
    }
}

private extension HealthBarViewModel {
    func recalculate() {
        hp = healthStatsStore?.calculateHP(for: inputs) ?? HealthBarCalculator.hp(for: inputs)
        currentHP = hp
    }

    func save() {
        storage.saveTodayInputs(inputs)
    }

    func bindStores() {
        healthStatsStore?.$currentHP
            .receive(on: RunLoop.main)
            .sink { [weak self] hp in
                self?.hp = hp
                self?.currentHP = hp
            }
            .store(in: &cancellables)

        statsStore?.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        hydrationSettingsStore?.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        sleepHistoryStore?.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    func clampProgress(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }
}
