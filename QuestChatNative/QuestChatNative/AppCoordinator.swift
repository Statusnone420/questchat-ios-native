import SwiftUI

/// Coordinates top-level view construction using the dependency container.
final class AppCoordinator {
    private let container: DependencyContainer

    private lazy var focusViewModel = container.makeFocusViewModel()
    private lazy var healthBarViewModel = container.makeHealthBarViewModel()

    init(container: DependencyContainer = .shared) {
        self.container = container
    }

    func makeFocusView(selectedTab: Binding<MainTab>) -> FocusView {
        FocusView(
            viewModel: focusViewModel,
            healthBarViewModel: healthBarViewModel,
            selectedTab: selectedTab
        )
    }
}
