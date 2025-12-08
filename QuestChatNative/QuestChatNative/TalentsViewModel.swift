import Foundation
import Combine
import UIKit

final class TalentsViewModel: ObservableObject {
    @Published private(set) var nodes: [TalentNode] = []
    @Published private(set) var currentRanks: [String: Int] = [:]
    @Published private(set) var availablePoints: Int = 0
    @Published private(set) var pointsSpent: Int = 0
    @Published private(set) var level: Int = 1
    @Published var selectedTalent: TalentNode?
    @Published var isShowingDetail: Bool = false
    @Published var masteryPulseID: String?

    private let store: TalentTreeStore
    private let statsStore: SessionStatsStore
    private var cancellables = Set<AnyCancellable>()

    init(store: TalentTreeStore, statsStore: SessionStatsStore) {
        self.store = store
        self.statsStore = statsStore

        // Seed initial values
        refreshFromStore()
        level = statsStore.level
        self.store.applyLevel(self.level)

        // Keep view model in sync with the store
        store.$nodes
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.nodes = $0 }
            .store(in: &cancellables)

        store.$currentRanks
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refreshFromStore() }
            .store(in: &cancellables)

        store.$totalPoints
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refreshFromStore() }
            .store(in: &cancellables)

        statsStore.$progression
            .map { $0.level }
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newLevel in
                guard let self = self else { return }
                self.level = newLevel
                self.store.applyLevel(newLevel)
            }
            .store(in: &cancellables)
    }

    // How many mastered nodes the player has
    var masteredCount: Int {
        nodes.filter { rank(for: $0) >= $0.maxRanks }.count
    }

    /// Simple tier to drive background aura intensity.
    var masteryTier: Int {
        switch masteredCount {
        case 0...3: return 0      // no aura
        case 4...9: return 1      // soft aura
        default: return 2         // stronger aura
        }
    }

    /// Total possible talent ranks in the tree
    var totalTalentRanks: Int {
        nodes.reduce(0) { $0 + $1.maxRanks }
    }

    /// How many ranks the player has actually put in
    var masteredTalentRanks: Int {
        nodes.reduce(0) { partial, node in
            partial + rank(for: node)
        }
    }

    /// 1–10, based on how many talents are fully mastered (every 2 mastered = +1 stage)
    var treeStage: Int {
        let stageFromMastery = masteredCount / 2 // 0..10
        return min(max(stageFromMastery + 1, 1), 10)
    }

    func rank(for node: TalentNode) -> Int {
        currentRanks[node.id] ?? 0
    }

    func canSpend(on node: TalentNode) -> Bool {
        store.canSpendPoint(on: node)
    }

    func isUnlocked(_ node: TalentNode) -> Bool {
        // Consider a node "unlocked" if it has at least 1 rank
        // or if it is currently eligible to be spent in.
        rank(for: node) > 0 || canSpend(on: node)
    }

    func incrementRank(for node: TalentNode) {
        let previousRank = rank(for: node)
        store.spendPoint(on: node)
        let newRank = store.rank(for: node)

        if previousRank < node.maxRanks && newRank == node.maxRanks {
            masteryPulseID = node.id
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        }
    }

    func respecAllTalents() {
        store.respecAll()
        refreshFromStore()
    }

    private func refreshFromStore() {
        nodes = store.nodes
        currentRanks = store.currentRanks
        availablePoints = store.availablePoints
        pointsSpent = store.pointsSpent
    }
}
