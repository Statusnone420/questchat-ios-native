import Foundation
import Combine

final class TalentsViewModel: ObservableObject {
    @Published private(set) var nodes: [TalentNode] = []
    @Published private(set) var currentRanks: [String: Int] = [:]
    @Published private(set) var availablePoints: Int = 0
    @Published private(set) var pointsSpent: Int = 0
    @Published private(set) var level: Int = 1

    private let store: TalentTreeStore
    private let statsStore: SessionStatsStore
    private var cancellables = Set<AnyCancellable>()

    init(store: TalentTreeStore, statsStore: SessionStatsStore) {
        self.store = store
        self.statsStore = statsStore

        // Seed initial values
        nodes = store.nodes
        currentRanks = store.currentRanks
        availablePoints = store.availablePoints
        pointsSpent = store.pointsSpent
        level = statsStore.level

        // Keep view model in sync with the store
        store.$nodes
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.nodes = $0 }
            .store(in: &cancellables)

        store.$currentRanks
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.currentRanks = self.store.currentRanks
                self.pointsSpent = self.store.pointsSpent
                self.availablePoints = self.store.availablePoints
            }
            .store(in: &cancellables)

        store.$totalPoints
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.availablePoints = self.store.availablePoints
            }
            .store(in: &cancellables)

        statsStore.$progression
            .map { $0.level }
            .receive(on: DispatchQueue.main)
            .assign(to: &$level)
    }

    func rank(for node: TalentNode) -> Int {
        store.rank(for: node)
    }

    func canSpend(on node: TalentNode) -> Bool {
        store.canSpendPoint(on: node)
    }

    func isUnlocked(_ node: TalentNode) -> Bool {
        // Consider a node "unlocked" if it has at least 1 rank
        // or if it is currently eligible to be spent in.
        rank(for: node) > 0 || canSpend(on: node)
    }

    func tap(node: TalentNode) {
        store.spendPoint(on: node)
    }
}
