import Foundation
import Combine

enum ReminderType: String, Codable, CaseIterable {
    case hydration
    case posture
}

struct ReminderSettings: Codable, Equatable {
    var enabled: Bool
    var cadenceMinutes: Int
    var activeStartHour: Int
    var activeEndHour: Int
    var onlyDuringFocusSessions: Bool
}

struct ReminderEvent: Identifiable {
    let id: UUID
    let type: ReminderType
    let firedAt: Date
    var responded: Bool
    var respondedAt: Date?
}

final class ReminderSettingsStore: ObservableObject {
    @Published var hydrationSettings: ReminderSettings
    @Published var postureSettings: ReminderSettings

    private let userDefaults: UserDefaults

    private let defaults: [ReminderType: ReminderSettings] = [
        .hydration: ReminderSettings(
            enabled: true,
            cadenceMinutes: 60,
            activeStartHour: 9,
            activeEndHour: 22,
            onlyDuringFocusSessions: false
        ),
        .posture: ReminderSettings(
            enabled: true,
            cadenceMinutes: 60,
            activeStartHour: 9,
            activeEndHour: 21,
            onlyDuringFocusSessions: true
        ),
    ]

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults

        hydrationSettings = Self.loadSettings(for: .hydration, userDefaults: userDefaults, defaults: defaults)
        postureSettings = Self.loadSettings(for: .posture, userDefaults: userDefaults, defaults: defaults)
    }

    func settings(for type: ReminderType) -> ReminderSettings {
        switch type {
        case .hydration:
            return hydrationSettings
        case .posture:
            return postureSettings
        }
    }

    func updateSettings(_ settings: ReminderSettings, for type: ReminderType) {
        switch type {
        case .hydration:
            if hydrationSettings != settings {
                hydrationSettings = settings
            }
        case .posture:
            if postureSettings != settings {
                postureSettings = settings
            }
        }

        persist(settings, for: type)
    }

    private func persist(_ settings: ReminderSettings, for type: ReminderType) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        userDefaults.set(data, forKey: Self.storageKey(for: type))
    }

    private static func loadSettings(
        for type: ReminderType,
        userDefaults: UserDefaults,
        defaults: [ReminderType: ReminderSettings]
    ) -> ReminderSettings {
        guard
            let data = userDefaults.data(forKey: storageKey(for: type)),
            let settings = try? JSONDecoder().decode(ReminderSettings.self, from: data)
        else {
            return defaults[type] ?? ReminderSettings(
                enabled: false,
                cadenceMinutes: 60,
                activeStartHour: 9,
                activeEndHour: 21,
                onlyDuringFocusSessions: false
            )
        }

        return settings
    }

    private static func storageKey(for type: ReminderType) -> String {
        "reminder_settings_\(type.rawValue)"
    }
}

final class ReminderEventsStore: ObservableObject {
    @Published private(set) var events: [ReminderEvent] = []

    func log(event: ReminderEvent) {
        events.append(event)
        print("[ReminderEvents] Fired \(event.type.rawValue) at \(event.firedAt)")
    }

    func markResponded(eventId: UUID, at date: Date = Date()) {
        guard let index = events.firstIndex(where: { $0.id == eventId }) else { return }
        events[index].responded = true
        events[index].respondedAt = date
    }
}
