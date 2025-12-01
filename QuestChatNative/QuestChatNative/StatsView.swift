import SwiftUI

struct StatsView: View {
    @ObservedObject var store: SessionStatsStore

    private var focusMinutes: Int { store.focusSeconds / 60 }
    private var selfCareMinutes: Int { store.selfCareSeconds / 60 }
    private var levelProgress: Double {
        let total = Double(store.xpForNextLevel)
        guard total > 0 else { return 0 }
        return Double(store.xpIntoCurrentLevel) / total
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    header
                    summaryTiles
                    sessionBreakdown
                }
                .padding(20)
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Stats")
            .toolbarBackground(Color.black, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
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
    }

    private var summaryTiles: some View {
        HStack(spacing: 12) {
            statCard(title: "XP", value: "\(store.xp)", icon: "sparkles", tint: .mint)
            statCard(title: "Sessions", value: "\(store.sessionsCompleted)", icon: "clock.badge.checkmark", tint: .cyan)
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
}

#Preview {
    StatsView(store: SessionStatsStore())
}
