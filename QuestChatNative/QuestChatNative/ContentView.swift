import SwiftUI

enum MainTab: Hashable {
    case focus, quests, stats, more
}

struct ContentView: View {
    @State private var selectedTab: MainTab = .focus
    @StateObject private var statsStore = DependencyContainer.shared.makeStatsStore()
    @StateObject private var questsViewModel = DependencyContainer.shared.makeQuestsViewModel()
    private let appCoordinator = AppCoordinator()

    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                appCoordinator.makeFocusView(selectedTab: $selectedTab)
                    .environmentObject(questsViewModel)
                    .tabItem { Label("Focus", systemImage: "timer") }
                    .tag(MainTab.focus)

                QuestsView(viewModel: questsViewModel)
                    .tabItem { Label("Quests", systemImage: "list.bullet.rectangle") }
                    .tag(MainTab.quests)

                StatsView(
                    store: statsStore,
                    questsViewModel: questsViewModel
                )
                    .tabItem { Label("Stats", systemImage: "chart.bar.xaxis") }
                    .tag(MainTab.stats)

                MoreView()
                    .tabItem { Label("More", systemImage: "ellipsis.circle") }
                    .tag(MainTab.more)
            }
            .preferredColorScheme(.dark)
            .tint(.mint)
            .background(Color.black)
        }
    }
}

#Preview {
    ContentView()
}
