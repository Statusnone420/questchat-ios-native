import SwiftUI
import UIKit

struct FocusView: View {
    @StateObject var viewModel: FocusViewModel
    @ObservedObject var healthBarViewModel: HealthBarViewModel
    @ObservedObject private var statsStore: SessionStatsStore
    @EnvironmentObject var questsViewModel: QuestsViewModel
    @Environment(\.scenePhase) private var scenePhase
    @Binding var selectedTab: MainTab

    @State private var primaryButtonScale: CGFloat = 1
    @State private var pauseButtonScale: CGFloat = 1
    @State private var resetButtonScale: CGFloat = 1
    @State private var heroCardScale: CGFloat = 0.98
    @State private var heroCardOpacity: Double = 0.92
    @State private var selectedStatusEffect: StatusEffect?

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

    init(viewModel: FocusViewModel, healthBarViewModel: HealthBarViewModel, selectedTab: Binding<MainTab>) {
        _viewModel = StateObject(wrappedValue: viewModel)
        _healthBarViewModel = ObservedObject(wrappedValue: healthBarViewModel)
        _selectedTab = selectedTab
        _statsStore = ObservedObject(wrappedValue: viewModel.statsStore)

        viewModel.onSessionComplete = { [weak healthBarViewModel] in
            healthBarViewModel?.logFocusSprint()
        }
    }

