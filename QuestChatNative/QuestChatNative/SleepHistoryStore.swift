import Foundation
import Combine

final class SleepHistoryStore: ObservableObject {
    private struct Entry: Codable {
        let day: Date
        let value: Int
    }

    private let userDefaults: UserDefaults
    private let storageKey = "sleep_history_v1"
    private let calendar = Calendar.current

    @Published private(set) var history: [Date: SleepQuality] = [:]

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        load()
    }

    func record(quality: SleepQuality, date: Date = Date()) {
        let day = calendar.startOfDay(for: date)
        history[day] = quality
        save()
    }

    func quality(on date: Date) -> SleepQuality? {
        let day = calendar.startOfDay(for: date)
        return history[day]
    }

    private func save() {
        let entries: [Entry] = history.map { Entry(day: $0.key, value: $0.value.rawValue) }
        guard let data = try? JSONEncoder().encode(entries) else { return }
        userDefaults.set(data, forKey: storageKey)
    }

    private func load() {
        guard let data = userDefaults.data(forKey: storageKey) else { return }
        guard let entries = try? JSONDecoder().decode([Entry].self, from: data) else { return }
        var map: [Date: SleepQuality] = [:]
        for entry in entries {
            let day = calendar.startOfDay(for: entry.day)
            if let quality = SleepQuality(rawValue: entry.value) {
                map[day] = quality
            }
        }
        history = map
    }
}
