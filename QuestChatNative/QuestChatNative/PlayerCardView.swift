import SwiftUI

struct PlayerCardView: View {
    @ObservedObject var store: SessionStatsStore
    @ObservedObject var statsViewModel: StatsViewModel
    @ObservedObject var healthBarViewModel: HealthBarViewModel
    @ObservedObject var focusViewModel: FocusViewModel

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

            statusSection

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
        PlayerStatusBarsView(
            hpProgress: statsViewModel.hpProgress,
            hydrationProgress: statsViewModel.hydrationProgress,
            sleepProgress: statsViewModel.sleepProgress,
            moodProgress: statsViewModel.moodProgress
        )
    }

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Status")
                .font(.headline)

            WellbeingSliderRow(label: "Gut", rating: $focusViewModel.gutRating)
            WellbeingSliderRow(label: "Mood", rating: $focusViewModel.moodRating)
            WellbeingSliderRow(label: "Sleep", rating: $focusViewModel.sleepRating)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemBackground).opacity(0.18))
        .cornerRadius(16)
    }
}

#Preview {
    let store = SessionStatsStore()
    let statsViewModel = StatsViewModel(
        healthStore: HealthBarIRLStatsStore(),
        hydrationSettingsStore: HydrationSettingsStore()
    )
    PlayerCardView(
        store: store,
        statsViewModel: statsViewModel,
        healthBarViewModel: HealthBarViewModel(),
        focusViewModel: DependencyContainer.shared.makeFocusViewModel()
    )
}
