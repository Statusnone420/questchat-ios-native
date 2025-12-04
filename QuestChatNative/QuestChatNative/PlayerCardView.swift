import SwiftUI

struct PlayerCardView: View {
    @ObservedObject var store: SessionStatsStore
    @ObservedObject var statsViewModel: StatsViewModel
    @ObservedObject var healthBarViewModel: HealthBarViewModel
    @ObservedObject var focusViewModel: FocusViewModel

    @AppStorage("playerDisplayName") private var playerDisplayName: String = QuestChatStrings.PlayerCard.defaultName

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
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
        }
        .background(Color.black.ignoresSafeArea())
        .scrollDismissesKeyboard(.interactively)
        .ignoresSafeArea(.keyboard, edges: .bottom)
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

    private var sleepQualityBinding: Binding<Double> {
        Binding<Double>(
            get: { Double(focusViewModel.sleepQuality.rawValue) },
            set: { newValue in
                if let quality = SleepQuality(rawValue: Int(newValue)) {
                    focusViewModel.sleepQuality = quality
                }
            }
        )
    }

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Status")
                .font(.headline)

            GutStatusPicker(selected: healthBarViewModel.inputs.gutStatus) { status in
                healthBarViewModel.setGutStatus(status)
            }

            MoodStatusPicker(selected: healthBarViewModel.inputs.moodStatus) { status in
                healthBarViewModel.setMoodStatus(status)
            }

            HStack(spacing: 12) {
                Label("Sleep", systemImage: "bed.double.fill")
                    .font(.caption)
                    .foregroundStyle(.indigo)
                    .frame(width: 70, alignment: .leading)

                Slider(value: sleepQualityBinding, in: 0...2, step: 1)

                Text(focusViewModel.sleepQuality.label)
                    .font(.subheadline.weight(.semibold))
                    .frame(minWidth: 70, alignment: .trailing)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemBackground).opacity(0.18))
        .cornerRadius(16)
    }
}

#Preview {
    let container = DependencyContainer.shared
    PlayerCardView(
        store: container.sessionStatsStore,
        statsViewModel: container.statsViewModel,
        healthBarViewModel: container.healthBarViewModel,
        focusViewModel: container.focusViewModel
    )
}
