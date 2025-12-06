import Foundation
import Combine

final class TalentTreeStore: ObservableObject {
    @Published private(set) var nodes: [TalentNode]
    @Published private(set) var currentRanks: [String: Int]
    @Published var currentLevel: Int  // external code can adjust this later

    init(
        nodes: [TalentNode] = TalentTreeConfig.defaultNodes,
        currentRanks: [String: Int] = [:],
        currentLevel: Int = 1
    ) {
        self.nodes = nodes
        self.currentRanks = currentRanks
        self.currentLevel = currentLevel
    }

    /// 1 talent point per level. Later we can clamp or adjust if needed.
    var pointsEarned: Int {
        max(currentLevel, 0)
    }

    var pointsSpent: Int {
        currentRanks.values.reduce(0, +)
    }

    var availablePoints: Int {
        max(pointsEarned - pointsSpent, 0)
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
        guard pointsSpent >= requiredPoints else { return false }

        // Prerequisites must exist and be at max rank
        for prereqID in node.prerequisiteIDs {
            guard let prereqNode = nodes.first(where: { $0.id == prereqID }) else { return false }
            let prereqRank = currentRanks[prereqID] ?? 0
            guard prereqRank >= prereqNode.maxRanks else { return false }
        }

        return true
    }

    /// Attempts to spend a point into the provided node.
    func spendPoint(on node: TalentNode) {
        guard canSpendPoint(on: node) else { return }
        let current = rank(for: node)
        currentRanks[node.id] = current + 1
    }
}
