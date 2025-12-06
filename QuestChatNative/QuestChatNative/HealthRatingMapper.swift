import Foundation

enum HealthRatingMapper {
    static func label(for rating: Int) -> String {
        switch rating {
        case 1:
            return "Terrible"
        case 2:
            return "Low"
        case 3:
            return "Okay"
        case 4:
            return "Good"
        case 5:
            return "Great"
        default:
            return "Not set"
        }
    }

    static func activityLabel(for rating: Int) -> String {
        switch rating {
        case 1:
            return "Barely moved"
        case 2:
            return "Lightly active"
        case 3:
            return "Some movement"
        case 4:
            return "Active"
        case 5:
            return "Very active"
        default:
            return "Not set"
        }
    }

    static func moodStatus(for rating: Int?) -> MoodStatus {
        // Collapse 5-point rating into 3 HP buckets:
        // nil → .none (ignored for HP)
        // 1–2 → .bad
        // 3   → .neutral
        // 4–5 → .good
        guard let rating else { return .none }

        switch rating {
        case 1, 2:
            return .bad
        case 3:
            return .neutral
        case 4, 5:
            return .good
        default:
            // Any out-of-range value is treated as not set
            return .none
        }
    }

    static func rating(for status: MoodStatus) -> Int? {
        switch status {
        case .none:
            return nil
        case .bad:
            return 1
        case .neutral:
            return 3
        case .good:
            return 5
        }
    }

    static func gutStatus(for rating: Int?) -> GutStatus {
        // Collapse 5-point rating into 3 HP buckets:
        // nil → .none (ignored for HP)
        // 1–2 → .rough
        // 3   → .meh
        // 4–5 → .great
        guard let rating else { return .none }

        switch rating {
        case 1, 2:
            return .rough
        case 3:
            return .meh
        case 4, 5:
            return .great
        default:
            // Any out-of-range value is treated as not set
            return .none
        }
    }

    static func rating(for status: GutStatus) -> Int? {
        switch status {
        case .none:
            return nil
        case .rough:
            return 1
        case .meh:
            return 3
        case .great:
            return 5
        }
    }

    static func sleepQuality(for rating: Int) -> SleepQuality? {
        // Collapse 5-point rating into 3 HP buckets:
        // 1–2 → .awful, 3 → .okay, 4–5 → .great
        // Note: callers should pass nil ratings as nil and treat them as ignored for HP.
        switch rating {
        case 1, 2:
            return .awful
        case 3:
            return .okay
        case 4, 5:
            return .great
        default:
            // Any out-of-range or placeholder value yields no quality
            return nil
        }
    }

    static func rating(for quality: SleepQuality) -> Int {
        switch quality {
        case .awful:
            return 1
        case .okay:
            return 3
        case .great:
            return 5
        }
    }

    static func activityLevel(for rating: Int?) -> ActivityLevel? {
        guard let rating else { return nil }
        return ActivityLevel(rawValue: rating)
    }

    static func rating(for activityLevel: ActivityLevel?) -> Int? {
        activityLevel?.rawValue
    }
}
