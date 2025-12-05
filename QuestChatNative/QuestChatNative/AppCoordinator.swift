import SwiftUI
import Combine

/// Coordinates top-level view construction using the dependency container.
final class AppCoordinator: ObservableObject {
    @Published private(set) var hasCompletedOnboarding: Bool

    private let container: DependencyContainer
    private var onboardingViewModel: OnboardingViewModel?

    init(container: DependencyContainer = .shared, userDefaults: UserDefaults = .standard) {
        self.container = container
        hasCompletedOnboarding = userDefaults.bool(forKey: OnboardingViewModel.Keys.hasCompletedOnboarding)
    }

    @ViewBuilder
    func makeRootView() -> some View {
        if self.hasCompletedOnboarding {
            ContentView()
        } else {
            OnboardingView(viewModel: self.resolveOnboardingViewModel())
        }
    }

    func makeFocusView(selectedTab: Binding<MainTab>) -> FocusView {
        FocusView(
            viewModel: container.focusViewModel,
            healthBarViewModel: container.healthBarViewModel,
            selectedTab: selectedTab
        )
    }

    private func resolveOnboardingViewModel() -> OnboardingViewModel {
        let viewModel = onboardingViewModel ?? container.makeOnboardingViewModel(onCompletion: { [weak self] in
            self?.markOnboardingComplete()
        })
        onboardingViewModel = viewModel
        return viewModel
    }

    private func markOnboardingComplete() {
        hasCompletedOnboarding = true
    }
}