    var body: some View {
        ZStack {
            NavigationStack {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 20) {
                        healthHeaderCard
                        vitalsCard
                        potionsCard
                        compactStatusHeader
                        todayQuestBanner

                        if let selectedCategory = viewModel.selectedCategoryData {
                            heroCard(for: selectedCategory)
                        }

                        quickTimersList

                        reminderCard
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
                .scrollBounceBehavior(.basedOnSize)
                .background(Color.black.ignoresSafeArea())
                .navigationTitle(QuestChatStrings.FocusView.navigationTitle)
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(Color.black, for: .navigationBar)
                .toolbarColorScheme(.dark, for: .navigationBar)
            }
            
            if let session = viewModel.lastCompletedSession {
                sessionCompleteOverlay(summary: session)
                    .transition(
                        .asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 1.05)),
                            removal: .opacity.combined(with: .scale(scale: 0.95))
                        )
                    )
                    .zIndex(2)
            }
            
            if let levelUp = statsStore.pendingLevelUp {
                LevelUpModalView(level: levelUp) {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        statsStore.pendingLevelUp = nil
                    }
                }
                .zIndex(3)
            }
        }
        .onAppear {
            viewModel.handleAppear()
        }
        .animation(.easeInOut(duration: 0.25), value: viewModel.lastCompletedSession?.timestamp)
        .animation(.easeInOut(duration: 0.35), value: viewModel.activeReminderEvent?.id)
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: viewModel.selectedCategory)
        .onAppear {
            viewModel.handleScenePhaseChange(scenePhase)
        }
        .onChange(of: scenePhase) {
            viewModel.handleScenePhaseChange(scenePhase)
        }
        .onChange(of: viewModel.selectedCategory) {
            heroCardScale = 0.98
            heroCardOpacity = 0.92
            withAnimation(.spring(response: 0.45, dampingFraction: 0.78)) {
                heroCardScale = 1
                heroCardOpacity = 1
            }
        }
        .sheet(isPresented: $viewModel.isShowingDurationPicker) {
            durationPickerSheet()
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
            .interactiveDismissDisabled()
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

    private func statusEffectIcon(for effect: StatusEffect) -> some View {
        let tint: Color = effect.kind == .buff ? .green : .red

        return VStack(spacing: 6) {
            Image(systemName: effect.systemImageName)
                .font(.subheadline.weight(.bold))
                .frame(width: 32, height: 32)
                .foregroundStyle(.black)
                .background(tint)
                .clipShape(Circle())
                .shadow(color: tint.opacity(0.35), radius: 6, x: 0, y: 3)

            Text(effect.title)
                .font(.caption2.weight(.semibold))
                .lineLimit(1)
        }
        .padding(10)
        .frame(minWidth: 90)
        .background(Color(uiColor: .secondarySystemBackground).opacity(0.3))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(tint.opacity(0.5), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func statusEffectDetail(for effect: StatusEffect) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(effect.title, systemImage: effect.systemImageName)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(effect.kind == .buff ? .green : .red)

            Text(effect.description)
                .font(.caption)
                .foregroundStyle(.secondary)

            if !effect.affectedStats.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "wand.and.stars")
                        .foregroundStyle(.yellow)
                    Text(effect.affectedStats.joined(separator: ", "))
                        .font(.caption.bold())
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemBackground).opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .transition(.opacity.combined(with: .scale))
    }

    private var healthHeaderCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("HealthBar IRL")
                    .font(.headline.weight(.semibold))
                Spacer()
                Text("\(viewModel.currentHP) / 100 HP")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            RPGStatBar(
                iconName: "heart.fill",
                label: "HP",
                color: .red,
                progress: viewModel.hpProgress,
                segments: 12
            )

            if !viewModel.activeEffects.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(viewModel.activeEffects) { effect in
                                Button {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                        if selectedStatusEffect?.id == effect.id {
                                            selectedStatusEffect = nil
                                        } else {
                                            selectedStatusEffect = effect
                                        }
                                    }
                                } label: {
                                    statusEffectIcon(for: effect)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    }

                    if let selectedStatusEffect {
                        statusEffectDetail(for: selectedStatusEffect)
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemBackground).opacity(0.65))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var vitalsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .lastTextBaseline) {
                Text("Vitals")
                    .font(.headline.weight(.semibold))
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(viewModel.hydrationSummaryText)
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    if let cups = viewModel.hydrationCupsText {
                        Text(cups)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            StatusBarRow(
                iconName: "drop.fill",
                label: "Hydration",
                tint: .blue,
                progress: viewModel.hydrationProgress,
                segments: 10,
                detailText: viewModel.hydrationSummaryText
            )

            StatusBarRow(
                iconName: "moon.fill",
                label: "Sleep",
                tint: .purple,
                progress: viewModel.sleepProgress,
                segments: 8,
                detailText: viewModel.sleepQualityLabel
            )

            StatusBarRow(
                iconName: "face.smiling",
                label: "Mood",
                tint: .green,
                progress: viewModel.moodProgress,
                segments: 8,
                detailText: viewModel.moodStatusLabel
            )

            StatusBarRow(
                iconName: "bolt.fill",
                label: "Stamina",
                tint: .orange,
                progress: viewModel.staminaProgress,
                segments: 8,
                detailText: viewModel.staminaLabel
            )
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemBackground).opacity(0.45))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var potionsCard: some View {
        PotionsCard(
            onHealthTap: { viewModel.logComfortBeverageTapped() },
            onManaTap: { viewModel.logHydrationPillTapped() },
            onStaminaTap: { viewModel.logStaminaPotionTapped() }
        )
    }

    struct PotionsCard: View {
        let onHealthTap: () -> Void
        let onManaTap: () -> Void
        let onStaminaTap: () -> Void

        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                Text("Potions")
                    .font(.headline.weight(.semibold))

                PotionsRow(
                    onHealthTap: onHealthTap,
                    onManaTap: onManaTap,
                    onStaminaTap: onStaminaTap
                )
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(uiColor: .secondarySystemBackground).opacity(0.45))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private struct PotionsRow: View {
        let onHealthTap: () -> Void
        let onManaTap: () -> Void
        let onStaminaTap: () -> Void

        var body: some View {
            GeometryReader { geo in
                let spacing: CGFloat = 12
                let totalSpacing = spacing * 2
                let pillWidth = (geo.size.width - totalSpacing) / 3

                HStack(spacing: spacing) {
                    Button(action: onHealthTap) {
                        potionPill(label: "Health", systemImage: "cross.case.fill", style: .health)
                    }
                    .frame(width: pillWidth)
                    .buttonStyle(.plain)

                    Button(action: onManaTap) {
                        potionPill(label: "Mana", systemImage: "drop.fill", style: .mana)
                    }
                    .frame(width: pillWidth)
                    .buttonStyle(.plain)

                    Button(action: onStaminaTap) {
                        potionPill(label: "Stamina", systemImage: "bolt.fill", style: .stamina)
                    }
                    .frame(width: pillWidth)
                    .buttonStyle(.plain)
                }
            }
            .frame(height: 52)
        }

        private func potionPill(label: String, systemImage: String, style: PotionStyle) -> some View {
            Label {
                Text(label)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .allowsTightening(true)
            } icon: {
                Image(systemName: systemImage)
                    .font(.subheadline.weight(.semibold))
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(style.backgroundColor)
            .foregroundStyle(Color.white)
            .clipShape(Capsule())
        }
    }

    private enum PotionStyle {
        case health
        case mana
        case stamina

        var backgroundColor: Color {
            switch self {
            case .health:
                return .green
            case .mana:
                return .cyan
            case .stamina:
                return .orange
            }
        }
    }

    @ViewBuilder
    private var todayQuestBanner: some View {
        if let quest = questsViewModel.dailyQuests.first {
            Button {
                selectedTab = .quests
            } label: {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(QuestChatStrings.FocusView.todayQuestLabel)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text(quest.title)
                            .font(.headline)
                    }

                    Spacer()

                    if quest.isCompleted {
                        Label(QuestChatStrings.FocusView.questCompletedLabel, systemImage: "checkmark.circle.fill")
                            .font(.subheadline.bold())
                            .foregroundStyle(.mint)
                    } else {
                        Text(QuestChatStrings.xpRewardText(quest.xpReward))
                            .font(.caption.bold())
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(.mint.opacity(0.15))
                            .foregroundStyle(.mint)
                            .clipShape(Capsule())
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.ultraThinMaterial.opacity(0.14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.gray.opacity(0.25), lineWidth: 1)
                )
                .cornerRadius(14)
            }
            .buttonStyle(.plain)
        }
    }

    private func heroCard(for category: TimerCategory) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: category.id.systemImageName)
                    .font(.system(size: 34))
                    .foregroundStyle(Color.accentColor)
                    .matchedGeometryEffect(id: "emoji-\(category.id)", in: categoryAnimation)

                VStack(alignment: .leading, spacing: 6) {
                    Text(category.id.title)
                        .font(.title.bold())
                        .matchedGeometryEffect(id: "title-\(category.id)", in: categoryAnimation)
                    Text(category.id.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .matchedGeometryEffect(id: "subtitle-\(category.id)", in: categoryAnimation)

                    comboPill(for: category)
                }

                Spacer(minLength: 0)

                Text(viewModel.formattedDuration(viewModel.durationForSelectedCategory()))
                    .font(.headline)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.mint.opacity(0.16))
                    .clipShape(Capsule())
                    .matchedGeometryEffect(id: "duration-\(category.id)", in: categoryAnimation)
                    .onTapGesture {
                        viewModel.pendingDurationSeconds = viewModel.durationForSelectedCategory()
                        viewModel.isShowingDurationPicker = true
                    }
            }

            timerRing

            controlPanel
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground).opacity(0.22))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [Color.mint.opacity(0.4), Color.cyan.opacity(0.3), Color.purple.opacity(0.2)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.6
                )
        )
        .shadow(color: Color.black.opacity(0.35), radius: 20, x: 0, y: 12)
        .shadow(color: Color.mint.opacity(0.22), radius: 14, x: 0, y: 8)
        .padding(.top, 4)
        .scaleEffect(heroCardScale)
        .opacity(heroCardOpacity)
        .onAppear {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.78)) {
                heroCardScale = 1
                heroCardOpacity = 1
            }
        }
        .overlay(alignment: .top) {
            if let event = viewModel.activeReminderEvent {
                reminderBanner(event: event)
                    .padding(.horizontal, 12)
                    .padding(.top, -6)
                    .transition(.move(edge: .top).combined(with: .opacity))
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
    }

    private func quickTimerTile(for category: TimerCategory) -> some View {
        Button {
            guard !viewModel.isRunning else { return }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                viewModel.selectCategory(category)
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
        NavigationView {
            VStack {
                DurationWheelPickerView(totalSeconds: $viewModel.pendingDurationSeconds)
                    .frame(maxHeight: 250)

                Spacer()
            }
            .navigationTitle("Set timer")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(QuestChatStrings.FocusView.cancelButtonTitle) {
                        viewModel.isShowingDurationPicker = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(QuestChatStrings.FocusView.doneButtonTitle) {
                        viewModel.setDurationForSelectedCategory(viewModel.pendingDurationSeconds)
                        viewModel.isShowingDurationPicker = false
                    }
                }
            }
        }
        .onAppear {
            viewModel.pendingDurationSeconds = viewModel.durationForSelectedCategory()
        }
    }

    private var timerRing: some View {
        VStack(spacing: 12) {
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
            .frame(maxWidth: .infinity)
            .frame(height: 280)

            Text(viewModel.timerStatusText)
                .font(.footnote)
                .foregroundColor(.white.opacity(0.75))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical)
    }

    private var controlPanel: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Button(action: {
                    animateButtonPress(scale: $primaryButtonScale)
                    viewModel.start()
                }) {
                    Label(viewModel.state == .paused ? QuestChatStrings.FocusView.resumeButtonTitle : QuestChatStrings.FocusView.startButtonTitle,
                          systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(.mint)
                .scaleEffect(primaryButtonScale)
                .disabled(viewModel.state == .running || selectedDurationInSeconds <= 0)
                .opacity(viewModel.state == .running || selectedDurationInSeconds <= 0 ? 0.6 : 1)

                Button(action: {
                    animateButtonPress(scale: $pauseButtonScale)
                    viewModel.pause()
                }) {
                    Label(QuestChatStrings.FocusView.pauseButtonTitle, systemImage: "pause.fill")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.bordered)
                .scaleEffect(pauseButtonScale)
                .disabled(viewModel.state != .running)
                .opacity(viewModel.state != .running ? 0.6 : 1)
            }

            Button(role: .destructive, action: {
                animateButtonPress(scale: $resetButtonScale)
                viewModel.reset()
            }) {
                Label(QuestChatStrings.FocusView.resetButtonTitle, systemImage: "arrow.counterclockwise")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.bordered)
            .scaleEffect(resetButtonScale)

            HStack {
                statPill(title: QuestChatStrings.FocusView.sessionsLabel, value: "\(statsStore.sessionsCompleted)")
                let nudgesActive = viewModel.notificationAuthorized && viewModel.hydrationNudgesEnabled
                statPill(title: QuestChatStrings.FocusView.hydratePostureLabel, value: nudgesActive ? QuestChatStrings.FocusView.hydratePostureOn : QuestChatStrings.FocusView.hydratePostureOff)
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
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "drop.fill")
                    .foregroundStyle(.cyan)
                VStack(alignment: .leading) {
                    Text(QuestChatStrings.FocusView.reminderTitle)
                        .font(.headline)
                    Text(QuestChatStrings.FocusView.reminderSubtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            Text(QuestChatStrings.FocusView.reminderTip)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemBackground).opacity(0.12))
        .cornerRadius(18)
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.gray.opacity(0.25), lineWidth: 1)
        )
    }

    private func reminderBanner(event: ReminderEvent) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: viewModel.reminderIconName(for: event.type))
                .foregroundStyle(event.type == .hydration ? .mint : .purple)
                .imageScale(.large)

            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.reminderTitle(for: event.type))
                    .font(.headline)
                Text(viewModel.activeReminderMessage ?? viewModel.reminderBody(for: event.type))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(.ultraThinMaterial.opacity(0.85))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 6)
    }

    private func statPill(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline.bold())
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(uiColor: .secondarySystemBackground).opacity(0.16))
        .cornerRadius(14)
    }

    private func comboPill(for category: TimerCategory) -> some View {
        // Derive a simple combo heuristic from existing stats rather than missing APIs.
        // Treat the daily focus goal as the combo completion for focus categories.
        let goalMinutes = statsStore.dailyMinutesGoal ?? 40
        let focusToday = statsStore.focusSecondsToday / 60
        let selfCareToday = statsStore.selfCareSecondsToday / 60

        // Determine progress source based on the category's mode.
        let isFocusMode = category.id.mode == .focus
        let progressMinutes = isFocusMode ? focusToday : selfCareToday

        // Map progress to a 3-step combo (roughly thirds of the goal for focus; fixed steps for self-care).
        let stepTarget: Int = max(1, isFocusMode ? max(10, goalMinutes / 3) : 5)
        let stepsCompleted = max(0, min(3, progressMinutes / stepTarget))
        let comboComplete = stepsCompleted >= 3

        return Group {
            if comboComplete {
                Label(QuestChatStrings.FocusView.comboComplete, systemImage: "sparkles")
                    .labelStyle(.titleAndIcon)
            } else {
                Label("\(QuestChatStrings.FocusView.comboProgressPrefix) \(stepsCompleted) / 3", systemImage: "repeat")
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

    private func sessionCompleteOverlay(summary: FocusViewModel.SessionSummary) -> some View {
        ZStack {
            Color.black.opacity(0.75)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Text(QuestChatStrings.FocusView.sessionCompleteTitle)
                    .font(.system(size: 34, weight: .black, design: .rounded))

                VStack(spacing: 6) {
                    Text("\(summary.mode.title) • \(minutes(from: summary.duration)) min")
                        .font(.headline)
                    Text(QuestChatStrings.xpRewardText(summary.xpGained))
                        .font(.subheadline.bold())
                        .foregroundStyle(.mint)
                }
                .multilineTextAlignment(.center)

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.lastCompletedSession = nil
                    }
                } label: {
                    Text(QuestChatStrings.FocusView.sessionCompleteButtonTitle)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .tint(.mint)
            }
            .padding(24)
            .frame(maxWidth: 320)
            .background(Color(uiColor: .secondarySystemBackground).opacity(0.95))
            .cornerRadius(24)
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color.gray.opacity(0.25), lineWidth: 1)
            )
        }
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

