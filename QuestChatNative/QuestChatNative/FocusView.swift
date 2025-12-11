import SwiftUI
import UIKit
import Lottie

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

struct FocusView: View {
    @StateObject var viewModel: FocusViewModel
    @ObservedObject var healthBarViewModel: HealthBarViewModel
    @ObservedObject private var statsStore: SessionStatsStore
    @EnvironmentObject var questsViewModel: QuestsViewModel
    @Environment(\.scenePhase) private var scenePhase
    @Binding var selectedTab: MainTab

    @State private var primaryButtonScale: CGFloat = 1
    @State private var resetButtonScale: CGFloat = 1
    @State private var heroCardScale: CGFloat = 0.98
    @State private var heroCardOpacity: Double = 0.92
    @State private var isShowingSettings = false
    @State private var focusRingsTrigger = UUID()
    @State private var momentumWaveTrigger = UUID()
    @State private var showDurationPreviewPill = false

    @Namespace private var categoryAnimation

    private var selectedDurationInSeconds: Int {
        viewModel.durationForSelectedCategory()
    }

    private var formattedTime: String {
        let minutes = viewModel.remainingSeconds / 60
        let seconds = viewModel.remainingSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private var warningFraction: Double {
        guard viewModel.remainingSeconds <= 10 else { return 0 }
        let fraction = 1 - (Double(viewModel.remainingSeconds) / 10)
        return min(max(fraction, 0), 1)
    }

    private var ringColors: [Color] {
        let base = [Color.mint, Color.cyan, Color.mint]
        let warning = [Color.orange, Color.red, Color.orange]
        return zip(base, warning).map { baseColor, warningColor in
            baseColor.blended(withFraction: warningFraction, of: warningColor)
        }
    }

    private var focusMinutesToday: Int { statsStore.focusSecondsToday / 60 }
    private var selfCareMinutesToday: Int { statsStore.selfCareSecondsToday / 60 }
    private var dailyFocusTarget: Int { statsStore.dailyMinutesGoal ?? 40 }

    private var questSummaryText: String {
        QuestChatStrings.FocusView.questProgress(completed: questsViewModel.completedQuestsCount, total: questsViewModel.totalQuestsCount)
    }

    private var minutesSummaryText: String {
        QuestChatStrings.FocusView.minutesProgress(totalMinutes: focusMinutesToday + selfCareMinutesToday, targetMinutes: dailyFocusTarget)
    }

    private var streakSummaryText: String {
        let days = statsStore.currentStreakDays
        return QuestChatStrings.FocusView.streakProgress(days: days)
    }

    private var momentumLabel: String { statsStore.momentumLabel() }

    private var momentumDescription: String { statsStore.momentumDescription() }

    private var momentumProgress: Double {
        let normalized = (statsStore.momentumMultiplier() - 1.0) / 0.20
        return min(max(normalized, 0), 1)
    }

    init(viewModel: FocusViewModel, healthBarViewModel: HealthBarViewModel, selectedTab: Binding<MainTab>) {
        _viewModel = StateObject(wrappedValue: viewModel)
        _healthBarViewModel = ObservedObject(wrappedValue: healthBarViewModel)
        _selectedTab = selectedTab
        _statsStore = ObservedObject(wrappedValue: viewModel.statsStore)

        viewModel.onSessionComplete = { [weak healthBarViewModel] in
            healthBarViewModel?.logFocusSession()
        }
    }

    var body: some View {
        ZStack(alignment: .top) {
            NavigationStack {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 20) {
                        compactStatusHeader
                        momentumCard

                        if let selectedCategory = viewModel.selectedCategoryData {
                            activeTimerSection(for: selectedCategory)
                        }

                        quickTimersList

                        reminderCard

                        bottomActionsSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
                .scrollBounceBehavior(.basedOnSize)
                .background(Color.black.ignoresSafeArea())
                .toolbar(.hidden, for: .navigationBar)
            }
        }
        .onAppear {
            viewModel.handleAppear()
            viewModel.handleScenePhaseChange(scenePhase)
        }
        .animation(.easeInOut(duration: 0.25), value: viewModel.lastCompletedSession?.timestamp)
        .animation(.spring(), value: viewModel.activeReminderEvent != nil)
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: viewModel.selectedCategory)
        .onChange(of: scenePhase) {
            viewModel.handleScenePhaseChange(scenePhase)
        }
        .onChange(of: viewModel.selectedCategory) {
            // Skip animations during Live Activity restoration
            guard !viewModel.isRestoringFromLiveActivity else { return }
            
            heroCardScale = 0.98
            heroCardOpacity = 0.92
            withAnimation(.spring(response: 0.45, dampingFraction: 0.78)) {
                heroCardScale = 1
                heroCardOpacity = 1
            }
        }
        .sheet(isPresented: $viewModel.isShowingDurationPicker) {
            durationPickerSheet()
                .presentationDetents([.height(400)])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $isShowingSettings) {
            SettingsView(
                viewModel: DependencyContainer.shared.settingsViewModel,
                moreViewModel: DependencyContainer.shared.moreViewModel
            )
        }
        .sheet(
            isPresented: Binding(
                get: { statsStore.shouldShowDailySetup },
                set: { statsStore.shouldShowDailySetup = $0 }
            )
        ) {
            DailySetupSheet(
                initialFocusArea: statsStore.todayPlan?.focusArea ?? .work,
                initialEnergyLevel: statsStore.todayPlan?.energyLevel ?? .medium
            ) { focusArea, energyLevel in
                statsStore.completeDailyConfig(focusArea: focusArea, energyLevel: energyLevel)
                questsViewModel.markCoreQuests(for: focusArea)
            }
            .presentationDetents([.medium])
            .interactiveDismissDisabled(statsStore.todayPlan == nil) // Allow swipe only if already set up
        }
        .onAppear {
            statsStore.refreshDailySetupIfNeeded()
        }
    }

