import Foundation
import Combine

private enum PlayerTitleKeys {
    static let unlocked = "player.titles.unlocked.v1"
    static let override = "player.titles.override.v1"
    static let base = "player.titles.base.v1"
}

final class PlayerTitleStore: ObservableObject {
    @Published private(set) var unlockedTitles: Set<String>
    @Published private(set) var equippedOverrideTitle: String?
    @Published private(set) var baseLevelTitle: String?

    private let userDefaults: UserDefaults

    var activeTitle: String? {
        equippedOverrideTitle ?? baseLevelTitle
    }

    init(
        unlockedTitles: Set<String> = [],
        equippedOverrideTitle: String? = nil,
        baseLevelTitle: String? = nil,
        userDefaults: UserDefaults = .standard
    ) {
        self.userDefaults = userDefaults

        if let data = userDefaults.data(forKey: PlayerTitleKeys.unlocked),
           let decoded = try? JSONDecoder().decode([String].self, from: data) {
            self.unlockedTitles = Set(decoded)
        } else {
            self.unlockedTitles = unlockedTitles
        }

        self.equippedOverrideTitle = userDefaults.string(forKey: PlayerTitleKeys.override) ?? equippedOverrideTitle
        self.baseLevelTitle = userDefaults.string(forKey: PlayerTitleKeys.base) ?? baseLevelTitle
    }

    func unlock(title: String) {
        unlockedTitles.insert(title)
        persist()
    }

    func equipOverride(title: String) {
        guard unlockedTitles.contains(title) || title == baseLevelTitle else { return }
        equippedOverrideTitle = title
        persist()
    }

    func clearOverride() {
        equippedOverrideTitle = nil
        persist()
    }

    func updateBaseLevelTitle(_ title: String) {
        baseLevelTitle = title
        persist()
    }

    private func persist() {
        let unlockedArray = Array(unlockedTitles)
        if let data = try? JSONEncoder().encode(unlockedArray) {
            userDefaults.set(data, forKey: PlayerTitleKeys.unlocked)
        }
        userDefaults.set(equippedOverrideTitle, forKey: PlayerTitleKeys.override)
        userDefaults.set(baseLevelTitle, forKey: PlayerTitleKeys.base)
    }
}