private struct DailySetupSheet: View {
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
        VStack {
            Spacer()

            VStack(alignment: .leading, spacing: 16) {
                header

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        focusAreaSection
                        energySection
                    }
                }

                Button {
                    onComplete(selectedFocusArea, selectedEnergy)
                    dismiss()
                } label: {
                    Text(QuestChatStrings.FocusView.saveTodayButtonTitle)
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color.accentColor)
                        .foregroundColor(.black)
                        .cornerRadius(20)
                }
                .padding(.top, 24)
                .padding(.bottom, 4)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.white.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
            .padding(.horizontal, 8)
            .padding(.top, 8)
            .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.6).ignoresSafeArea())
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(QuestChatStrings.FocusView.dailySetupTitle)
                .font(.title2.bold())
                .foregroundColor(.white)
            Text("Pick where to focus and your energy. We’ll set a realistic goal for today.")
                .font(.subheadline)
                .foregroundColor(Color.white.opacity(0.85))
        }
    }

    private var focusAreaSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(QuestChatStrings.FocusView.focusAreaLabel)
                .font(.headline)
                .foregroundColor(.white)

            VStack(spacing: 8) {
                ForEach(FocusArea.allCases) { area in
                    Button {
                        selectedFocusArea = area
                    } label: {
                        HStack(spacing: 10) {
                            Text(area.icon)
                            Text(area.displayName)
                                .font(.body)
                            Spacer()
                            if selectedFocusArea == area {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(selectedFocusArea == area ? Color.white.opacity(0.12) : Color.white.opacity(0.04))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var energySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(QuestChatStrings.FocusView.energyLevelLabel)
                .font(.headline)
                .foregroundColor(.white)

            HStack(spacing: 8) {
                chip(for: .low)
                chip(for: .medium)
                chip(for: .high)
            }
        }
    }

    private func chip(for level: EnergyLevel) -> some View {
        Button {
            selectedEnergy = level
        } label: {
            HStack(spacing: 6) {
                Text(level.emoji)
                Text(level.label)
            }
            .font(.subheadline)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(level == selectedEnergy ? Color.white.opacity(0.15) : Color.white.opacity(0.05))
            )
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(level == selectedEnergy ? 0.3 : 0.15), lineWidth: 1)
            )
            .foregroundColor(.white)
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
    FocusView.PotionsCard(onHealthTap: {}, onManaTap: {}, onStaminaTap: {})
        .padding(20)
        .background(Color.black)
        .previewDevice("iPhone 15 Pro")
}

#Preview("Potions – iPhone 17 Pro Max") {
    FocusView.PotionsCard(onHealthTap: {}, onManaTap: {}, onStaminaTap: {})
        .padding(20)
        .background(Color.black)
        .previewDevice("iPhone 17 Pro Max")
}