    @ViewBuilder
    private var compactStatusHeader: some View {
        HStack(spacing: 12) {
            headerItem(title: QuestChatStrings.FocusView.headerQuestsTitle, value: questSummaryText, icon: "checkmark.circle.fill", tint: .mint)
            headerItem(title: QuestChatStrings.FocusView.headerTodayTitle, value: minutesSummaryText, icon: "timer", tint: .cyan)
            headerItem(title: QuestChatStrings.FocusView.headerStreakTitle, value: streakSummaryText, icon: "flame.fill", tint: .orange)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground).opacity(0.16))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [Color.mint.opacity(0.5), Color.cyan.opacity(0.35), Color.purple.opacity(0.2)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }

    private var settingsGearButton: some View {
        Button {
            isShowingSettings = true
        } label: {
            Image(systemName: "gearshape.fill")
                .font(.title3)
                .padding(10)
                .background(Color(uiColor: .secondarySystemBackground))
                .clipShape(Circle())
        }
        .foregroundStyle(.mint)
    }

    @ViewBuilder
    private var bottomActionsSection: some View {
        HStack(alignment: .center) {
            #if DEBUG
            VStack(alignment: .leading, spacing: 8) {
                Button("Test hydration nudge") {
                    viewModel.debugFireHydrationReminder()
                }
                Button("Test posture nudge") {
                    viewModel.debugFirePostureReminder()
                }
            }
            #endif

            Spacer()

            settingsGearButton
        }
        .foregroundStyle(.mint)
    }

    private func headerItem(title: String, value: String, icon: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: icon)
                .font(.caption.bold())
                .foregroundStyle(tint)
            Text(value)
                .font(.subheadline)
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var momentumCard: some View {
        ZStack {
            // Back: wave Lottie animation
            LottieView(
                animationName: "WaveLoop",
                loopMode: .loop,
                animationSpeed: 1.0,
                contentMode: .scaleAspectFill,
                animationTrigger: momentumWaveTrigger,
                freezeOnLastFrame: false,
                tintColor: UIColor.systemPurple
            )
            .frame(height: 110)
            .opacity(0.25)
            .allowsHitTesting(false)
            
            // Front: momentum content
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Label(QuestChatStrings.StatsView.momentumLabel, systemImage: "bolt.fill")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.yellow)
                    Spacer()
                    Text(momentumLabel)
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                }

