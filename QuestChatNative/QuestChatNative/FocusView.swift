import SwiftUI

struct FocusView: View {
    @StateObject var viewModel: FocusViewModel
    @EnvironmentObject var questsViewModel: QuestsViewModel
    @Binding var selectedTab: MainTab

    private var formattedTime: String {
        let minutes = viewModel.secondsRemaining / 60
        let seconds = viewModel.secondsRemaining % 60
        return String(format: "%02d:%02d", minutes, seconds)
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

    private var levelProgressPercentage: Int {
        let progress = Double(viewModel.statsStore.xpIntoCurrentLevel) / Double(viewModel.statsStore.xpForNextLevel)
        guard progress.isFinite else { return 0 }
        return Int(progress * 100)
    }

    private var focusMinutesToday: Int { viewModel.statsStore.focusSecondsToday / 60 }
    private var selfCareMinutesToday: Int { viewModel.statsStore.selfCareSecondsToday / 60 }

    var body: some View {
        ZStack {
            NavigationStack {
                ScrollView {
                    VStack(spacing: 24) {
                        todayQuestBanner

                        xpStrip

                        TodaySummaryView(
                            completedQuests: questsViewModel.completedQuestsCount,
                            totalQuests: questsViewModel.totalQuestsCount,
                            focusMinutes: focusMinutesToday,
                            selfCareMinutes: selfCareMinutesToday,
                            dailyFocusTarget: 40,
                            currentStreakDays: viewModel.statsStore.currentStreakDays
                        )

                        timerCard

                        controlPanel

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

    private var xpStrip: some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkles")
                .foregroundStyle(.mint)
                .imageScale(.large)
            VStack(alignment: .leading, spacing: 4) {
                Text("XP: \(viewModel.statsStore.xp)")
                    .font(.title2.bold())
                Text("Level \(viewModel.statsStore.level) • \(levelProgressPercentage)% to next level")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text("Focus: \(minutes(from: viewModel.statsStore.focusSeconds)) min • Self care: \(minutes(from: viewModel.statsStore.selfCareSeconds)) min")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding()
        .background(.ultraThinMaterial.opacity(0.15))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
        .cornerRadius(16)
    }

    private var timerCard: some View {
        VStack(spacing: 16) {
            Picker("Mode", selection: $viewModel.selectedMode) {
                ForEach(FocusTimerMode.allCases) { mode in
                    Label(mode.title, systemImage: mode.accentSystemImage)
                        .tag(mode)
                }
            }
            .pickerStyle(.segmented)

            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.35), lineWidth: 18)
                Circle()
                    .trim(from: 0, to: viewModel.progress)
                    .stroke(AngularGradient(colors: [.mint, .cyan, .mint], center: .center), style: StrokeStyle(lineWidth: 18, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.3), value: viewModel.progress)

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
        .padding()
        .background(Color(uiColor: .secondarySystemBackground).opacity(0.15))
        .cornerRadius(24)
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.gray.opacity(0.25), lineWidth: 1)
        )
    }

    private var controlPanel: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Button(action: viewModel.startOrPause) {
                    Label(viewModel.isRunning ? "Pause" : "Start",
                          systemImage: viewModel.isRunning ? "pause.fill" : "play.fill")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(.mint)

                Button(role: .destructive, action: viewModel.reset) {
                    Label("Reset", systemImage: "arrow.counterclockwise")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.bordered)
            }

            HStack {
                statPill(title: "Sessions", value: "\(viewModel.statsStore.sessionsCompleted)")
                statPill(title: "Hydrate + Posture", value: viewModel.notificationAuthorized ? "On" : "Off")
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

#Preview {
    let store = SessionStatsStore()
    FocusView(
        viewModel: FocusViewModel(statsStore: store),
        selectedTab: .constant(.focus)
    )
    .environmentObject(QuestsViewModel(statsStore: store))
}
