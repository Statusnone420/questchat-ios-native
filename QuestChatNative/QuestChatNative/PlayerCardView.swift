import SwiftUI

struct PlayerCardView: View {
    @ObservedObject var store: SessionStatsStore
    @ObservedObject var statsViewModel: StatsViewModel
    @ObservedObject var healthBarViewModel: HealthBarViewModel
    @ObservedObject var focusViewModel: FocusViewModel
    @State private var isTitlePickerPresented = false

    @AppStorage("playerDisplayName") private var playerDisplayName: String = QuestChatStrings.PlayerCard.defaultName

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 20) {
                headerCard

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
        .sheet(isPresented: $isTitlePickerPresented) {
            NavigationStack {
                VStack(spacing: 16) {
                    List {
                        if let base = statsViewModel.baseLevelTitle {
                            Section("Level titles") {
                                Button {
                                    statsViewModel.equipBaseLevelTitle()
                                    isTitlePickerPresented = false
                                } label: {
                                    HStack {
                                        Text(base)
                                        Spacer()
                                        if statsViewModel.activeTitle == base {
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(.subheadline)
                                        }
                                    }
                                }
                            }
                        }

                        Section("Achievement titles") {
                            ForEach(Array(statsViewModel.unlockedAchievementTitles).sorted(), id: \.self) { title in
                                Button {
                                    statsViewModel.equipOverrideTitle(title)
                                    isTitlePickerPresented = false
                                } label: {
                                    HStack {
                                        Text(title)
                                        Spacer()
                                        if statsViewModel.activeTitle == title {
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(.subheadline)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
                .navigationTitle("Choose Title")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") {
                            isTitlePickerPresented = false
                        }
                    }
                }
            }
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.06))
                        .frame(width: 56, height: 56)

                    Text(playerDisplayName.isEmpty ? "P1" : String(playerDisplayName.prefix(2)))
                        .font(.headline.weight(.bold))
                }

                VStack(alignment: .leading, spacing: 6) {
                    TextField(QuestChatStrings.PlayerCard.namePlaceholder, text: $playerDisplayName)
                        .font(.title2.weight(.bold))
                        .textFieldStyle(.plain)

                    Button {
                        isTitlePickerPresented = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "wand.and.stars")
                                .font(.caption)

                            Text(statsViewModel.activeTitle ?? "Choose a title")
                                .font(.subheadline.weight(.semibold))

                            Image(systemName: "chevron.down")
                                .font(.caption2)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color.cyan.opacity(0.26))
                        )
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.cyan)
                }

                Spacer()

                if let latest = statsViewModel.latestUnlockedSeasonAchievement {
                    SeasonAchievementBadgeView(
                        title: latest.title,
                        iconName: latest.iconName,
                        isUnlocked: true,
                        progressFraction: 1.0
                    )
                    .frame(width: 52, height: 52)
                }
            }

            Text("Your real-life player card. Track your HP, habits, and streaks here.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.08),
                            Color.white.opacity(0.02)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
        .padding(.horizontal)
        .padding(.top, 16)
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
