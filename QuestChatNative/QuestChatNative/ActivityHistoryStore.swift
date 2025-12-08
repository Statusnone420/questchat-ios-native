import Foundation
import Combine

enum ActivityLevel: Int, Codable, CaseIterable, Identifiable {
    case one = 1
    case two
    case three
    case four
    case five

    var id: Int { rawValue }
}

final class ActivityHistoryStore: ObservableObject {
    private struct Entry: Codable {
        let day: Date
        let value: Int
    }

    private let userDefaults: UserDefaults
    private let storageKey = "activity_history_v1"
    private let calendar = Calendar.current

    @Published private(set) var history: [Date: ActivityLevel] = [:]

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        load()
    }

    func record(level: ActivityLevel, date: Date = Date()) {
        let day = calendar.startOfDay(for: date)
        history[day] = level
        save()
    }

    func removeRecord(on date: Date = Date()) {
        let day = calendar.startOfDay(for: date)
        history.removeValue(forKey: day)
        save()
    }

    func level(on date: Date) -> ActivityLevel? {
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
        var map: [Date: ActivityLevel] = [:]
        for entry in entries {
            let day = calendar.startOfDay(for: entry.day)
            if let level = ActivityLevel(rawValue: entry.value) {
                map[day] = level
            }
        }
        history = map
    }
}