                ProgressView(value: momentumProgress, total: 1)
                    .tint(.yellow)
                    .progressViewStyle(.linear)

                Text(momentumDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(uiColor: .secondarySystemBackground).opacity(0.45))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    @ViewBuilder
    private func activeTimerSection(for category: TimerCategory) -> some View {
        if viewModel.isActiveTimerExpanded {
            heroCard(for: category)
                .onTapGesture {
                    toggleActiveTimerExpansion()
                }
        } else {
            collapsedActiveTimer(for: category)
                .id("active-timer-card")
                .onTapGesture {
                    toggleActiveTimerExpansion()
                }
        }
    }

    private func toggleActiveTimerExpansion() {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
            viewModel.isActiveTimerExpanded.toggle()
        }
    }

    private func collapsedActiveTimer(for category: TimerCategory) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(category.id.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .frame(height: 18)

                    Text(category.id.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .frame(height: 14)
                }
                .frame(height: 36)

                Spacer(minLength: 0)

                Text(formattedTime)
                    .font(.title3.monospacedDigit().weight(.bold))
                    .foregroundStyle(.primary)
                    .frame(width: 70, alignment: .trailing)
            }
            .frame(height: 44)

            ProgressView(value: viewModel.progress, total: 1)
                .progressViewStyle(.linear)
                .tint(.mint)
                .frame(height: 4)
        }
        .padding(16)
        .frame(height: 86)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: 90) // Keep collapsed card height stable
        .background(Color(uiColor: .secondarySystemBackground).opacity(0.18))
        .cornerRadius(18)
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.25), radius: 12, x: 0, y: 6)
        .animation(nil, value: viewModel.selectedCategory) // Disable layout animation on category change
    }

    private func heroCard(for category: TimerCategory) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .center, spacing: 12) {
                    Image(systemName: category.id.systemImageName)
                        .font(.system(size: 30))
                        .foregroundStyle(Color.accentColor)
                        .matchedGeometryEffect(id: "emoji-\(category.id)", in: categoryAnimation)

                    Text(category.id.title)
                        .font(.title.weight(.semibold))
                        .matchedGeometryEffect(id: "title-\(category.id)", in: categoryAnimation)

                    Spacer(minLength: 0)

                    HStack(spacing: 6) {
                        Text(viewModel.formattedDuration(viewModel.durationForSelectedCategory()))
                            .font(.subheadline.weight(.semibold))
                        
                        Image(systemName: "pencil.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(.mint)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.mint.opacity(0.16))
                    .clipShape(Capsule())
                    .matchedGeometryEffect(id: "duration-\(category.id)", in: categoryAnimation)
                    .onTapGesture {
                        viewModel.pendingDurationSeconds = viewModel.durationForSelectedCategory()
                        viewModel.isShowingDurationPicker = true
                    }
                }

                if !category.id.subtitle.isEmpty {
                    Text(category.id.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .matchedGeometryEffect(id: "subtitle-\(category.id)", in: categoryAnimation)
                }

                comboPill(for: category)
            }

            timerRing
                .frame(width: 220, height: 220)
                .padding(.top, 4)
                .frame(maxWidth: .infinity)

            controlPanel
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground).opacity(0.18))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.25), radius: 12, x: 0, y: 8)
        .scaleEffect(heroCardScale)
        .opacity(heroCardOpacity)
        .onAppear {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.78)) {
                heroCardScale = 1
                heroCardOpacity = 1
            }
        }
    }

    private var quickTimersList: some View {
        let otherCategories = viewModel.categories.filter { $0.id != viewModel.selectedCategory }

        return VStack(alignment: .leading, spacing: 12) {
            if !otherCategories.isEmpty {
                Text(QuestChatStrings.FocusView.quickTimersTitle)
                    .font(.headline)
                    .foregroundStyle(.secondary)

                VStack(spacing: 10) {
                    ForEach(otherCategories) { category in
                        quickTimerTile(for: category)
                    }
                }
            }
        }
        .animation(nil, value: viewModel.selectedCategory) // Prevent layout animation on selection
    }

    private func quickTimerTile(for category: TimerCategory) -> some View {
        Button {
            guard !viewModel.isRunning else { return }
            let wasCollapsed = !viewModel.isActiveTimerExpanded
            withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                viewModel.selectCategory(category)
            }
            // Preserve collapsed state after switching categories
            if wasCollapsed {
                // Keep it collapsed without animating expansion
                withAnimation(.none) {
                    viewModel.isActiveTimerExpanded = false
                }
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: category.id.systemImageName)
                    .font(.system(size: 22))
                    .foregroundStyle(Color.accentColor)
                    .matchedGeometryEffect(id: "emoji-\(category.id)", in: categoryAnimation)

                VStack(alignment: .leading, spacing: 4) {
                    Text(category.id.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .matchedGeometryEffect(id: "title-\(category.id)", in: categoryAnimation)
                    Text(category.id.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .matchedGeometryEffect(id: "subtitle-\(category.id)", in: categoryAnimation)
                }

                Spacer()

                Text(viewModel.formattedDuration(category.durationSeconds))
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)
                    .matchedGeometryEffect(id: "duration-\(category.id)", in: categoryAnimation)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color(uiColor: .secondarySystemBackground).opacity(0.1))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
            .opacity(viewModel.isRunning ? 0.6 : 1)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableCardStyle())
        .disabled(viewModel.isRunning)
    }

    @ViewBuilder
    private func durationPickerSheet() -> some View {
        VStack(spacing: 0) {
            // Compact header
            HStack {
                Button(QuestChatStrings.FocusView.cancelButtonTitle) {
                    viewModel.isShowingDurationPicker = false
                }
                .foregroundStyle(.secondary)
                
                Spacer()
                
                Text("Set Timer")
                    .font(.headline)
                
                Spacer()
                
                Button(QuestChatStrings.FocusView.doneButtonTitle) {
                    viewModel.setDurationForSelectedCategory(viewModel.pendingDurationSeconds)
                    viewModel.isShowingDurationPicker = false
                }
                .foregroundStyle(.mint)
                .fontWeight(.semibold)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            
            Divider()
            
            // Picker content
            VStack(spacing: 20) {
                DurationWheelPickerView(totalSeconds: $viewModel.pendingDurationSeconds)
                    .frame(height: 200)

                // Preview of selected duration (animated pop-in)
                if showDurationPreviewPill {
                    Text(viewModel.formattedDuration(viewModel.pendingDurationSeconds))
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.mint.opacity(0.12))
                        .clipShape(Capsule())
                        .transition(.opacity.combined(with: .scale))
                }
            }
            .padding(.top, 20)
            .padding(.bottom, 30)
        }
        .background(Color(uiColor: .systemBackground))
        .onAppear {
            viewModel.pendingDurationSeconds = viewModel.durationForSelectedCategory()
            // Reset then animate the pill in
            showDurationPreviewPill = false
            DispatchQueue.main.async {
                withAnimation(.easeOut(duration: 0.15)) {
                    showDurationPreviewPill = true
                }
            }
        }
        .onDisappear {
            // Prepare for next presentation
            showDurationPreviewPill = false
        }
    }

    private var timerRing: some View {
        VStack(spacing: 8) {
            ZStack {
                // 🔵 Lottie rings in the back
                LottieView(
                    animationName: "FocusRings",
                    loopMode: .loop,
                    animationSpeed: 0.5,
                    contentMode: .scaleAspectFit,
                    animationTrigger: focusRingsTrigger,
                    freezeOnLastFrame: false
                )
                .frame(width: 360, height: 360)
                .opacity(0.6)
                .allowsHitTesting(false)
                
                // 🕒 Your existing timer circle + text
                ZStack {
                    Circle()
                    .stroke(Color.gray.opacity(0.35), lineWidth: 18)

                Circle()
                    .trim(from: 0, to: viewModel.progress)
                    .stroke(
                        AngularGradient(colors: ringColors, center: .center),
                        style: StrokeStyle(lineWidth: 18, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .scaleEffect(1 + (0.06 * warningFraction))
                    // smooth progress animation
                    .animation(
                        .easeInOut(duration: 0.2),
                        value: viewModel.progress
                    )
                    // smooth “warning bump” without looping forever
                    .animation(
                        .easeInOut(duration: 0.3),
                        value: warningFraction
                    )
                    .overlay {
                        Circle()
                            .stroke(Color.white.opacity(0.22), lineWidth: 6)
                            .scaleEffect(
                                viewModel.remainingSeconds <= 10 && viewModel.remainingSeconds > 0
                                ? 1.05
                                : 1
                            )
                            .opacity(
                                viewModel.remainingSeconds <= 10 && viewModel.remainingSeconds > 0
                                ? 0.9
                                : 0
                            )
                            // fade/scale in when entering/leaving last 10s,
                            // but no repeatForever
                            .animation(
                                .easeInOut(duration: 0.3),
                                value: viewModel.remainingSeconds <= 10 && viewModel.remainingSeconds > 0
                            )
                    }

                    Text(formattedTime)
                        .font(.system(size: 64, weight: .black, design: .rounded))
                        .monospacedDigit()
                }
                .frame(width: 220, height: 220)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    private var controlPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                let primaryDisabled = viewModel.state != .running && selectedDurationInSeconds <= 0

                Button(action: {
                    animateButtonPress(scale: $primaryButtonScale)
                    if viewModel.state == .running {
                        viewModel.pause()
                    } else {
                        viewModel.start()
                    }
                }) {
                    Label(
                        viewModel.state == .running
                            ? QuestChatStrings.FocusView.pauseButtonTitle
                            : (viewModel.state == .paused ? QuestChatStrings.FocusView.resumeButtonTitle : QuestChatStrings.FocusView.startButtonTitle),
                        systemImage: viewModel.state == .running ? "pause.fill" : "play.fill"
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(.mint)
                .scaleEffect(primaryButtonScale)
                .disabled(primaryDisabled)
                .opacity(primaryDisabled ? 0.6 : 1)

                Button(role: .destructive, action: {
                    animateButtonPress(scale: $resetButtonScale)
                    viewModel.reset()
                }) {
                    Text(QuestChatStrings.FocusView.resetButtonTitle)
                        .frame(minWidth: 90)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.bordered)
                .scaleEffect(resetButtonScale)
            }

            Text("Focus minutes turn into XP. For life too.")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.top, 4)

            HStack {
                Text("\(QuestChatStrings.FocusView.sessionsLabel): \(statsStore.sessionsCompleted)")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.primary)

                Spacer()

                HStack(spacing: 8) {
                    ToggleChip(
                        title: "Hydrate",
                        systemImage: "drop.fill",
                        isOn: viewModel.notificationAuthorized && viewModel.hydrationNudgesEnabled
                    )

                    ToggleChip(
                        title: "Posture",
                        systemImage: "figure.stand",
                        isOn: viewModel.notificationAuthorized && viewModel.postureRemindersEnabled
                    )
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial.opacity(0.12))
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }

    private var reminderCard: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "hand.tap")
                .font(.title3)
                .foregroundStyle(.mint)

            VStack(alignment: .leading, spacing: 4) {
                Text("Tip: Tap the active timer to minimize.")
                    .font(.subheadline.weight(.semibold))
                Text("Tap again to expand anytime to adjust timer settings.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial.opacity(0.14))
        .cornerRadius(18)
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.gray.opacity(0.25), lineWidth: 1)
        )
    }

    private func comboPill(for category: TimerCategory) -> some View {
        // Use actual consecutive timer count from QuestsViewModel
        let consecutiveCount = questsViewModel.consecutiveTimerCount
        let comboComplete = consecutiveCount >= 3

        return Group {
            if comboComplete {
                Label(QuestChatStrings.FocusView.comboComplete, systemImage: "sparkles")
                    .labelStyle(.titleAndIcon)
            } else {
                Label("\(QuestChatStrings.FocusView.comboProgressPrefix) \(consecutiveCount) / 3", systemImage: "repeat")
                    .labelStyle(.titleAndIcon)
            }
        }
        .font(.caption.bold())
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.mint.opacity(0.12))
        .foregroundStyle(.mint)
        .clipShape(Capsule())
    }

    private struct ToggleChip: View {
        let title: String
        let systemImage: String
        let isOn: Bool

        var body: some View {
            HStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.caption2)
                Text(title)
                    .font(.caption)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isOn ? Color.teal.opacity(0.2) : Color.secondary.opacity(0.15))
            .foregroundStyle(isOn ? Color.teal : .secondary)
            .clipShape(Capsule())
        }
    }

    private func animateButtonPress(scale: Binding<CGFloat>) {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.65)) {
            scale.wrappedValue = 1.06
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                scale.wrappedValue = 1.0
            }
        }
    }

    private func minutes(from seconds: Int) -> Int {
        seconds / 60
    }
}

