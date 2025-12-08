import SwiftUI

private struct SipFeedbackOverlay: View {
    let text: String
    @State private var animate = false

    var body: some View {
        Text(text)
            .font(.caption.bold())
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.cyan.opacity(0.2))
            .foregroundStyle(.cyan)
            .clipShape(Capsule())
            .offset(y: animate ? -24 : 0)
            .opacity(animate ? 0 : 1)
            .onAppear {
                withAnimation(.easeOut(duration: 0.5)) {
                    animate = true
                }
            }
    }
}

enum MainTab: Hashable {
    case focus, health, quests, stats, talents
}

struct ContentView: View {
    @EnvironmentObject private var appCoordinator: AppCoordinator
    @State private var selectedTab: MainTab = .focus
    @StateObject private var statsStore = DependencyContainer.shared.sessionStatsStore
    @StateObject private var healthStatsViewModel = DependencyContainer.shared.statsViewModel
    @StateObject private var healthBarViewModel = DependencyContainer.shared.healthBarViewModel
    @StateObject private var focusViewModel = DependencyContainer.shared.focusViewModel
    @StateObject private var questsViewModel = DependencyContainer.shared.questsViewModel
    @Environment(\.scenePhase) private var scenePhase

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
                    statsStore: statsStore,
                    statsViewModel: healthStatsViewModel,
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

                appCoordinator.makeTalentsView()
                    .tabItem {
                        Image(systemName: "wand.and.stars")
                        Text("Talents")
                    }
                    .tag(MainTab.talents)
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
                .zIndex(100)
                .transition(.opacity.combined(with: .scale))
            }
        }
        .safeAreaInset(edge: .top) {
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
                            focusViewModel.showSipFeedback("+1 oz")
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
                .overlay(alignment: .topTrailing) {
                    if let feedback = focusViewModel.sipFeedback {
                        SipFeedbackOverlay(text: feedback)
                            .transition(.move(edge: .top).combined(with: .opacity))
                            .padding(.top, -8)
                    }
                }
                .gesture(
                    DragGesture(minimumDistance: 20)
                        .onEnded { value in
                            // Swipe up to dismiss
                            if value.translation.height < -50 {
                                focusViewModel.dismissReminder()
                            }
                        }
                )
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(10)
            }
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            focusViewModel.updateScenePhase(newPhase)
        }
        .onAppear {
            focusViewModel.updateScenePhase(scenePhase)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppCoordinator())
}
