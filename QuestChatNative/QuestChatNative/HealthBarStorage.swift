import Foundation

protocol HealthBarStorageProtocol {
    func loadTodayInputs() -> DailyHealthInputs
    func saveTodayInputs(_ inputs: DailyHealthInputs)
}

struct DefaultHealthBarStorage: HealthBarStorageProtocol {
    private let userDefaults: UserDefaults
    private let dateProvider: () -> Date

    init(userDefaults: UserDefaults = .standard, dateProvider: @escaping () -> Date = Date.init) {
        self.userDefaults = userDefaults
        self.dateProvider = dateProvider
    }

    func loadTodayInputs() -> DailyHealthInputs {
        let key = Self.key(for: dateProvider())

        guard let data = userDefaults.data(forKey: key) else {
            return Self.defaultInputs
        }

        do {
            return try JSONDecoder().decode(DailyHealthInputs.self, from: data)
        } catch {
            return Self.defaultInputs
        }
    }

    func saveTodayInputs(_ inputs: DailyHealthInputs) {
        let key = Self.key(for: dateProvider())

        guard let data = try? JSONEncoder().encode(inputs) else {
            return
        }

        userDefaults.set(data, forKey: key)
    }
}

private extension DefaultHealthBarStorage {
    static var defaultInputs: DailyHealthInputs {
        DailyHealthInputs(
            hydrationCount: 0,
            selfCareSessions: 0,
            focusSprints: 0,
            gutStatus: .none,
            moodStatus: .none,
            pendingHydrationOunces: 0
        )
    }

    static func key(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
