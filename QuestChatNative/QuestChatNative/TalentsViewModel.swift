import Foundation
import Combine

final class TalentsViewModel: ObservableObject {
    @Published private(set) var nodes: [TalentNode] = []
    @Published private(set) var currentRanks: [String: Int] = [:]
    @Published private(set) var availablePoints: Int = 0
    @Published private(set) var pointsSpent: Int = 0
    @Published private(set) var level: Int = 1
    @Published var selectedTalent: TalentNode?
    @Published var isShowingDetail: Bool = false

    private let store: TalentTreeStore
    private let statsStore: SessionStatsStore
    private var cancellables = Set<AnyCancellable>()

    init(store: TalentTreeStore, statsStore: SessionStatsStore) {
        self.store = store
        self.statsStore = statsStore

        // Seed initial values
        refreshFromStore()
        level = statsStore.level

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
            .receive(on: DispatchQueue.main)
            .assign(to: &$level)
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

    func tap(node: TalentNode) {
        store.spendPoint(on: node)
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
