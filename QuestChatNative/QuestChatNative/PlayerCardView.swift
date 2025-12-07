import SwiftUI

struct LevelTitleDefinition {
    let minLevel: Int
    let title: String
}

enum PlayerTitles {
    static let rookie   = "Focus Rookie"      // 1–9
    static let worker   = "Deep Worker"       // 10–19
    static let knight   = "Quest Knight"      // 20–29
    static let master   = "Flow Master"       // 30–39
    static let sage     = "Time Sage"         // 40–49
    static let fiend    = "Focus Fiend"       // 50–59
    static let guardian = "Grind Guardian"    // 60–69
    static let tyrant   = "Tempo Tyrant"      // 70–79
    static let overlord = "Attention Overlord"// 80–89
    static let noLifer  = "Focus No Lifer"    // 90–100
}

enum PlayerTitleConfig {
    static let levelTitles: [LevelTitleDefinition] = [
        .init(minLevel: 1,  title: PlayerTitles.rookie),
        .init(minLevel: 10, title: PlayerTitles.worker),
        .init(minLevel: 20, title: PlayerTitles.knight),
        .init(minLevel: 30, title: PlayerTitles.master),
        .init(minLevel: 40, title: PlayerTitles.sage),
        .init(minLevel: 50, title: PlayerTitles.fiend),
        .init(minLevel: 60, title: PlayerTitles.guardian),
        .init(minLevel: 70, title: PlayerTitles.tyrant),
        .init(minLevel: 80, title: PlayerTitles.overlord),
        .init(minLevel: 90, title: PlayerTitles.noLifer)
    ]

    static func unlockedLevelTitles(for level: Int) -> [String] {
        levelTitles
            .filter { level >= $0.minLevel }
            .map { $0.title }
    }

    static func bestTitle(for level: Int) -> String {
        unlockedLevelTitles(for: level).last ?? PlayerTitles.rookie
    }
}

struct PlayerCardView: View {
    @ObservedObject var store: SessionStatsStore
    @ObservedObject var statsViewModel: StatsViewModel
    @ObservedObject var healthBarViewModel: HealthBarViewModel
    @ObservedObject var focusViewModel: FocusViewModel
    @ObservedObject var dailyRatingsStore: DailyHealthRatingsStore = DependencyContainer.shared.dailyHealthRatingsStore
    let isEmbedded: Bool
    @State private var isTitlePickerPresented = false
    @State private var moodSliderValue: Int?
    @State private var gutSliderValue: Int?
    @State private var sleepSliderValue: Int?

    @AppStorage("playerDisplayName") private var playerDisplayName: String = QuestChatStrings.PlayerCard.defaultName

    init(
        store: SessionStatsStore,
        statsViewModel: StatsViewModel,
        healthBarViewModel: HealthBarViewModel,
        focusViewModel: FocusViewModel,
        isEmbedded: Bool = false
    ) {
        _store = ObservedObject(wrappedValue: store)
        _statsViewModel = ObservedObject(wrappedValue: statsViewModel)
        _healthBarViewModel = ObservedObject(wrappedValue: healthBarViewModel)
        _focusViewModel = ObservedObject(wrappedValue: focusViewModel)
        self.isEmbedded = isEmbedded
    }

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
        ZStack {
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

            // Level-up overlay when Player Card is presented as a sheet
            if let levelUp = store.pendingLevelUp {
                LevelUpModalView(level: levelUp) {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        store.pendingLevelUp = nil
                    }
                }
                .zIndex(100)
                .transition(.opacity.combined(with: .scale))
            }
        }
        .background(Color.black.ignoresSafeArea())
        // Removed onAppear to rely solely on DailyHealthRatingsStore as canonical source for slider values
        .sheet(isPresented: $isTitlePickerPresented) {
            NavigationStack {
                VStack(spacing: 16) {
                    List {
                        Section("Level titles") {
                            ForEach(PlayerTitleConfig.unlockedLevelTitles(for: store.level), id: \.self) { title in
                                Button {
                                    // Treat level titles as the base track: clear any override and set base to this selection via the view model.
                                    statsViewModel.setBaseLevelTitle(title)
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

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Status")
                .font(.headline)

            DailyVitalsSlidersView(
                dailyRatingsStore: dailyRatingsStore,
                healthBarViewModel: healthBarViewModel,
                focusViewModel: focusViewModel
            )
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemBackground).opacity(0.18))
        .cornerRadius(16)
    }
}

/// Shared sliders for daily vitals (mood, gut, sleep, activity) used across the app and onboarding
/// so updates only need to be made in one place.
struct DailyVitalsSlidersView: View {
    @ObservedObject var dailyRatingsStore: DailyHealthRatingsStore
    @ObservedObject var healthBarViewModel: HealthBarViewModel
    @ObservedObject var focusViewModel: FocusViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
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
    }

    private var sleepQualityBinding: Binding<Int?> {
        Binding<Int?>(
            get: { dailyRatingsStore.ratings().sleep },
            set: { newValue in
                dailyRatingsStore.setSleep(newValue)
                focusViewModel.sleepQuality = HealthRatingMapper.sleepQuality(for: newValue ?? 3) ?? .okay
            }
        )
    }

    private var moodRatingBinding: Binding<Int?> {
        Binding<Int?>(
            get: { dailyRatingsStore.ratings().mood },
            set: { newValue in
                let previous = dailyRatingsStore.ratings().mood
                dailyRatingsStore.setMood(newValue)
                let status = HealthRatingMapper.moodStatus(for: newValue)
                healthBarViewModel.setMoodStatus(status)
                if previous == nil, newValue != nil {
                    DependencyContainer.shared.questsViewModel.completeQuestIfNeeded(id: "DAILY_HB_MORNING_CHECKIN")
                }
            }
        )
    }

    private var gutRatingBinding: Binding<Int?> {
        Binding<Int?>(
            get: { dailyRatingsStore.ratings().gut },
            set: { newValue in
                dailyRatingsStore.setGut(newValue)
                let status = HealthRatingMapper.gutStatus(for: newValue)
                healthBarViewModel.setGutStatus(status)
            }
        )
    }

    private var activityRatingBinding: Binding<Int?> {
        Binding<Int?>(
            get: { dailyRatingsStore.ratings().activity },
            set: { newValue in
                dailyRatingsStore.setActivity(newValue)
                focusViewModel.activityLevel = HealthRatingMapper.activityLevel(for: newValue)
            }
        )
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
