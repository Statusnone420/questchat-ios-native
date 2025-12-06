import SwiftUI

struct HealthBarView: View {
    @StateObject var viewModel: HealthBarViewModel
    @ObservedObject var focusViewModel: FocusViewModel
    @ObservedObject var statsStore: SessionStatsStore
    @ObservedObject var statsViewModel: StatsViewModel
    @Binding var selectedTab: MainTab
    @EnvironmentObject var questsViewModel: QuestsViewModel
    @ObservedObject var dailyRatingsStore: DailyHealthRatingsStore = DependencyContainer.shared.dailyHealthRatingsStore

    init(viewModel: HealthBarViewModel, focusViewModel: FocusViewModel, statsStore: SessionStatsStore, statsViewModel: StatsViewModel, selectedTab: Binding<MainTab>) {
        _viewModel = StateObject(wrappedValue: viewModel)
        _focusViewModel = ObservedObject(wrappedValue: focusViewModel)
        _statsStore = ObservedObject(wrappedValue: statsStore)
        _statsViewModel = ObservedObject(wrappedValue: statsViewModel)
        _selectedTab = selectedTab
    }

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 20) {
                    healthHeaderCard
                    vitalsCard
                    PotionsCard(
                        onHealthTap: { focusViewModel.logComfortBeverageTapped() },
                        onManaTap: { focusViewModel.logHydrationPillTapped() },
                        onStaminaTap: { focusViewModel.logStaminaPotionTapped() }
                    )
                    if questsViewModel.dailyQuests.first != nil {
                        Divider()
                            .padding(.vertical, 8)
                    }
                    todaysQuestCard
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .scrollBounceBehavior(.basedOnSize)
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("HP")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.black, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    @ViewBuilder
    private var todaysQuestCard: some View {
        if let quest = questsViewModel.dailyQuests.first {
            TodaysQuestCard(quest: quest) {
                selectedTab = .quests
            }
        }
    }

    private var healthHeaderCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("HealthBar IRL")
                    .font(.headline.weight(.semibold))
                Spacer()
                Text("Level \(viewModel.level)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            RPGStatBar(
                iconName: "heart.fill",
                label: "HP",
                color: .red,
                progress: viewModel.hpProgress,
                segments: viewModel.hpSegments
            )

            HStack {
                Spacer()
                Text("\(viewModel.currentHP) / \(viewModel.maxHP) HP")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 6) {
                ProgressView(value: viewModel.xpProgress, total: 1)
                    .tint(.mint)

                HStack {
                    Text("XP")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(viewModel.xpInCurrentLevel) / \(max(viewModel.xpToNextLevel, 1))")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                }
            }

            let ratings = dailyRatingsStore.ratings()
            let gutText = HealthRatingMapper.gutStatus(for: ratings.gut).displayText
            let moodText = HealthRatingMapper.moodStatus(for: ratings.mood).displayText
            let sleepText = HealthRatingMapper.label(for: ratings.sleep ?? 0)

            HStack(spacing: 10) {
                statusBadge(title: "Gut", value: gutText, systemImage: "heart.text.square", tint: .orange)
                statusBadge(title: "Mood", value: moodText, systemImage: "face.smiling", tint: .green)
                statusBadge(title: "Sleep", value: sleepText, systemImage: "moon.fill", tint: .purple)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemBackground).opacity(0.65))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var vitalsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .lastTextBaseline) {
                Text("Vitals")
                    .font(.headline.weight(.semibold))
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(viewModel.hydrationSummaryText)
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    if let cups = viewModel.hydrationCupsText {
                        Text(cups)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            StatusBarRow(
                iconName: "drop.fill",
                label: "Hydration",
                tint: .blue,
                progress: viewModel.hydrationProgress,
                segments: 10,
                detailText: viewModel.hydrationSummaryText
            )
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: viewModel.hydrationProgress)
            .scaleEffect(viewModel.hydrationProgressBump ? 1.02 : 1.0)
            .animation(.easeOut(duration: 0.2), value: viewModel.hydrationProgressBump)

            StatusBarRow(
                iconName: "moon.fill",
                label: "Sleep",
                tint: .purple,
                progress: sleepProgressVisual,
                segments: 8,
                detailText: viewModel.sleepStatusText
            )

            StatusBarRow(
                iconName: "face.smiling",
                label: "Mood",
                tint: .green,
                progress: moodProgressVisual,
                segments: 8,
                detailText: viewModel.moodStatusText
            )

            StatusBarRow(
                iconName: "bolt.fill",
                label: "Stamina",
                tint: .orange,
                progress: viewModel.staminaProgress,
                segments: 8,
                detailText: viewModel.staminaLabel
            )
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemBackground).opacity(0.45))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func statusBadge(title: String, value: String, systemImage: String, tint: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.caption.bold())
                .foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.subheadline.weight(.semibold))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemBackground).opacity(0.35))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
    
    private var moodProgressVisual: Double {
        // Visual-only: map the 1–5 slider directly to 0.0–1.0 so 5 shows full, 4 is slightly less, etc.
        let rating = dailyRatingsStore.ratings().mood
        guard let rating else { return 0 }
        let normalized = (Double(rating) - 1.0) / 4.0
        return min(max(normalized, 0), 1)
    }
    
    private var sleepProgressVisual: Double {
        // Visual-only: map the 1–5 slider directly to 0.0–1.0 so 5 shows full, 4 is slightly less, etc.
        let rating = dailyRatingsStore.ratings().sleep
        guard let rating else { return 0 }
        let normalized = (Double(rating) - 1.0) / 4.0
        return min(max(normalized, 0), 1)
    }
}

#Preview {
    let container = DependencyContainer.shared
    HealthBarView(
        viewModel: container.healthBarViewModel,
        focusViewModel: container.focusViewModel,
        statsStore: container.sessionStatsStore,
        statsViewModel: container.statsViewModel,
        selectedTab: .constant(.health)
    )
    .environmentObject(container.questsViewModel)
}

private extension MoodStatus {
    var displayText: String {
        switch self {
        case .good: return "Good"
        case .neutral: return "Okay"
        case .bad: return "Rough"
        case .none: return "Not set"
        }
    }
}

private extension GutStatus {
    var displayText: String {
        switch self {
        case .great: return "Great"
        case .meh: return "Okay"
        case .rough: return "Rough"
        case .none: return "Not set"
        }
    }
}
