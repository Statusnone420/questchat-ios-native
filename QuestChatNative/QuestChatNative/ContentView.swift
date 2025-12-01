import SwiftUI

enum MainTab: Hashable {
    case focus, quests, stats, more
}

struct ContentView: View {
    @State private var selectedTab: MainTab = .focus

    var body: some View {
        TabView(selection: $selectedTab) {
            FocusView(viewModel: DependencyContainer.shared.makeFocusViewModel())
                .tabItem { Label("Focus", systemImage: "timer") }
                .tag(MainTab.focus)

            QuestsView()
                .tabItem { Label("Quests", systemImage: "list.bullet.rectangle") }
                .tag(MainTab.quests)

            StatsView()
                .tabItem { Label("Stats", systemImage: "chart.bar.xaxis") }
                .tag(MainTab.stats)

            MoreView()
                .tabItem { Label("More", systemImage: "ellipsis.circle") }
                .tag(MainTab.more)
        }
    }
}

#Preview {
    ContentView()
}
