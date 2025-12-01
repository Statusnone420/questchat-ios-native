import Foundation

/// A simple container responsible for building view models.
/// This can later be expanded to manage shared services and dependencies.
final class DependencyContainer {
    static let shared = DependencyContainer()
    private init() {}

    private let statsStore = SessionStatsStore()
    private lazy var questsViewModel = QuestsViewModel(statsStore: statsStore)

    func makeFocusViewModel() -> FocusViewModel {
        FocusViewModel(statsStore: statsStore)
    }

    func makeHealthBarViewModel() -> HealthBarViewModel {
        HealthBarViewModel()
    }

    func makeStatsStore() -> SessionStatsStore {
        statsStore
    }

    func makeQuestsViewModel() -> QuestsViewModel {
        questsViewModel
    }
}
