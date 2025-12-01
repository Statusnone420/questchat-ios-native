import SwiftUI

struct StatsView: View {
    @ObservedObject var store: SessionStatsStore
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
        let total = Double(store.xpForNextLevel)
        guard total > 0 else { return 0 }
        return Double(store.xpIntoCurrentLevel) / total
    }

    private var recentSessions: [SessionStatsStore.SessionRecord] {
        Array(store.sessionHistory.suffix(5).reversed())
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

                    header
                    summaryTiles
                    sessionBreakdown
                    sessionHistorySection
                }
                .padding(20)
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Stats")
            .toolbarBackground(Color.black, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .sheet(isPresented: $showPlayerCard) {
                PlayerCardView(store: store)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Experience")
                .font(.title2.bold())
            Text("Everything is stored locally until Supabase sync lands.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .lastTextBaseline, spacing: 8) {
                    Text("Level")
                        .font(.headline)
                        .foregroundStyle(.mint)
                    Text("\(store.level)")
                        .font(.largeTitle.bold())
                }

                ProgressView(value: levelProgress)
                    .progressViewStyle(.linear)
                    .tint(.mint)

                Text("\(store.xpIntoCurrentLevel) / \(store.xpForNextLevel) XP into this level")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
                statCard(title: "XP", value: "\(store.xp)", icon: "sparkles", tint: .mint)
                statCard(title: "Sessions", value: "\(store.sessionsCompleted)", icon: "clock.badge.checkmark", tint: .cyan)
            }

            streakCard
        }
    }

    private var sessionBreakdown: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Minutes")
                .font(.headline)
            VStack(spacing: 12) {
                progressRow(title: "Focus", minutes: focusMinutes, totalSeconds: store.focusSeconds, tint: .mint)
                progressRow(title: "Self care", minutes: selfCareMinutes, totalSeconds: store.selfCareSeconds, tint: .cyan)
            }
            .padding()
            .background(Color(uiColor: .secondarySystemBackground).opacity(0.15))
            .cornerRadius(16)
        }
    }

    private var sessionHistorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Session History")
                .font(.headline)

            if recentSessions.isEmpty {
                Text("No sessions yet.")
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

    private var dailyGoalCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Today's focus goal", systemImage: "target")
                    .font(.headline)
                    .foregroundStyle(.mint)
                Spacer()
                if let focusAreaLabel {
                    Text(focusAreaLabel)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Text("\(dailyGoalProgress) / \(dailyGoalMinutes) minutes")
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
            Label("Streak", systemImage: "calendar")
                .font(.headline)
                .foregroundStyle(.orange)
            Text("\(store.currentStreakDays)")
                .font(.largeTitle.bold())
            Text("Consecutive days with at least one session.")
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
    StatsView(store: store, questsViewModel: QuestsViewModel(statsStore: store))
}