private struct PressableCardStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.8), value: configuration.isPressed)
    }
}

private extension Color {
    func blended(withFraction fraction: Double, of color: Color) -> Color {
        let clampedFraction = min(max(fraction, 0), 1)
        let from = UIColor(self)
        let to = UIColor(color)

        var fromRed: CGFloat = 0
        var fromGreen: CGFloat = 0
        var fromBlue: CGFloat = 0
        var fromAlpha: CGFloat = 0
        from.getRed(&fromRed, green: &fromGreen, blue: &fromBlue, alpha: &fromAlpha)

        var toRed: CGFloat = 0
        var toGreen: CGFloat = 0
        var toBlue: CGFloat = 0
        var toAlpha: CGFloat = 0
        to.getRed(&toRed, green: &toGreen, blue: &toBlue, alpha: &toAlpha)

        return Color(
            red: Double(fromRed + (toRed - fromRed) * clampedFraction),
            green: Double(fromGreen + (toGreen - fromGreen) * clampedFraction),
            blue: Double(fromBlue + (toBlue - fromBlue) * clampedFraction),
            opacity: Double(fromAlpha + (toAlpha - fromAlpha) * clampedFraction)
        )
    }

}

struct DailySetupSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var selectedFocusArea: FocusArea
    @State private var selectedEnergy: EnergyLevel

    let onComplete: (FocusArea, EnergyLevel) -> Void

    init(initialFocusArea: FocusArea, initialEnergyLevel: EnergyLevel, onComplete: @escaping (FocusArea, EnergyLevel) -> Void) {
        _selectedFocusArea = State(initialValue: initialFocusArea)
        _selectedEnergy = State(initialValue: initialEnergyLevel)
        self.onComplete = onComplete
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Set today's vibe")
                            .font(.title2.bold())
                            .foregroundColor(.primary)
                        Text("Sets your daily goal and keeps your streak alive.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true) // ensure wrapping without vertical compression
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 12)
            }
            
            Divider()
                .background(Color.white.opacity(0.1))
            
            // Content
            VStack(alignment: .leading, spacing: 20) {
                // Energy level section (now first)
                VStack(alignment: .leading, spacing: 10) {
                    Text("How much capacity do you have today?")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)

                    HStack(spacing: 8) {
                        ForEach(EnergyLevel.allCases) { level in
                            let details = energyDetails(for: level)
                            CompactEnergyButton(
                                icon: details.icon,
                                label: details.shortLabel,
                                minutes: details.minutes,
                                isSelected: selectedEnergy == level
                            ) {
                                selectedEnergy = level
                            }
                        }
                    }
                }
                
                // Focus mode section (simplified, now second)
                VStack(alignment: .leading, spacing: 10) {
                    Text("What's today's energy?")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)

                    HStack(spacing: 8) {
                        ForEach(FocusArea.allCases) { area in
                            let details = focusDetails(for: area)
                            CompactFocusModeButton(
                                systemImage: details.symbol,
                                label: area.displayName,
                                isSelected: selectedFocusArea == area
                            ) {
                                selectedFocusArea = area
                            }
                        }
                    }
                }
                
                // Info card
                HStack(spacing: 10) {
                    Image(systemName: "lightbulb.fill")
                        .font(.title3)
                        .foregroundStyle(.yellow)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Your goal: \(goalMinutes) minutes today")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.primary)
                        Text("Hit this to keep your weekly streak alive.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.05), lineWidth: 1)
                )
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            
            Divider()
                .background(Color.white.opacity(0.1))
            
            // Save button
            Button {
                onComplete(selectedFocusArea, selectedEnergy)
                dismiss()
            } label: {
                Text("Let's go")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.mint)
                    .foregroundColor(.black)
                    .cornerRadius(14)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .background(Color(uiColor: .systemBackground))
    }
    
    private var goalMinutes: Int {
        selectedEnergy.focusGoalMinutes
    }

    private func energyDetails(for level: EnergyLevel) -> (icon: String, shortLabel: String, minutes: Int) {
        switch level {
        case .low:
            return ("moon.zzz.fill", "Low", 20)
        case .medium:
            return ("cloud.sun.fill", "Medium", 40)
        case .high:
            return ("sun.max.fill", "High", 60)
        }
    }

    private func focusDetails(for area: FocusArea) -> (symbol: String, hint: String) {
        switch area {
        case .work:
            return ("laptopcomputer", "Productive tasks")
        case .selfCare:
            return ("figure.cooldown", "Recovery mode")
        case .chill:
            return ("waveform", "Light activities")
        case .grind:
            return ("flame.fill", "Maximum output")
        }
    }

    private struct CompactEnergyButton: View {
        let icon: String
        let label: String
        let minutes: Int
        let isSelected: Bool
        let action: () -> Void

        var body: some View {
            Button(action: action) {
                VStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundStyle(isSelected ? Color.mint : .secondary)
                    
                    VStack(spacing: 2) {
                        Text(label)
                            .font(.caption.weight(.semibold))
                        Text("\(minutes) min")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isSelected ? Color.mint.opacity(0.2) : Color(uiColor: .secondarySystemBackground))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? Color.mint : Color.clear, lineWidth: 2)
                )
            }
            .buttonStyle(.plain)
        }
    }
    
    private struct CompactFocusModeButton: View {
        let systemImage: String
        let label: String
        let isSelected: Bool
        let action: () -> Void

        var body: some View {
            Button(action: action) {
                VStack(spacing: 6) {
                    Image(systemName: systemImage)
                        .font(.title2)
                        .foregroundStyle(isSelected ? Color.cyan : .secondary)
                    
                    Text(label)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.primary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isSelected ? Color.cyan.opacity(0.2) : Color(uiColor: .secondarySystemBackground))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? Color.cyan : Color.clear, lineWidth: 2)
                )
            }
            .buttonStyle(.plain)
        }
    }
}

