import Foundation

enum HydrationReminderReason {
    case timerCompleted
    case periodic
}

final class HydrationReminderManager: ObservableObject {
    @Published private(set) var lastHydrationReminderDate: Date? {
        didSet { persistLastFiredDate() }
    }

    private let reminderSettingsStore: ReminderSettingsStore
    private let userDefaults: UserDefaults
    private let lastFiredKey = "hydration_reminder_last_fired_date"
    private let legacyLastFiredKey = "reminder_last_fired_hydration"

    init(reminderSettingsStore: ReminderSettingsStore, userDefaults: UserDefaults = .standard) {
        self.reminderSettingsStore = reminderSettingsStore
        self.userDefaults = userDefaults
        if let storedDate = userDefaults.object(forKey: lastFiredKey) as? Date {
            lastHydrationReminderDate = storedDate
        } else if let legacyDate = userDefaults.object(forKey: legacyLastFiredKey) as? Date {
            lastHydrationReminderDate = legacyDate
        }
    }

    @discardableResult
    func maybeScheduleHydrationReminder(
        reason: HydrationReminderReason,
        now: Date = Date(),
        waterIntakeOuncesToday: Int,
        waterGoalOunces: Int,
        isFocusSessionContextActive: Bool,
        sessionCategory: TimerCategory.Kind? = nil,
        sessionDurationMinutes: Int? = nil,
        schedule: () -> Void
    ) -> Bool {
        guard canScheduleHydrationReminder(
            reason: reason,
            now: now,
            waterIntakeOuncesToday: waterIntakeOuncesToday,
            waterGoalOunces: waterGoalOunces,
            isFocusSessionContextActive: isFocusSessionContextActive,
            sessionCategory: sessionCategory,
            sessionDurationMinutes: sessionDurationMinutes
        ) else { return false }

        schedule()
        lastHydrationReminderDate = now
        return true
    }

    func nextEligibleReminderDate(
        now: Date = Date(),
        waterIntakeOuncesToday: Int,
        waterGoalOunces: Int,
        isFocusSessionContextActive: Bool
    ) -> Date? {
        let settings = reminderSettingsStore.hydrationSettings
        guard settings.enabled else { return nil }
        guard waterGoalOunces > 0, waterIntakeOuncesToday < waterGoalOunces else { return nil }
        if settings.onlyDuringFocusSessions, !isFocusSessionContextActive { return nil }

        let cadence = TimeInterval(settings.cadenceMinutes * 60)
        let last = lastHydrationReminderDate ?? now
        let tentative = max(now, last.addingTimeInterval(cadence))

        guard isWithinActiveWindow(tentative, settings: settings) else {
            return nextWindowStart(after: tentative, settings: settings)
        }

        return tentative
    }

    func canScheduleHydrationReminder(
        reason: HydrationReminderReason,
        now: Date = Date(),
        waterIntakeOuncesToday: Int,
        waterGoalOunces: Int,
        isFocusSessionContextActive: Bool,
        sessionCategory: TimerCategory.Kind? = nil,
        sessionDurationMinutes: Int? = nil
    ) -> Bool {
        let settings = reminderSettingsStore.hydrationSettings
        guard settings.enabled else { return false }

        guard waterGoalOunces > 0, waterIntakeOuncesToday < waterGoalOunces else { return false }
        if settings.onlyDuringFocusSessions, !isFocusSessionContextActive { return false }
        guard isWithinActiveWindow(now, settings: settings) else { return false }

        let cadence = TimeInterval(settings.cadenceMinutes * 60)
        let last = lastHydrationReminderDate ?? .distantPast
        guard now.timeIntervalSince(last) >= cadence else { return false }

        if case .timerCompleted = reason {
            guard let category = sessionCategory, category.mode == .focus else { return false }
            guard (sessionDurationMinutes ?? 0) >= 20 else { return false }
        }

        return true
    }
}

private extension HydrationReminderManager {
    func persistLastFiredDate() {
        if let date = lastHydrationReminderDate {
            userDefaults.set(date, forKey: lastFiredKey)
        } else {
            userDefaults.removeObject(forKey: lastFiredKey)
        }
    }

    func isWithinActiveWindow(_ date: Date, settings: ReminderSettings) -> Bool {
        let calendar = Calendar.current
        guard
            let start = calendar.date(bySettingHour: settings.activeStartHour, minute: 0, second: 0, of: date),
            let end = calendar.date(bySettingHour: settings.activeEndHour, minute: 0, second: 0, of: date)
        else { return true }

        if settings.activeStartHour == settings.activeEndHour { return true }

        if end > start {
            return date >= start && date <= end
        } else {
            return date >= start || date <= end
        }
    }

    func nextWindowStart(after date: Date, settings: ReminderSettings) -> Date? {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = settings.activeStartHour
        components.minute = 0
        components.second = 0

        guard let todayStart = calendar.date(from: components) else { return nil }
        if date < todayStart {
            return todayStart
        }

        return calendar.date(byAdding: .day, value: 1, to: todayStart)
    }
}
