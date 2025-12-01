import SwiftUI

enum MainTab: Hashable {
    case focus, quests, stats, more
}

struct ContentView: View {
    @State private var selectedTab: MainTab = .focus
    @StateObject private var statsStore = DependencyContainer.shared.makeStatsStore()
    @StateObject private var questsViewModel = DependencyContainer.shared.makeQuestsViewModel()

    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                FocusView(
                    viewModel: DependencyContainer.shared.makeFocusViewModel(),
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

            if let levelUp = statsStore.pendingLevelUp {
                LevelUpModalView(level: levelUp) {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        statsStore.pendingLevelUp = nil
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .background(Color.black.opacity(0.75).ignoresSafeArea())
                .transition(
                    .asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 1.05)),
                        removal: .opacity.combined(with: .scale(scale: 0.96))
                    )
                )
                .zIndex(1)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: statsStore.pendingLevelUp)
    }
}

#Preview {
    ContentView()
}
