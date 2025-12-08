import Foundation
import Combine

extension Notification.Name {
    static let gutRatingUpdated = Notification.Name("gutRatingUpdated")
}

struct DailyHealthRatings: Codable {
    var mood: Int?      // 1–5, nil means Not set
    var gut: Int?
    var sleep: Int?
    var activity: Int?
}

final class DailyHealthRatingsStore: ObservableObject {
    private struct Entry: Codable {
        let day: Date
        let ratings: DailyHealthRatings
    }

    private let userDefaults: UserDefaults
    private let storageKey = "daily_health_ratings_v1"
    private let calendar = Calendar.current

    @Published private(set) var ratingsByDay: [Date: DailyHealthRatings] = [:]
    private let notificationCenter = NotificationCenter.default

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        load()
    }

    func ratings(for date: Date = Date()) -> DailyHealthRatings {
        let day = calendar.startOfDay(for: date)
        return ratingsByDay[day] ?? DailyHealthRatings(mood: nil, gut: nil, sleep: nil, activity: nil)
    }

    func update(_ transform: (inout DailyHealthRatings) -> Void, on date: Date = Date()) {
        let day = calendar.startOfDay(for: date)
        var current = ratingsByDay[day] ?? DailyHealthRatings(mood: nil, gut: nil, sleep: nil, activity: nil)
        let oldGut = current.gut
        transform(&current)
        ratingsByDay[day] = current
        save()
        notifyGutChangedIfNeeded(old: oldGut, new: current.gut, day: day)
    }

    func setMood(_ value: Int?, on date: Date = Date()) { update { $0.mood = value } }
    func setGut(_ value: Int?, on date: Date = Date()) { update { $0.gut = value } }
    func setSleep(_ value: Int?, on date: Date = Date()) { update { $0.sleep = value } }
    func setActivity(_ value: Int?, on date: Date = Date()) { update { $0.activity = value } }

    private func notifyGutChangedIfNeeded(old: Int?, new: Int?, day: Date) {
        guard old != new else { return }
        var info: [String: Any] = ["date": day]
        if let new {
            info["value"] = new
        } else {
            info["value"] = NSNull()
        }
        notificationCenter.post(name: .gutRatingUpdated, object: self, userInfo: info)
    }

    private func save() {
        let entries: [Entry] = ratingsByDay.map { Entry(day: $0.key, ratings: $0.value) }
        guard let data = try? JSONEncoder().encode(entries) else { return }
        userDefaults.set(data, forKey: storageKey)
    }

    private func load() {
        guard let data = userDefaults.data(forKey: storageKey) else { return }
        guard let entries = try? JSONDecoder().decode([Entry].self, from: data) else { return }
        var map: [Date: DailyHealthRatings] = [:]
        for entry in entries {
            let day = calendar.startOfDay(for: entry.day)
            map[day] = entry.ratings
        }
        ratingsByDay = map
    }
    
    func delete(for date: Date) {
        let day = calendar.startOfDay(for: date)
        ratingsByDay.removeValue(forKey: day)
        save()
    }

    func delete(in range: ClosedRange<Date>) {
        let start = calendar.startOfDay(for: range.lowerBound)
        let end = calendar.startOfDay(for: range.upperBound)
        let keys = ratingsByDay.keys.filter { key in
            let day = calendar.startOfDay(for: key)
            return (start...end).contains(day)
        }
        for key in keys { ratingsByDay.removeValue(forKey: key) }
        save()
    }
}
