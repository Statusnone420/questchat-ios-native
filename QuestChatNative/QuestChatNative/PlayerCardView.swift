import SwiftUI

struct PlayerCardView: View {
    @ObservedObject var store: SessionStatsStore
    @ObservedObject var viewModel: StatsViewModel

    @AppStorage("playerDisplayName") private var playerDisplayName: String = QuestChatStrings.PlayerCard.defaultName

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 4) {
                TextField(QuestChatStrings.PlayerCard.namePlaceholder, text: $playerDisplayName)
                    .font(.title.bold())
                    .multilineTextAlignment(.center)
                    .textFieldStyle(.plain)
                Text(store.playerTitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(uiColor: .secondarySystemBackground).opacity(0.18))
            .cornerRadius(14)

            playerHUDSection

            VStack(alignment: .leading, spacing: 12) {
                statRow(label: QuestChatStrings.PlayerCard.levelLabel, value: "\(store.level)", tint: .mint)
                statRow(label: QuestChatStrings.PlayerCard.totalXPLabel, value: "\(store.xp)", tint: .cyan)
                statRow(label: QuestChatStrings.PlayerCard.streakLabel, value: "\(store.currentStreakDays) days", tint: .orange)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(uiColor: .secondarySystemBackground).opacity(0.16))
            .cornerRadius(16)

            HStack {
                Text(store.statusLine)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            Spacer()
        }
        .padding()
        .background(Color.black.ignoresSafeArea())
    }

    private func statRow(label: String, value: String, tint: Color) -> some View {
        HStack {
            Label(label, systemImage: "sparkles")
                .font(.headline)
                .foregroundStyle(tint)
            Spacer()
            Text(value)
                .font(.title3.bold())
        }
    }

    private var playerHUDSection: some View {
        VStack(spacing: 8) {
            RPGStatBar(iconName: "heart.fill",
                       label: "HP",
                       color: .red,
                       progress: viewModel.hpProgress,
                       segments: 10)

            RPGStatBar(iconName: "drop.fill",
                       label: "Hydration",
                       color: .blue,
                       progress: viewModel.hydrationProgress,
                       segments: 10)

            RPGStatBar(iconName: "moon.fill",
                       label: "Sleep",
                       color: .purple,
                       progress: viewModel.sleepProgress,
                       segments: 10)

            RPGStatBar(iconName: "face.smiling",
                       label: "Mood",
                       color: .green,
                       progress: viewModel.moodProgress,
                       segments: 10)
        }
    }
}

#Preview {
    let store = SessionStatsStore()
    let statsViewModel = StatsViewModel(
        healthStore: HealthBarIRLStatsStore(),
        hydrationSettingsStore: HydrationSettingsStore()
    )
    PlayerCardView(store: store, viewModel: statsViewModel)
}
