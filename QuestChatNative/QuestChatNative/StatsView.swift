import SwiftUI

struct StatsView: View {
    @ObservedObject var store: SessionStatsStore
    @ObservedObject var viewModel: StatsViewModel
    @ObservedObject var questsViewModel: QuestsViewModel
    @State private var showPlayerCard = false

    private var focusMinutes: Int { store.focusSeconds / 60 }
    private var selfCareMinutes: Int { store.selfCareSeconds / 60 }
    private var focusMinutesToday: Int { store.focusSecondsToday / 60 }
    private var selfCareMinutesToday: Int { store.selfCareSecondsToday / 60 }
    private var dailyGoalMinutes: Int { store.dailyMinutesGoal ?? 40 }
    private var dailyGoalProgress: Int { store.dailyMinutesProgress }
    private var focusAreaLabel: String? {
        guard let area = store.dailyConfig?.focusArea else { return nil }
        return "\(area.emoji) \(area.title)"
    }
    private var levelProgress: Double {
        if store.level >= 100 { return 1 }
        let total = Double(store.xpForNextLevel)
        guard total > 0 else { return 0 }
        return Double(store.xpIntoCurrentLevel) / total
    }

    private var levelProgressText: String {
        if store.level >= 100 {
            return "QuestChat Master"
        }
        return QuestChatStrings.StatsView.levelProgress(current: store.xpIntoCurrentLevel, total: store.xpForNextLevel)
    }

    private var momentumStatusText: String {
        let value = store.currentMomentum
        switch value {
        case let value where value >= 1.0:
            return QuestChatStrings.StatsView.momentumReady
        case let value where value >= 0.5:
            return QuestChatStrings.StatsView.momentumAlmost
        case let value where value > 0:
            return QuestChatStrings.StatsView.momentumCharging
        default:
            return QuestChatStrings.StatsView.momentumStart
        }
    }

    private var recentSessions: [SessionStatsStore.SessionRecord] {
        Array(store.sessionHistory.suffix(5).reversed())
    }

    private var weeklyGoalProgress: [SessionStatsStore.WeeklyGoalDayStatus] {
        store.weeklyGoalProgress
    }

    private var healthBarWeeklySummary: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("HealthBar IRL – Last 7 Days")
                .font(.headline)

