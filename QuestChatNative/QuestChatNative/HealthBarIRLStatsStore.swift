import Foundation
import Combine

struct HealthDaySummary: Codable, Identifiable {
    var date: Date
    var hpValues: [Int]
    var hydrationCount: Int
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

final class HealthBarIRLStatsStore: ObservableObject {
    @Published var days: [HealthDaySummary] = []

    private let userDefaults: UserDefaults
    private let storageKey = "HealthBarIRLStatsStore.days"
    private let calendar = Calendar.current

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        load()
    }

    func recordSnapshot(
        hp: Int,
        hydrationCount: Int,
        selfCareCount: Int,
        focusCount: Int,
        gutStatus: GutStatus,
        moodStatus: MoodStatus
    ) {
        let today = calendar.startOfDay(for: Date())

        if let index = days.firstIndex(where: { calendar.isDate($0.date, inSameDayAs: today) }) {
            days[index].hpValues.append(hp)
            days[index].hydrationCount = hydrationCount
            days[index].selfCareCount = selfCareCount
            days[index].focusCount = focusCount
            days[index].lastGut = gutStatus
            days[index].lastMood = moodStatus
        } else {
            let summary = HealthDaySummary(
                date: today,
                hpValues: [hp],
                hydrationCount: hydrationCount,
                selfCareCount: selfCareCount,
                focusCount: focusCount,
                lastGut: gutStatus,
                lastMood: moodStatus
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
    }

    func save() {
        guard let data = try? JSONEncoder().encode(days) else { return }
        userDefaults.set(data, forKey: storageKey)
    }

    func deleteSnapshots(since date: Date) {
        let startOfCutoff = calendar.startOfDay(for: date)
        let originalCount = days.count
        days.removeAll { $0.date >= startOfCutoff }

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
