import SwiftUI

enum MainTab: Hashable {
    case focus, health, quests, stats, more
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
        ZStack(alignment: .top) {
            TabView(selection: $selectedTab) {
                FocusView(
                    viewModel: focusViewModel,
                    healthBarViewModel: healthBarViewModel,
                    selectedTab: $selectedTab
                )
                .environmentObject(questsViewModel)
                .tabItem { Label("Focus", systemImage: "timer") }
                .tag(MainTab.focus)

                HealthBarView(
                    viewModel: healthBarViewModel,
                    focusViewModel: focusViewModel,
                    selectedTab: $selectedTab
                )
                    .environmentObject(questsViewModel)
                    .tabItem { Label("HP", systemImage: "heart.fill") }
                    .tag(MainTab.health)

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

            if let event = focusViewModel.activeReminderEvent,
               let message = focusViewModel.activeReminderMessage {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: focusViewModel.reminderIconName(for: event.type))
                        .imageScale(.large)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(focusViewModel.reminderTitle(for: event.type))
                            .font(.headline)
                        Text(message)
                            .font(.subheadline)
                    }

                    Spacer()

                    if event.type == .hydration {
                        Button("Took a sip") {
                            focusViewModel.logHydrationSip()
                            focusViewModel.acknowledgeReminder(event)
                        }
                    } else {
                        Button("Fixed it") {
                            focusViewModel.acknowledgeReminder(event)
                        }
                    }
                }
                .padding(12)
                .background(Color(uiColor: .secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(radius: 8)
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(1)
                .animation(.spring(), value: focusViewModel.activeReminderEvent != nil)
                .gesture(
                    DragGesture().onEnded { value in
                        if value.translation.height < -20 {
                            focusViewModel.acknowledgeReminder(event)
                        }
                    }
                )
            }
        }
    }
}

#Preview {
    ContentView()
}
