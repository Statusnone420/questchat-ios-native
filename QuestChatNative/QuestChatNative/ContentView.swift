import SwiftUI
import UIKit

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
    @AppStorage("showMiniFocusFAB") private var showMiniFocusFAB: Bool = true
    @AppStorage("miniFABOffsetX") private var miniFABOffsetX: Double = 0
    @AppStorage("miniFABOffsetY") private var miniFABOffsetY: Double = 0
    @State private var miniTimerOffset: CGSize = .zero
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
                    .tabItem { Label("Player", systemImage: "person.crop.circle.dashed") }
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
                        Image(systemName: "tree.fill")
                        Text("Talents")
                    }
                    .tag(MainTab.talents)
            }
            .preferredColorScheme(.dark)
            .tint(.mint)
            .background(Color.black)
            
            if let levelUp = statsStore.pendingLevelUp {
                LevelUpModalView(
                    levelUp: levelUp,
                    onDismiss: {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            statsStore.pendingLevelUp = nil
                        }
                    },
                    onOpenTalents: {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            selectedTab = .talents
                            statsStore.pendingLevelUp = nil
                        }
                    }
                )
                .zIndex(100)
                .transition(.opacity.combined(with: .scale))
            }
            
            // 🎮 COMBO CELEBRATION (app-wide for timer combos!)
            if let combo = questsViewModel.comboCelebration {
                comboCelebrationOverlay(combo: combo)
                    .padding(.top, 100)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(99)
            }
            
            // Mini Focus Timer FAB overlay on all tabs
            if showMiniFocusFAB, focusViewModel.state == .running || focusViewModel.state == .paused, focusViewModel.remainingSeconds > 0 {
                VStack { Spacer() }
                    .overlay(
                        MiniFocusTimerFAB(
                            viewModel: focusViewModel,
                            selectedTab: $selectedTab,
                            dragOffset: $miniTimerOffset
                        )
                        .padding(.trailing, 16)
                        .padding(.bottom, 24),
                        alignment: .bottomTrailing
                    )
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                    .zIndex(20)
            }
            
            // Global session-complete toast (appears on any tab)
            // REMOVED PER INSTRUCTIONS
            
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: questsViewModel.comboCelebration != nil)
        .animation(.easeInOut(duration: 0.25), value: focusViewModel.lastCompletedSession?.timestamp)
        .onReceive(NotificationCenter.default.publisher(for: .openTalentsTabRequested)) { _ in
            withAnimation(.easeInOut(duration: 0.25)) {
                selectedTab = .talents
                statsStore.pendingLevelUp = nil
            }
        }
        .animation(.easeInOut(duration: 0.3), value: statsStore.pendingLevelUp != nil)
        .safeAreaInset(edge: .top) {
            if let event = focusViewModel.activeReminderEvent,
               let message = focusViewModel.activeReminderMessage {
                VStack(spacing: 0) {
                    HStack(alignment: .top, spacing: 14) {
                        // Icon with colored background
                        ZStack {
                            Circle()
                                .fill(
                                    event.type == .hydration
                                        ? Color.cyan.opacity(0.2)
                                        : Color.purple.opacity(0.2)
                                )
                                .frame(width: 44, height: 44)
                            
                            Image(systemName: focusViewModel.reminderIconName(for: event.type))
                                .font(.system(size: 22))
                                .foregroundStyle(
                                    event.type == .hydration
                                        ? Color.cyan
                                        : Color.purple
                                )
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text(focusViewModel.reminderTitle(for: event.type))
                                .font(.headline.weight(.bold))
                                .foregroundStyle(.primary)
                            Text(message)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        // Action button
                        Button {
                            if event.type == .hydration {
                                focusViewModel.logHydrationSip()
                                focusViewModel.showSipFeedback("+1 oz")
                            }
                            focusViewModel.acknowledgeReminder(event)
                        } label: {
                            Text(event.type == .hydration ? "Took a sip" : "Fixed it")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.black)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(
                                    event.type == .hydration
                                        ? Color.cyan
                                        : Color.purple
                                )
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color(uiColor: .secondarySystemBackground))
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(
                                        LinearGradient(
                                            colors: event.type == .hydration
                                                ? [Color.cyan.opacity(0.5), Color.cyan.opacity(0.2)]
                                                : [Color.purple.opacity(0.5), Color.purple.opacity(0.2)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1.5
                                    )
                            )
                    )
                    .shadow(color: Color.black.opacity(0.3), radius: 12, x: 0, y: 6)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .overlay(alignment: .topTrailing) {
                        if let feedback = focusViewModel.sipFeedback {
                            SipFeedbackOverlay(text: feedback)
                                .transition(.move(edge: .top).combined(with: .opacity))
                                .padding(.top, -8)
                                .padding(.trailing, 20)
                        }
                    }
                    
                    // Swipe indicator
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.up")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("Swipe up to dismiss")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 4)
                    .padding(.bottom, 8)
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
        .safeAreaInset(edge: .bottom) {
            Group {
                if let session = focusViewModel.lastCompletedSession {
                    SessionCompleteToast(
                        xpGained: session.xpGained,
                        minutes: session.duration / 60,
                        label: sessionLabel(forMinutes: session.duration / 60),
                        onOpenFocus: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedTab = .focus
                                focusViewModel.lastCompletedSession = nil
                            }
                        }
                    )
                    .padding(.horizontal, 16)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(50)
                    .highPriorityGesture(
                        DragGesture(minimumDistance: 20)
                            .onEnded { value in
                                let dx = abs(value.translation.width)
                                let dy = abs(value.translation.height)
                                if dx > 60 || dy > 40 {
                                    withAnimation {
                                        focusViewModel.lastCompletedSession = nil
                                    }
                                }
                            }
                    )
                    .onAppear {
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) {
                            withAnimation {
                                focusViewModel.lastCompletedSession = nil
                            }
                        }
                    }
                }
            }
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            focusViewModel.updateScenePhase(newPhase)
        }
        .onAppear {
            focusViewModel.updateScenePhase(scenePhase)
            // Restore saved FAB offset
            miniTimerOffset = CGSize(width: miniFABOffsetX, height: miniFABOffsetY)
        }
        .onChange(of: miniTimerOffset) { oldValue, newValue in
            miniFABOffsetX = newValue.width
            miniFABOffsetY = newValue.height
        }
    }
    
    private func sessionLabel(forMinutes minutes: Int) -> String {
        switch minutes {
        case 0..<10:
            return "Quick focus run"
        case 10..<25:
            return "Focus session"
        default:
            return "Deep Focus"
        }
    }
    
    /// 🎮 Combo celebration overlay - epic full-width gaming-style popup!
    @ViewBuilder
    func comboCelebrationOverlay(combo: ComboCelebration) -> some View {
        VStack(spacing: 16) {
            // Epic title with gradient
            Text(combo.title)
                .font(.system(size: 42, weight: .black, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.orange, .red, .pink],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .shadow(color: .red.opacity(0.8), radius: 12, x: 0, y: 4)
                .multilineTextAlignment(.center)
            
            // Subtitle
            Text(combo.subtitle)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            
            // XP Reward
            HStack(spacing: 8) {
                Image(systemName: "star.fill")
                    .font(.title2)
                    .foregroundStyle(.yellow)
                Text("+\(combo.xpAmount) XP")
                    .font(.title.bold())
                    .foregroundStyle(.yellow)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(.black.opacity(0.7))
                    .overlay(
                        Capsule()
                            .stroke(Color.yellow.opacity(0.9), lineWidth: 3)
                    )
            )
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
        .padding(.vertical, 32)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.black.opacity(0.92))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [.orange, .red, .pink],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 4
                        )
                )
        )
        .padding(.horizontal, 16)
        .shadow(color: .orange.opacity(0.8), radius: 30, x: 0, y: 12)
        .scaleEffect(1.0)
        .animation(.spring(response: 0.4, dampingFraction: 0.6), value: combo.id)
        .onAppear {
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppCoordinator())
}