private struct FocusModeRow: View {
    let title: String
    let subtitle: String
    let systemImageName: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(0.16))
                        .frame(width: 40, height: 40)

                    Image(systemName: systemImageName)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.accentColor)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.accentColor.opacity(0.18) : Color(.secondarySystemBackground))
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview("FocusView – iPhone 15 Pro") {
    let container = DependencyContainer.shared
    let focusVM = container.focusViewModel
    let healthBarVM = HealthBarViewModel()
    FocusView(
        viewModel: focusVM,
        healthBarViewModel: healthBarVM,
        selectedTab: .constant(.focus)
    )
    .environmentObject(QuestsViewModel(statsStore: container.sessionStatsStore))
    .previewDevice("iPhone 15 Pro")
}

#Preview("FocusView – iPhone 17 Pro Max") {
    let container = DependencyContainer.shared
    let focusVM = container.focusViewModel
    let healthBarVM = HealthBarViewModel()
    FocusView(
        viewModel: focusVM,
        healthBarViewModel: healthBarVM,
        selectedTab: .constant(.focus)
    )
    .environmentObject(QuestsViewModel(statsStore: container.sessionStatsStore))
    .previewDevice("iPhone 17 Pro Max")
}

#Preview("Potions – iPhone 15 Pro") {
    PotionsCard(onHealthTap: {}, onManaTap: {}, onStaminaTap: {})
        .padding(20)
        .background(Color.black)
        .previewDevice("iPhone 15 Pro")
}

#Preview("Potions – iPhone 17 Pro Max") {
    PotionsCard(onHealthTap: {}, onManaTap: {}, onStaminaTap: {})
        .padding(20)
        .background(Color.black)
        .previewDevice("iPhone 17 Pro Max")
}
