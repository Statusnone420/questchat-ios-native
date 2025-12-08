import Foundation
import Combine

struct HealthDaySummary: Codable, Identifiable {
    var date: Date
    var hpValues: [Int]
    var hydrationCount: Int
    var hydrationOunces: Int
    var selfCareCount: Int
    var focusCount: Int
    var lastGut: GutStatus
    var lastMood: MoodStatus

    var id: Date { date }

    var averageHP: Double {
        guard !hpValues.isEmpty else { return 0 }
        let total = hpValues.reduce(0, +)
        return Double(total) / Double(hpValues.count)
    }
}

extension HealthDaySummary {
    enum CodingKeys: String, CodingKey {
        case date, hpValues, hydrationCount, hydrationOunces, selfCareCount, focusCount, lastGut, lastMood
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.date = try c.decode(Date.self, forKey: .date)
        self.hpValues = try c.decode([Int].self, forKey: .hpValues)
        self.hydrationCount = try c.decodeIfPresent(Int.self, forKey: .hydrationCount) ?? (try c.decode(Int.self, forKey: .hydrationCount))
        // If ounces not present (older data), default to 8oz per logged count to freeze past totals.
        self.hydrationOunces = try c.decodeIfPresent(Int.self, forKey: .hydrationOunces) ?? (self.hydrationCount * 8)
        self.selfCareCount = try c.decode(Int.self, forKey: .selfCareCount)
        self.focusCount = try c.decode(Int.self, forKey: .focusCount)
        self.lastGut = try c.decode(GutStatus.self, forKey: .lastGut)
        self.lastMood = try c.decode(MoodStatus.self, forKey: .lastMood)
    }
}

final class HealthBarIRLStatsStore: ObservableObject {
    @Published var days: [HealthDaySummary] = []
    @Published private(set) var currentHP: Int = 0

    let maxHP: Int = 100

    private let userDefaults: UserDefaults
    private let storageKey = "HealthBarIRLStatsStore.days"
    private let calendar = Calendar.current

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        load()
    }

    var hpPercentage: Double {
        let clamped = max(0, min(Double(currentHP), Double(maxHP)))
        return clamped / Double(maxHP)
    }

    func calculateHP(for inputs: DailyHealthInputs) -> Int {
        HealthBarCalculator.hp(for: inputs)
    }

    func update(from inputs: DailyHealthInputs) {
        let hp = calculateHP(for: inputs)
        currentHP = hp

        let today = calendar.startOfDay(for: Date())

        if let index = days.firstIndex(where: { calendar.isDate($0.date, inSameDayAs: today) }) {
            days[index].hpValues.append(hp)
            // Preserve any hydration already recorded directly on the day (e.g., via addHydration)
            // so partial "sip" logs or background writes are not overwritten if inputs lag behind.
            days[index].hydrationCount = max(days[index].hydrationCount, inputs.hydrationCount)
            days[index].hydrationOunces += inputs.pendingHydrationOunces
            days[index].selfCareCount = inputs.selfCareSessions
            days[index].focusCount = inputs.focusSprints
            days[index].lastGut = inputs.gutStatus
            days[index].lastMood = inputs.moodStatus
        } else {
            let summary = HealthDaySummary(
                date: today,
                hpValues: [hp],
                hydrationCount: inputs.hydrationCount,
                hydrationOunces: inputs.pendingHydrationOunces,
                selfCareCount: inputs.selfCareSessions,
                focusCount: inputs.focusSprints,
                lastGut: inputs.gutStatus,
                lastMood: inputs.moodStatus
            )
            days.insert(summary, at: 0)
        }

        days.sort { $0.date > $1.date }
        trimHistory()
        save()
    }

    func load() {
        guard let data = userDefaults.data(forKey: storageKey) else { return }
        guard let decoded = try? JSONDecoder().decode([HealthDaySummary].self, from: data) else { return }
        days = decoded.sorted { $0.date > $1.date }
        trimHistory()

        if let latestHP = days.first?.hpValues.last {
            currentHP = latestHP
        }
    }

    func save() {
        guard let data = try? JSONEncoder().encode(days) else { return }
        userDefaults.set(data, forKey: storageKey)
    }

    func addHydration(ounces: Int, at date: Date = Date()) {
        let dayStart = calendar.startOfDay(for: date)
        if let idx = days.firstIndex(where: { calendar.isDate($0.date, inSameDayAs: dayStart) }) {
            days[idx].hydrationCount += 1
            days[idx].hydrationOunces += ounces
        } else {
            let summary = HealthDaySummary(
                date: dayStart,
                hpValues: [],
                hydrationCount: 1,
                hydrationOunces: ounces,
                selfCareCount: 0,
                focusCount: 0,
                lastGut: .none,
                lastMood: .none
            )
            days.insert(summary, at: 0)
        }
        days.sort { $0.date > $1.date }
        trimHistory()
        save()
    }

    func deleteSnapshots(since date: Date) {
        let startOfCutoff = calendar.startOfDay(for: date)
        let originalCount = days.count
        days.removeAll { $0.date >= startOfCutoff }

        guard days.count != originalCount else { return }
        save()
    }
    
    func deleteDay(_ day: Date) {
        let target = calendar.startOfDay(for: day)
        let originalCount = days.count
        days.removeAll { calendar.isDate($0.date, inSameDayAs: target) }
        guard days.count != originalCount else { return }
        save()
    }

    private func trimHistory() {
        let maxDays = 14
        if days.count > maxDays {
            days = Array(days.prefix(maxDays))
        }
    }
}
