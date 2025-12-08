import Foundation
import Combine

final class TalentTreeStore: ObservableObject {
    @Published private(set) var nodes: [TalentNode]
    @Published private(set) var currentRanks: [String: Int]
    @Published private(set) var totalPoints: Int
    @Published private(set) var spentPoints: Int
    @Published private(set) var currentLevel: Int  // external code can adjust this later

    // MARK: - Persistence
    private let userDefaults: UserDefaults
    private let ranksKey = "talentTree.currentRanks.v1"
    private let levelKey = "talentTree.currentLevel.v1"

    private func prerequisitesSatisfied(for node: TalentNode) -> Bool {
        guard !node.prerequisiteIDs.isEmpty else { return true }
        for prereqID in node.prerequisiteIDs {
            // Find the prerequisite node to know its maxRanks
            guard let prereqNode = nodes.first(where: { $0.id == prereqID }) else { return false }
            let rank = currentRanks[prereqID] ?? 0
            if rank < prereqNode.maxRanks { return false } // must be fully maxed (e.g., 5/5 or 3/3)
        }
        return true
    }

    init(
        nodes: [TalentNode] = TalentTreeConfig.defaultNodes,
        currentRanks: [String: Int] = [:],
        currentLevel: Int = 1,
        userDefaults: UserDefaults = .standard
    ) {
        self.nodes = nodes
        self.currentRanks = currentRanks
        self.totalPoints = 0
        self.spentPoints = currentRanks.values.reduce(0, +)
        self.currentLevel = currentLevel
        self.userDefaults = userDefaults

        // Load previously saved state first to avoid wiping ranks on launch.
        loadState()
        recalculateSpentPoints()

        // Ensure total points reflect the current (possibly loaded) level.
        applyLevel(self.currentLevel)
    }

    /// 1 talent point per level. Later we can clamp or adjust if needed.
    var pointsEarned: Int {
        totalPoints
    }

    var pointsSpent: Int {
        spentPoints
    }

    var availablePoints: Int {
        max(totalPoints - spentPoints, 0)
    }

    func rank(for node: TalentNode) -> Int {
        currentRanks[node.id] ?? 0
    }

    /// Checks tier requirement + prereqs + rank cap + available points.
    func canSpendPoint(on node: TalentNode) -> Bool {
        // No points left or already maxed
        guard availablePoints > 0 else { return false }
        let current = rank(for: node)
        guard current < node.maxRanks else { return false }

        // Tier requirement: tier 1 = 0, tier 2 = 5, tier 3 = 10, tier 4 = 15, tier 5 = 20
        let requiredPoints = max((node.tier - 1) * 5, 0)
        guard spentPoints >= requiredPoints else { return false }

        guard prerequisitesSatisfied(for: node) else { return false }

        return true
    }

    /// Attempts to spend a point into the provided node.
    func spendPoint(on node: TalentNode) {
        guard canSpendPoint(on: node) else { return }
        let current = rank(for: node)
        currentRanks[node.id] = current + 1
        recalculateSpentPoints()
        saveIfNeeded()
    }

    func applyLevel(_ level: Int) {
        let maxPoints = nodes.reduce(0) { $0 + $1.maxRanks }
        let newTotalPoints = min(max(level, 0), maxPoints)

        currentLevel = level
        if newTotalPoints != totalPoints {
            totalPoints = newTotalPoints
            if spentPoints > totalPoints {
                currentRanks = [:]
                recalculateSpentPoints()
            }
        }
        saveIfNeeded()
    }

    func respecAll() {
        currentRanks = [:]
        spentPoints = 0
        saveIfNeeded()
    }

    private func recalculateSpentPoints() {
        spentPoints = currentRanks.values.reduce(0, +)
    }

    private func loadState() {
        if let data = userDefaults.data(forKey: ranksKey),
           let decoded = try? JSONDecoder().decode([String: Int].self, from: data) {
            currentRanks = decoded
        }
        if userDefaults.object(forKey: levelKey) != nil {
            let savedLevel = userDefaults.integer(forKey: levelKey)
            if savedLevel > 0 { currentLevel = savedLevel }
        }
    }

    private func saveIfNeeded() {
        if let data = try? JSONEncoder().encode(self.currentRanks) {
            userDefaults.set(data, forKey: ranksKey)
        }
        userDefaults.set(self.currentLevel, forKey: levelKey)
    }
}
