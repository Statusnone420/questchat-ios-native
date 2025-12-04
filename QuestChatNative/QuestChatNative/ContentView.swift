import SwiftUI

enum MainTab: Hashable {
    case focus, quests, stats, more
}

struct ContentView: View {
    @State private var selectedTab: MainTab = .focus
    @StateObject private var statsStore = DependencyContainer.shared.sessionStatsStore
    @StateObject private var healthStatsViewModel = DependencyContainer.shared.statsViewModel
    @StateObject private var healthBarViewModel = DependencyContainer.shared.healthBarViewModel
    @StateObject private var focusViewModel = DependencyContainer.shared.focusViewModel
    @StateObject private var questsViewModel = DependencyContainer.shared.questsViewModel
    @StateObject private var moreViewModel = DependencyContainer.shared.moreViewModel

    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                FocusView(
                    viewModel: focusViewModel,
                    healthBarViewModel: healthBarViewModel,
                    selectedTab: $selectedTab
                )
                .environmentObject(questsViewModel)
                .tabItem { Label("Focus", systemImage: "timer") }
                .tag(MainTab.focus)

                QuestsView(viewModel: questsViewModel)
                    .tabItem { Label("Quests", systemImage: "list.bullet.rectangle") }
                    .tag(MainTab.quests)

                StatsView(
                    store: statsStore,
                    viewModel: healthStatsViewModel,
                    questsViewModel: questsViewModel,
                    healthBarViewModel: healthBarViewModel,
                    focusViewModel: focusViewModel
                )
                    .tabItem { Label("Stats", systemImage: "chart.bar.xaxis") }
                    .tag(MainTab.stats)

                MoreView(viewModel: moreViewModel)
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
