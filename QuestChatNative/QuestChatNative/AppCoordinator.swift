import SwiftUI

/// Coordinates top-level view construction using the dependency container.
final class AppCoordinator {
    private let container: DependencyContainer

    init(container: DependencyContainer = .shared) {
        self.container = container
    }

    func makeFocusView(selectedTab: Binding<MainTab>) -> FocusView {
        FocusView(
            viewModel: container.focusViewModel,
            healthBarViewModel: container.healthBarViewModel,
            selectedTab: selectedTab
        )
    }
}