            if viewModel.last7Days.isEmpty {
                Text("No recent HealthBar data yet.")
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 10) {
                    ForEach(viewModel.last7Days) { day in
                        healthDayRow(day)
                    }
                }
                .padding()
                .background(Color(uiColor: .secondarySystemBackground).opacity(0.15))
                .cornerRadius(16)
            }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    TodaySummaryView(
                        completedQuests: questsViewModel.completedQuestsCount,
                        totalQuests: questsViewModel.totalQuestsCount,
                        focusMinutes: focusMinutesToday,
                        selfCareMinutes: selfCareMinutesToday,
                        dailyFocusTarget: dailyGoalMinutes,
                        currentStreakDays: store.currentStreakDays
                    )

                    dailyGoalCard
                    weeklyPathCard
                    healthBarWeeklySummary

                    header
                    summaryTiles
                    sessionBreakdown
                    sessionHistorySection
                }
                .padding(20)
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle(QuestChatStrings.StatsView.navigationTitle)
            .toolbarBackground(Color.black, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .sheet(isPresented: $showPlayerCard) {
                PlayerCardView(store: store)
            }
            .onAppear {
                store.refreshMomentumIfNeeded()
            }
        }
    }

    private func healthDayRow(_ day: HealthDaySummary) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.label(for: day.date))
                    .font(.subheadline.bold())
                Text("Avg \(Int(day.averageHP.rounded())) / 100 HP")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .leading, spacing: 6) {
                Text("💧 \(day.hydrationCount)")
                Text("✨ \(day.selfCareCount)")
                Text("⚡️ \(day.focusCount)")
            }
            .font(.caption)

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                Text("Gut: \(gutLabel(for: day.lastGut))")
                Text("Mood: \(moodLabel(for: day.lastMood))")
            }
            .font(.caption)
        }
    }

    private func gutLabel(for status: GutStatus) -> String {
        switch status {
        case .great: return "Great"
        case .meh: return "Meh"
        case .rough: return "Rough"
        case .none: return "—"
        }
    }

    private func moodLabel(for status: MoodStatus) -> String {
        switch status {
        case .good: return "Good"
        case .neutral: return "Neutral"
        case .bad: return "Bad"
        case .none: return "—"
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(QuestChatStrings.StatsView.headerTitle)
                .font(.title2.bold())
            Text(QuestChatStrings.StatsView.headerSubtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .lastTextBaseline, spacing: 8) {
                    Text(QuestChatStrings.StatsView.levelLabel)
                        .font(.headline)
                        .foregroundStyle(.mint)
                    Text("\(store.level)")
                        .font(.largeTitle.bold())
                }

                ProgressView(value: levelProgress)
                    .progressViewStyle(.linear)
                    .tint(.mint)

                Text(levelProgressText)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                    Label(QuestChatStrings.StatsView.momentumLabel, systemImage: "bolt.fill")
                        .font(.subheadline.bold())
                        .foregroundStyle(.yellow)
                        Spacer()
                        Text(momentumStatusText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    ProgressView(value: store.currentMomentum, total: 1)
                        .tint(.yellow)
                        .progressViewStyle(.linear)
                }
            }
            .padding()
            .background(Color(uiColor: .secondarySystemBackground).opacity(0.16))
            .cornerRadius(14)
        }
        .overlay(alignment: .topTrailing) {
            Button {
                showPlayerCard = true
            } label: {
                Image(systemName: "person.crop.circle")
                    .font(.title3)
                    .padding(8)
                    .background(Color(uiColor: .secondarySystemBackground).opacity(0.25))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
    }

    private var summaryTiles: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                statCard(title: QuestChatStrings.StatsView.summaryXPTileTitle, value: "\(store.xp)", icon: "sparkles", tint: .mint)
                statCard(title: QuestChatStrings.StatsView.summarySessionsTileTitle, value: "\(store.sessionsCompleted)", icon: "clock.badge.checkmark", tint: .cyan)
            }

            streakCard
        }
    }

    private var sessionBreakdown: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(QuestChatStrings.StatsView.minutesTitle)
                .font(.headline)
            VStack(spacing: 12) {
                progressRow(title: QuestChatStrings.StatsView.focusMinutesLabel, minutes: focusMinutes, totalSeconds: store.focusSeconds, tint: .mint)
                progressRow(title: QuestChatStrings.StatsView.selfCareMinutesLabel, minutes: selfCareMinutes, totalSeconds: store.selfCareSeconds, tint: .cyan)
            }
            .padding()
            .background(Color(uiColor: .secondarySystemBackground).opacity(0.15))
            .cornerRadius(16)
        }
    }

    private var sessionHistorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(QuestChatStrings.StatsView.sessionHistoryTitle)
                .font(.headline)

            if recentSessions.isEmpty {
                Text(QuestChatStrings.StatsView.sessionHistoryEmpty)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 12) {
                    ForEach(recentSessions) { record in
                        sessionHistoryRow(record)
                    }
                }
                .padding()
                .background(Color(uiColor: .secondarySystemBackground).opacity(0.15))
                .cornerRadius(16)
            }
        }
    }

    private func statCard(title: String, value: String, icon: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: icon)
                .font(.headline)
                .foregroundStyle(tint)
            Text(value)
                .font(.largeTitle.bold())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(uiColor: .secondarySystemBackground).opacity(0.16))
        .cornerRadius(14)
    }

    private var weeklyPathCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(QuestChatStrings.StatsView.weeklyPathTitle, systemImage: "chart.dots.scatter")
                .font(.headline)
                .foregroundStyle(.mint)

            HStack(spacing: 10) {
                ForEach(weeklyGoalProgress) { day in
                    ZStack {
                        Circle()
                            .fill(day.goalHit ? Color.mint : Color.clear)
                            .frame(width: 16, height: 16)
                            .overlay(
                                Circle()
                                    .stroke(day.goalHit ? Color.mint : Color.secondary.opacity(0.6), lineWidth: 2)
                            )
                            .opacity(day.goalHit ? 1 : 0.7)

                        if day.isToday {
                            Circle()
                                .stroke(Color.white.opacity(0.35), lineWidth: 3)
                                .frame(width: 24, height: 24)
                        }
                    }
                    .accessibilityLabel(day.date.formatted(date: .abbreviated, time: .omitted))
                    .accessibilityValue(day.goalHit ? QuestChatStrings.StatsView.weeklyGoalMet : QuestChatStrings.StatsView.weeklyGoalNotMet)
                }
            }

            if weeklyGoalProgress.allSatisfy({ $0.goalHit }) {
                Text(QuestChatStrings.StatsView.weeklyStreakBonus)
                    .font(.caption)
                    .foregroundStyle(.mint)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemBackground).opacity(0.16))
        .cornerRadius(14)
    }

    private var dailyGoalCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(QuestChatStrings.StatsView.todaysFocusGoal, systemImage: "target")
                    .font(.headline)
                    .foregroundStyle(.mint)
                Spacer()
                if let focusAreaLabel {
                    Text(focusAreaLabel)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Text(QuestChatStrings.StatsView.dailyGoalProgress(current: dailyGoalProgress, total: dailyGoalMinutes))
                .font(.subheadline.bold())

            ProgressView(value: Double(min(dailyGoalProgress, dailyGoalMinutes)), total: Double(dailyGoalMinutes))
                .tint(.mint)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemBackground).opacity(0.16))
        .cornerRadius(14)
    }

    private var streakCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(QuestChatStrings.StatsView.streakTitle, systemImage: "calendar")
                .font(.headline)
                .foregroundStyle(.orange)
            Text("\(store.currentStreakDays)")
                .font(.largeTitle.bold())
            Text(QuestChatStrings.StatsView.streakSubtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(uiColor: .secondarySystemBackground).opacity(0.16))
        .cornerRadius(14)
    }

    private func progressRow(title: String, minutes: Int, totalSeconds: Int, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.subheadline.bold())
                Spacer()
                Text("\(minutes) min")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: Double(totalSeconds), total: 60 * 60)
                .tint(tint)
                .progressViewStyle(.linear)
        }
    }

    private func sessionHistoryRow(_ record: SessionStatsStore.SessionRecord) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(modeTitle(for: record.modeRawValue))
                    .font(.subheadline.bold())
                Text(record.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(formattedDuration(seconds: record.durationSeconds))
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }

    private func formattedDuration(seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }

    private func modeTitle(for rawValue: String) -> String {
        FocusTimerMode(rawValue: rawValue)?.title ?? rawValue.capitalized
    }
}

#Preview {
    let store = SessionStatsStore()
    let healthStats = HealthBarIRLStatsStore()
    let hydrationSettingsStore = HydrationSettingsStore()
    StatsView(
        store: store,
        viewModel: StatsViewModel(healthStore: healthStats, hydrationSettingsStore: hydrationSettingsStore),
        questsViewModel: QuestsViewModel(statsStore: store)
    )
}
