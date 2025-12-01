import Foundation

/// A simple container responsible for building view models.
/// This can later be expanded to manage shared services and dependencies.
final class DependencyContainer {
    static let shared = DependencyContainer()
    private init() {}

    func makeFocusViewModel() -> FocusViewModel {
        FocusViewModel()
    }
}
