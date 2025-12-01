import SwiftUI
import UIKit

struct FocusView: View {
    @StateObject var viewModel: FocusViewModel
    @EnvironmentObject var questsViewModel: QuestsViewModel
    @Binding var selectedTab: MainTab

    @State private var primaryButtonScale: CGFloat = 1
    @State private var pauseButtonScale: CGFloat = 1
    @State private var resetButtonScale: CGFloat = 1
    @State private var heroCardScale: CGFloat = 0.98
    @State private var heroCardOpacity: Double = 0.92
    @State private var isShowingDurationPicker = false
    @State private var tempDurationMinutes: Int = 0

    @Namespace private var categoryAnimation

    private var formattedTime: String {
        let minutes = viewModel.secondsRemaining / 60
        let seconds = viewModel.secondsRemaining % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private var warningFraction: Double {
        guard viewModel.secondsRemaining <= 10 else { return 0 }
        let fraction = 1 - (Double(viewModel.secondsRemaining) / 10)
        return min(max(fraction, 0), 1)
    }

    private var ringColors: [Color] {
        let base = [Color.mint, Color.cyan, Color.mint]
        let warning = [Color.orange, Color.red, Color.orange]
        return zip(base, warning).map { baseColor, warningColor in
            baseColor.blended(withFraction: warningFraction, of: warningColor)
        }
    }

    private var accessoryText: String {
        if viewModel.hasFinishedOnce {
            return "Session complete. Ready for another round?"
        }
        switch viewModel.selectedMode {
        case .focus:
            return "Stay present. Every focus minute turns into XP."
        case .selfCare:
            return "Micro break to stretch, hydrate, and reset posture."
        }
    }

    private var focusMinutesToday: Int { viewModel.statsStore.focusSecondsToday / 60 }
    private var selfCareMinutesToday: Int { viewModel.statsStore.selfCareSecondsToday / 60 }
    private var dailyFocusTarget: Int { viewModel.statsStore.dailyMinutesGoal ?? 40 }

    private var questSummaryText: String {
        "\(questsViewModel.completedQuestsCount) / \(questsViewModel.totalQuestsCount) quests done"
    }

    private var minutesSummaryText: String {
        "\(focusMinutesToday + selfCareMinutesToday) / \(dailyFocusTarget) min"
    }

    private var streakSummaryText: String {
        let days = viewModel.statsStore.currentStreakDays
        return days > 0 ? "\(days)-day streak" : "Start your streak"
    }

    var body: some View {
        ZStack {
            NavigationStack {
                ScrollView {
                    VStack(spacing: 20) {
                        compactStatusHeader
                        todayQuestBanner

                        if let selectedCategory = viewModel.selectedCategory {
                            heroCard(for: selectedCategory)
                        }

                        quickTimersList

                        reminderCard
                    }
                    .padding(.vertical, 24)
                    .padding(.horizontal, 16)
                }
                .background(Color.black.ignoresSafeArea())
                .navigationTitle("Focus")
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(Color.black, for: .navigationBar)
                .toolbarColorScheme(.dark, for: .navigationBar)
            }

            if let pendingLevel = viewModel.statsStore.pendingLevelUp {
                levelUpOverlay(level: pendingLevel)
                    .transition(
                        .asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 1.05)),
                            removal: .opacity.combined(with: .scale(scale: 0.96))
                        )
                    )
                    .zIndex(1)
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
        }
        .animation(.easeInOut(duration: 0.25), value: viewModel.statsStore.pendingLevelUp)
        .animation(.easeInOut(duration: 0.25), value: viewModel.lastCompletedSession?.timestamp)
        .animation(.easeInOut(duration: 0.35), value: viewModel.activeHydrationNudge?.id)
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: viewModel.selectedCategoryID)
        .onAppear {
            viewModel.statsStore.refreshMomentumIfNeeded()
        }
        .onChange(of: viewModel.selectedCategoryID) { _ in
            heroCardScale = 0.98
            heroCardOpacity = 0.92
            withAnimation(.spring(response: 0.45, dampingFraction: 0.78)) {
                heroCardScale = 1
                heroCardOpacity = 1
            }
        }
        .sheet(isPresented: $isShowingDurationPicker) {
            durationPickerSheet()
        }
        .sheet(
            isPresented: Binding(
                get: { viewModel.statsStore.shouldShowDailySetup },
                set: { viewModel.statsStore.shouldShowDailySetup = $0 }
            )
        ) {
            DailySetupSheet(
                initialFocusArea: viewModel.statsStore.dailyConfig?.focusArea ?? .work,
                initialEnergyLevel: .medium
            ) { focusArea, energyLevel in
                viewModel.statsStore.completeDailyConfig(focusArea: focusArea, energyLevel: energyLevel)
                questsViewModel.markCoreQuests(for: focusArea)
            }
            .presentationDetents([.medium])
            .interactiveDismissDisabled()
        }
        .onAppear {
            viewModel.statsStore.refreshDailySetupIfNeeded()
        }
    }

    @ViewBuilder
    private var compactStatusHeader: some View {
        HStack(spacing: 12) {
            headerItem(title: "Quests", value: questSummaryText, icon: "checkmark.circle.fill", tint: .mint)
            headerItem(title: "Today", value: minutesSummaryText, icon: "timer", tint: .cyan)
            headerItem(title: "Streak", value: streakSummaryText, icon: "flame.fill", tint: .orange)
        }
        .padding(14)
        .frame(maxWidth: .infinity)
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

    @ViewBuilder
    private var todayQuestBanner: some View {
        if let quest = questsViewModel.dailyQuests.first {
            Button {
                selectedTab = .quests
            } label: {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Today's Quest")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text(quest.title)
                            .font(.headline)
                    }

                    Spacer()

                    if quest.isCompleted {
                        Label("Completed", systemImage: "checkmark.circle.fill")
                            .font(.subheadline.bold())
                            .foregroundStyle(.mint)
                    } else {
                        Text("+\(quest.xpReward) XP")
                            .font(.caption.bold())
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(.mint.opacity(0.15))
                            .foregroundStyle(.mint)
                            .clipShape(Capsule())
                    }
                }
                .padding()
                .frame(maxWidth: .infinity)
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
                Text(category.emoji)
                    .font(.system(size: 46))
                    .matchedGeometryEffect(id: "emoji-\(category.id)", in: categoryAnimation)

                VStack(alignment: .leading, spacing: 6) {
                    Text(category.name)
                        .font(.title.bold())
                        .matchedGeometryEffect(id: "title-\(category.id)", in: categoryAnimation)
                    Text(category.description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .matchedGeometryEffect(id: "subtitle-\(category.id)", in: categoryAnimation)

                    comboPill(for: category)
                }

                Spacer(minLength: 0)

                Button {
                    tempDurationMinutes = category.durationMinutes
                    isShowingDurationPicker = true
                } label: {
                    Text("\(category.durationMinutes) min")
                        .font(.headline)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color.mint.opacity(0.16))
                        .clipShape(Capsule())
                        .matchedGeometryEffect(id: "duration-\(category.id)", in: categoryAnimation)
                }
                .buttonStyle(.plain)
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
            if let nudge = viewModel.activeHydrationNudge {
                hydrationBanner(nudge: nudge)
                    .padding(.horizontal, 12)
                    .padding(.top, -6)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    private var quickTimersList: some View {
        let otherCategories = viewModel.categories.filter { $0.id != viewModel.selectedCategoryID }

        return VStack(alignment: .leading, spacing: 12) {
            if !otherCategories.isEmpty {
                Text("Quick timers")
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
                Text(category.emoji)
                    .font(.title3)
                    .matchedGeometryEffect(id: "emoji-\(category.id)", in: categoryAnimation)

                VStack(alignment: .leading, spacing: 4) {
                    Text(category.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .matchedGeometryEffect(id: "title-\(category.id)", in: categoryAnimation)
                    Text(category.description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .matchedGeometryEffect(id: "subtitle-\(category.id)", in: categoryAnimation)
                }

                Spacer()

                Text("\(category.durationMinutes) min")
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
            HStack {
                Button("Cancel") {
                    isShowingDurationPicker = false
                }

                Spacer()

                Button("Done") {
                    if let selectedCategory = viewModel.selectedCategory {
                        viewModel.updateDuration(for: selectedCategory, to: tempDurationMinutes)
                    }
                    isShowingDurationPicker = false
                }
                .fontWeight(.semibold)
            }
            .padding()

            Divider()

            Picker("Duration", selection: $tempDurationMinutes) {
                ForEach(Array(stride(from: 5, through: 120, by: 5)), id: \.self) { minutes in
                    Text("\(minutes) min").tag(minutes)
                }
            }
            .pickerStyle(.wheel)
            .labelsHidden()
            .frame(maxWidth: .infinity)
            .padding(.top, 12)
        }
        .presentationDetents([.fraction(0.35), .medium])
        .presentationDragIndicator(.visible)
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
    }

    private var timerRing: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.35), lineWidth: 18)
            Circle()
                .trim(from: 0, to: viewModel.progress)
                .stroke(AngularGradient(colors: ringColors, center: .center), style: StrokeStyle(lineWidth: 18, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .scaleEffect(1 + (0.06 * warningFraction))
                .animation(
                    .easeInOut(duration: 0.2),
                    value: viewModel.progress
                )
                .animation(
                    .easeInOut(duration: 0.6).repeatForever(autoreverses: true),
                    value: warningFraction > 0
                )
                .animation(
                    .easeInOut(duration: 0.3),
                    value: warningFraction
                )
                .overlay {
                    Circle()
                        .stroke(Color.white.opacity(0.22), lineWidth: 6)
                        .scaleEffect(viewModel.secondsRemaining <= 10 && viewModel.secondsRemaining > 0 ? 1.05 : 1)
                        .opacity(viewModel.secondsRemaining <= 10 && viewModel.secondsRemaining > 0 ? 0.9 : 0)
                        .animation(
                            .easeInOut(duration: 0.75).repeatForever(autoreverses: true),
                            value: viewModel.secondsRemaining <= 10 && viewModel.secondsRemaining > 0
                        )
                }

            VStack(spacing: 8) {
                Text(formattedTime)
                    .font(.system(size: 64, weight: .black, design: .rounded))
                    .monospacedDigit()
                Text(accessoryText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 280)
        .padding(.vertical)
    }

    private var controlPanel: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Button(action: {
                    animateButtonPress(scale: $primaryButtonScale)
                    viewModel.start()
                }) {
                    Label(viewModel.state == .paused ? "Resume" : "Start",
                          systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(.mint)
                .scaleEffect(primaryButtonScale)
                .disabled(viewModel.state == .running)
                .opacity(viewModel.state == .running ? 0.6 : 1)

                Button(action: {
                    animateButtonPress(scale: $pauseButtonScale)
                    viewModel.pause()
                }) {
                    Label("Pause", systemImage: "pause.fill")
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
                Label("Reset", systemImage: "arrow.counterclockwise")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.bordered)
            .scaleEffect(resetButtonScale)

            HStack {
                statPill(title: "Sessions", value: "\(viewModel.statsStore.sessionsCompleted)")
                let nudgesActive = viewModel.notificationAuthorized && viewModel.hydrationNudgesEnabled
                statPill(title: "Hydrate + Posture", value: nudgesActive ? "On" : "Off")
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
                    Text("Hydrate + posture when the timer ends")
                        .font(.headline)
                    Text("Notifications stay local for now. We'll sync stats to Supabase later.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            Text("Tip: keep the display black to save battery on OLED. Your streak and XP stay stored on device even if you close the app.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(uiColor: .secondarySystemBackground).opacity(0.12))
        .cornerRadius(18)
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.gray.opacity(0.25), lineWidth: 1)
        )
    }

    private func hydrationBanner(nudge: FocusViewModel.HydrationNudge) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "figure.walk")
                .foregroundStyle(.mint)
                .imageScale(.large)

            VStack(alignment: .leading, spacing: 4) {
                Text("Hydrate + posture check")
                    .font(.headline)
                Text(nudge.message)
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
        let comboCount = viewModel.statsStore.comboCount(for: category.id)
        let comboComplete = viewModel.statsStore.hasEarnedComboBonus(for: category.id)

        return Group {
            if comboComplete {
                Label("Combo complete today!", systemImage: "sparkles")
                    .labelStyle(.titleAndIcon)
            } else {
                Label("Combo: \(comboCount) / 3", systemImage: "repeat")
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

    private func levelUpOverlay(level: Int) -> some View {
        ZStack {
            Color.black.opacity(0.75)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Text("Level \(level)")
                    .font(.system(size: 40, weight: .black, design: .rounded))
                    .foregroundStyle(.mint)

                Text("Keep the momentum going! Your focus streak just leveled up.")
                    .multilineTextAlignment(.center)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Button {
                    withAnimation {
                        viewModel.statsStore.pendingLevelUp = nil
                    }
                } label: {
                    Text("Nice!")
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

    private func sessionCompleteOverlay(summary: FocusViewModel.SessionSummary) -> some View {
        ZStack {
            Color.black.opacity(0.75)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Text("Session complete")
                    .font(.system(size: 34, weight: .black, design: .rounded))

                VStack(spacing: 6) {
                    Text("\(summary.mode.title) • \(minutes(from: summary.duration)) min")
                        .font(.headline)
                    Text("+\(summary.xpGained) XP")
                        .font(.subheadline.bold())
                        .foregroundStyle(.mint)
                }
                .multilineTextAlignment(.center)

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.lastCompletedSession = nil
                    }
                } label: {
                    Text("Nice, back to it")
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
    @State private var selectedEnergy: DailyEnergyLevel

    let onComplete: (FocusArea, DailyEnergyLevel) -> Void

    init(initialFocusArea: FocusArea, initialEnergyLevel: DailyEnergyLevel, onComplete: @escaping (FocusArea, DailyEnergyLevel) -> Void) {
        _selectedFocusArea = State(initialValue: initialFocusArea)
        _selectedEnergy = State(initialValue: initialEnergyLevel)
        self.onComplete = onComplete
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Daily setup")
                        .font(.title2.bold())
                    Text("Pick where to focus and your energy. We'll set a realistic minute goal for today.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Focus area")
                        .font(.headline)
                    ForEach(FocusArea.allCases) { area in
                        Button {
                            selectedFocusArea = area
                        } label: {
                            HStack {
                                Text(area.emoji)
                                Text(area.title)
                                    .font(.body)
                                Spacer()
                                if selectedFocusArea == area {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.mint)
                                }
                            }
                            .padding(10)
                            .frame(maxWidth: .infinity)
                            .background(Color(uiColor: .secondarySystemBackground).opacity(0.18))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Energy level")
                        .font(.headline)

                    Picker("Energy", selection: $selectedEnergy) {
                        ForEach(DailyEnergyLevel.allCases) { level in
                            Text("\(level.emoji) \(level.title) - \(level.suggestedMinutes) min")
                                .tag(level)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Spacer()

                Button {
                    onComplete(selectedFocusArea, selectedEnergy)
                    dismiss()
                } label: {
                    Text("Save today")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(.mint)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
            .padding()
            .background(Color.black.ignoresSafeArea())
        }
    }
}

#Preview {
    let store = SessionStatsStore()
    FocusView(
        viewModel: FocusViewModel(statsStore: store),
        selectedTab: .constant(.focus)
    )
    .environmentObject(QuestsViewModel(statsStore: store))
}
