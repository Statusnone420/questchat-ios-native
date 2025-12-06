import SwiftUI

struct PlayerCardView: View {
    @ObservedObject var store: SessionStatsStore
    @ObservedObject var statsViewModel: StatsViewModel
    @ObservedObject var healthBarViewModel: HealthBarViewModel
    @ObservedObject var focusViewModel: FocusViewModel
    let isEmbedded: Bool = false
    @State private var isTitlePickerPresented = false
    @State private var moodSliderValue: Int?
    @State private var gutSliderValue: Int?
    @State private var sleepSliderValue: Int?

    @AppStorage("playerDisplayName") private var playerDisplayName: String = QuestChatStrings.PlayerCard.defaultName

    private var content: some View {
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

            Spacer(minLength: 0)
        }
        .padding()
    }

    var body: some View {
        Group {
            if isEmbedded {
                content
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    content
                }
                .scrollDismissesKeyboard(.interactively)
                .ignoresSafeArea(.keyboard, edges: .bottom)
            }
        }
        .background(Color.black.ignoresSafeArea())
        .onAppear {
            if moodSliderValue == nil {
                moodSliderValue = HealthRatingMapper.rating(for: healthBarViewModel.inputs.moodStatus)
            }
            if gutSliderValue == nil {
                gutSliderValue = HealthRatingMapper.rating(for: healthBarViewModel.inputs.gutStatus)
            }
            if sleepSliderValue == nil {
                sleepSliderValue = HealthRatingMapper.rating(for: focusViewModel.sleepQuality)
            }
        }
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
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.cyan.opacity(0.9),
                                    Color.blue.opacity(0.9)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 56, height: 56)

                    Image(systemName: "atom")
                        .font(.title2.weight(.semibold))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 8) {
                    TextField(QuestChatStrings.PlayerCard.namePlaceholder, text: $playerDisplayName)
                        .font(.title2.weight(.bold))
                        .textFieldStyle(.plain)

                    HStack(spacing: 8) {
                        Text("Level \(store.level)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)

                        Spacer()

                        Text("\(healthBarViewModel.currentHP) / \(healthBarViewModel.maxHP) HP")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                    }

                    RPGStatBar(
                        iconName: "heart.fill",
                        label: "HP",
                        color: .red,
                        progress: healthBarViewModel.hpProgress,
                        segments: healthBarViewModel.hpSegments
                    )
                    .frame(height: 36)

                    Button {
                        isTitlePickerPresented = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "wand.and.stars")
                                .font(.caption)

                            Text(statsViewModel.activeTitle ?? "Choose a title")
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(1)
                                .truncationMode(.tail)

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
                        progressFraction: 1.0,
                        isCompact: true
                    )
                    .frame(width: 36, height: 36)
                }
            }

            Text("Your real-life stats, achivements, badges, and titles.")
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

    private var sleepQualityBinding: Binding<Int?> {
        Binding<Int?>(
            get: { sleepSliderValue ?? HealthRatingMapper.rating(for: focusViewModel.sleepQuality) },
            set: { newValue in
                guard let rating = newValue, let quality = HealthRatingMapper.sleepQuality(for: rating) else { return }
                sleepSliderValue = rating
                focusViewModel.sleepQuality = quality
            }
        )
    }

    private var moodRatingBinding: Binding<Int?> {
        Binding<Int?>(
            get: { moodSliderValue ?? HealthRatingMapper.rating(for: healthBarViewModel.inputs.moodStatus) },
            set: { newValue in
                let status = HealthRatingMapper.moodStatus(for: newValue)
                moodSliderValue = newValue
                healthBarViewModel.setMoodStatus(status)
            }
        )
    }

    private var gutRatingBinding: Binding<Int?> {
        Binding<Int?>(
            get: { gutSliderValue ?? HealthRatingMapper.rating(for: healthBarViewModel.inputs.gutStatus) },
            set: { newValue in
                let status = HealthRatingMapper.gutStatus(for: newValue)
                gutSliderValue = newValue
                healthBarViewModel.setGutStatus(status)
            }
        )
    }

    private var activityRatingBinding: Binding<Int?> {
        Binding<Int?>(
            get: { HealthRatingMapper.rating(for: focusViewModel.activityLevel) },
            set: { newValue in
                focusViewModel.activityLevel = HealthRatingMapper.activityLevel(for: newValue)
            }
        )
    }

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Status")
                .font(.headline)

            RatingSliderRow(
                title: "Mood",
                systemImage: "face.smiling",
                tint: .purple,
                value: moodRatingBinding,
                labels: ["Terrible", "Low", "Okay", "Good", "Great"],
                allowsClearing: true,
                valueDescription: { HealthRatingMapper.label(for: $0) }
            )

            RatingSliderRow(
                title: "Gut",
                systemImage: "heart.text.square",
                tint: .orange,
                value: gutRatingBinding,
                labels: ["Terrible", "Low", "Okay", "Good", "Great"],
                allowsClearing: true,
                valueDescription: { HealthRatingMapper.label(for: $0) }
            )

            RatingSliderRow(
                title: "Sleep",
                systemImage: "bed.double.fill",
                tint: .indigo,
                value: sleepQualityBinding,
                labels: ["Terrible", "Low", "Okay", "Good", "Great"],
                allowsClearing: false,
                valueDescription: { HealthRatingMapper.label(for: $0) }
            )

            RatingSliderRow(
                title: "Activity",
                systemImage: "figure.walk",
                tint: .green,
                value: activityRatingBinding,
                labels: ["Barely moved", "Lightly active", "Some movement", "Active", "Very active"],
                allowsClearing: true,
                valueDescription: { HealthRatingMapper.activityLabel(for: $0) }
            )
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
