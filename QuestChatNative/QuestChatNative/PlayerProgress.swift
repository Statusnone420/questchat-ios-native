import Foundation

struct PlayerProgress: Codable {
    private(set) var totalXP: Int

    init(totalXP: Int = 0) {
        self.totalXP = totalXP
    }

    // 100 XP per level
    var level: Int {
        totalXP / 100
    }

    var xpIntoCurrentLevel: Int {
        totalXP % 100
    }

    mutating func addXP(_ amount: Int) {
        guard amount > 0 else { return }
        totalXP &+= amount
    }
}
