import SwiftUI
import SwiftUI
import Lottie

struct StatsView: View {
    @ObservedObject var store: SessionStatsStore
    @ObservedObject var viewModel: StatsViewModel
    @ObservedObject var questsViewModel: QuestsViewModel
    @ObservedObject var healthBarViewModel: HealthBarViewModel
    @ObservedObject var focusViewModel: FocusViewModel
    @State private var selectedScope: StatsScope = .today
    @State private var selectedAchievement: SeasonAchievement?
    @State private var isShowingDailySetup = false
    @State private var sakuraTrigger = UUID()
    @State private var statsWaveTrigger = UUID()
#if DEBUG
    @State private var shouldPostAchievementNotifications = false
#endif

    private var focusMinutes: Int { store.focusSeconds / 60 }
    private var selfCareMinutes: Int { store.selfCareSeconds / 60 }
    private var focusMinutesToday: Int { store.todayProgress?.focusMinutes ?? store.focusSecondsToday / 60 }
    private var selfCareMinutesToday: Int { store.selfCareSecondsToday / 60 }
    private var dailyGoalMinutes: Int { store.todayPlan?.focusGoalMinutes ?? 40 }
    private var dailyGoalProgress: Int { store.todayProgress?.focusMinutes ?? store.dailyMinutesProgress }
    private var focusAreaLabel: String? {
        guard let area = store.todayPlan?.focusArea else { return nil }
        return "\(area.icon) \(area.displayName)"
    }
    private var reachedFocusGoal: Bool { store.todayProgress?.reachedFocusGoal ?? false }
    private var scopeTitle: String { selectedScope == .today ? "Today" : "Yesterday" }
    private var dailyGoalMinutesForScope: Int { dailyGoalMinutes }
    private var dailyGoalProgressForScope: Int { dailyGoalProgress }
    private var reachedFocusGoalForScope: Bool { reachedFocusGoal }
    private var focusAreaLabelForScope: String? { focusAreaLabel }
    private var focusGoalLabel: String { QuestChatStrings.StatsView.todaysFocusGoal }
    private var focusGoalProgressText: String {
        QuestChatStrings.StatsView.dailyGoalProgress(current: dailyGoalProgressForScope, total: dailyGoalMinutesForScope)
    }
    private var recentSessions: [SessionStatsStore.SessionRecord] {
        Array(store.sessionHistory.suffix(5).reversed())
    }

    private var weeklyGoalProgress: [SessionStatsStore.WeeklyGoalDayStatus] {
        store.weeklyGoalProgress
    }

    private var healthBarWeeklySummary: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.subheadline)
                    .foregroundStyle(.mint)
                Text("HealthBar IRL – Last 7 Days")
                    .font(.headline)
            }

            if viewModel.last7Days.isEmpty {
                Text("No recent HealthBar data yet.")
                    .foregroundStyle(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(uiColor: .secondarySystemBackground).opacity(0.15))
                    .cornerRadius(16)
            } else {
                VStack(spacing: 8) {
                    ForEach(viewModel.last7Days) { day in
                        healthDayRow(day)
                    }
                }
                .padding(12)
                .background(Color(uiColor: .secondarySystemBackground).opacity(0.15))
                .cornerRadius(16)
            }
        }
    }

    private var scopePicker: some View {
        Picker("Stats range", selection: $selectedScope) {
            Text("Today").tag(StatsScope.today)
            Text("Yesterday").tag(StatsScope.yesterday)
        }
        .pickerStyle(.segmented)
    }
    
    private var statsHeaderWithWave: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Stats")
                    .font(.largeTitle.bold())
                    .foregroundColor(.white)
                Spacer()
            }
            
            ZStack {
                LottieView(
                    animationName: "WaveLoop",
                    loopMode: .loop,
                    animationSpeed: 0.5,
                    contentMode: .scaleAspectFill,
                    animationTrigger: statsWaveTrigger,
                    freezeOnLastFrame: false,
                    tintColor: UIColor(red: 0.3, green: 0.7, blue: 1.0, alpha: 1.0)
                )
                .frame(height: 70)
                .opacity(0.22)
                .allowsHitTesting(false)
                
                scopePicker
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
            }
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemBackground))
            )
        }
    }

    private var todayContent: some View {
        VStack(spacing: 18) {
            TodaySummaryView(
                title: scopeTitle,
                completedQuests: questsViewModel.completedQuestsCount,
                totalQuests: questsViewModel.totalQuestsCount,
                focusMinutes: focusMinutesToday,
                focusGoalMinutes: dailyGoalMinutes,
                reachedFocusGoal: reachedFocusGoal,
                focusAreaLabel: focusAreaLabel,
                currentStreakDays: store.currentStreakDays
            )

            dailyGoalCard
            reopenDailySetupButton
            weeklyPathCard
            achievementsSection
            healthBarWeeklySummary

            summaryTiles
            sessionBreakdown
            sessionHistorySection

#if DEBUG
            debugSeasonAchievementsSection
#endif
        }
    }

    private var reopenDailySetupButton: some View {
        Button {
            isShowingDailySetup = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "sun.max.circle.fill")
                    .foregroundStyle(.mint)
                Text("Re-open Daily Setup for today")
                    .font(.subheadline.bold())
                Spacer(minLength: 0)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.mint.opacity(0.18))
            .foregroundStyle(.mint)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var yesterdayContent: some View {
        VStack(spacing: 18) {
            yesterdaySummaryCard
            yesterdayStreakCard
            yesterdayAchievementsSection
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ScrollView (.vertical, showsIndicators: false) {
                    VStack(spacing: 18) {
                        statsHeaderWithWave
                        
                        if selectedScope == .today {
                            todayContent
                        } else {
                            yesterdayContent
                        }
                    }
                    .padding(20)
                }
            .background(Color.black.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)

                if let unlocked = viewModel.unlockedAchievementToShow {
                    AchievementUnlockOverlayView(
                        achievement: unlocked,
                        xpReward: 500,
                        onEquipTitle: {
                            viewModel.equipTitle(for: unlocked)
                            viewModel.unlockedAchievementToShow = nil
                        },
                        onDismiss: {
                            viewModel.unlockedAchievementToShow = nil
                        }
                    )
                    .transition(.opacity.combined(with: .scale))
                    .zIndex(10)
                }
            }
            .animation(.easeInOut, value: viewModel.unlockedAchievementToShow != nil)
            .onAppear {
                questsViewModel.handleQuestEvent(.statsViewed(scope: selectedScope))
            }
            .onChange(of: selectedScope) { newScope in
                questsViewModel.handleQuestEvent(.statsViewed(scope: newScope))
            }
        }
        .sheet(isPresented: $isShowingDailySetup) {
            DailySetupSheet(
                initialFocusArea: store.todayPlan?.focusArea ?? .work,
                initialEnergyLevel: store.todayPlan?.energyLevel ?? .medium
            ) { focusArea, energyLevel in
                store.completeDailyConfig(focusArea: focusArea, energyLevel: energyLevel)
                questsViewModel.markCoreQuests(for: focusArea)
            }
            .presentationDetents([.medium])
            .interactiveDismissDisabled()
        }
        .sheet(item: $selectedAchievement) { achievement in
            SeasonAchievementDetailView(
                achievement: achievement,
                progress: viewModel.progress(for: achievement)
            )
            .presentationDetents([.medium, .large])
        }
    }

    private func healthDayRow(_ day: HealthDaySummary) -> some View {
        VStack(spacing: 10) {
            // Header row with date and HP
            HStack(alignment: .firstTextBaseline) {
                Text(viewModel.label(for: day.date))
                    .font(.subheadline.bold())
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "heart.fill")
                        .font(.caption2)
                        .foregroundStyle(.red)
                    Text("\(Int(day.averageHP.rounded())) HP")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            
            // Activity metrics grid
            HStack(spacing: 12) {
                // Hydration
                HStack(spacing: 4) {
                    Image(systemName: "drop.fill")
                        .font(.caption)
                        .foregroundStyle(.blue)
                    Text("\(day.hydrationOunces)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.primary)
                    Text("oz")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Self-care sessions
                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                        .font(.caption)
                        .foregroundStyle(.cyan)
                    Text("\(day.selfCareCount)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.primary)
                    Text("Self-care session\(day.selfCareCount == 1 ? "" : "s")")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            HStack(spacing: 12) {
                // Focus sessions
                HStack(spacing: 4) {
                    Image(systemName: "bolt.fill")
                        .font(.caption)
                        .foregroundStyle(.mint)
                    Text("\(day.focusCount)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.primary)
                    Text("Focus session\(day.focusCount == 1 ? "" : "s")")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Gut & Mood status
                HStack(spacing: 8) {
                    HStack(spacing: 4) {
                        Image(systemName: "heart.text.square.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                        Text(gutLabel(for: day.lastGut))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    HStack(spacing: 4) {
                        Image(systemName: "face.smiling.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                        Text(moodLabel(for: day.lastMood))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding(12)
        .background(Color(uiColor: .tertiarySystemBackground).opacity(0.5))
        .cornerRadius(12)
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

    private var yesterdaySummaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Label("Yesterday", systemImage: "clock.arrow.circlepath")
                    .font(.headline)
                    .foregroundStyle(.mint.opacity(0.9))
                Spacer()
            }

            if let summary = viewModel.yesterdaySummary {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Quests: \(summary.questsCompleted) / \(summary.totalQuests) completed")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 8) {
                        Text("Focus: \(summary.focusMinutes) / \(summary.focusGoalMinutes) minutes")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        if summary.reachedFocusGoal {
                            Text("Goal hit!")
                                .font(.caption.bold())
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.mint.opacity(0.15))
                                .foregroundColor(.mint)
                                .cornerRadius(10)
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Overall progress: \(Int(summary.overallProgress * 100))%")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        ProgressView(value: summary.overallProgress)
                            .progressViewStyle(.linear)
                            .tint(.mint)
                    }

                    Divider().padding(.vertical, 6)

                    VStack(alignment: .leading, spacing: 8) {
                        // Hydration
                        HStack(spacing: 8) {
                            Image(systemName: "drop.fill").foregroundStyle(.cyan)
                            let goalText = summary.hydrationGoalOunces > 0 ? " / \(summary.hydrationGoalOunces) oz" : " oz"
                            Text("Hydration: \(summary.hydrationOunces)\(goalText)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        if summary.hydrationGoalOunces > 0 {
                            ProgressView(value: summary.hydrationProgress)
                                .progressViewStyle(.linear)
                                .tint(.cyan)
                        }

                        // Sleep
                        HStack(spacing: 8) {
                            Image(systemName: "moon.fill").foregroundStyle(.purple)
                            Text("Sleep: \(summary.sleepQuality?.label ?? "—")")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        // Mood
                        HStack(spacing: 8) {
                            Image(systemName: "face.smiling").foregroundStyle(.green)
                            let moodLabel: String = {
                                switch summary.mood ?? .none {
                                case .good: return "Good"
                                case .neutral: return "Neutral"
                                case .bad: return "Bad"
                                case .none: return "—"
                                }
                            }()
                            Text("Mood: \(moodLabel)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    // Gut and HP
                    Divider().padding(.vertical, 6)

                    HStack(spacing: 12) {
                        HStack(spacing: 6) {
                            Image(systemName: "heart.text.square").foregroundStyle(.orange)
                            let gutLabel: String = {
                                switch summary.gutStatus ?? .none {
                                case .great: return "Great"
                                case .meh: return "Meh"
                                case .rough: return "Rough"
                                case .none: return "—"
                                }
                            }()
                            Text("Gut: \(gutLabel)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        HStack(spacing: 6) {
                            Image(systemName: "cross.case.fill").foregroundStyle(.red)
                            Text("Avg HP: \(summary.averageHP.map(String.init) ?? "—")")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } else {
                Text("No stats for yesterday yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemBackground).opacity(0.12))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }

    private var yesterdayStreakCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Weekly streak as of yesterday", systemImage: "calendar.badge.clock")
                .font(.headline)
                .foregroundStyle(.orange)

            if let maintained = viewModel.wasStreakMaintainedYesterday {
                Text(maintained ? "Streak: maintained ✅" : "Streak: broken ☠️")
                    .font(.subheadline.bold())
                    .foregroundStyle(maintained ? .mint : .red)

                if viewModel.yesterdayStreakDots.isEmpty {
                    Text("No streak data for yesterday yet.")
                        .foregroundStyle(.secondary)
                        .font(.footnote)
                } else {
                    compactWeeklyDots(for: viewModel.yesterdayStreakDots)
                }
            } else {
                Text("No streak data for yesterday yet.")
                    .foregroundStyle(.secondary)
                    .font(.footnote)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemBackground).opacity(0.16))
        .cornerRadius(14)
    }

    private var yesterdayAchievementsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Season achievements from yesterday")
                .font(.headline)

            if viewModel.yesterdayUnlockedAchievements.isEmpty {
                Text("No new achievements yesterday. Today’s a good day to change that.")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 16) {
                    ForEach(viewModel.yesterdayUnlockedAchievements) { item in
                        Button {
                            selectAchievement(item)
                        } label: {
                            SeasonAchievementBadgeView(
                                title: item.title,
                                iconName: item.iconName,
                                isUnlocked: item.isUnlocked,
                                progressFraction: CGFloat(item.progressFraction)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemBackground).opacity(0.15))
        .cornerRadius(16)
    }

    private func compactWeeklyDots(for days: [SessionStatsStore.WeeklyGoalDayStatus]) -> some View {
        HStack(spacing: 8) {
            ForEach(days) { day in
                ZStack {
                    Circle()
                        .fill(day.goalHit ? Color.mint : Color.clear)
                        .frame(width: 12, height: 12)
                        .overlay(
                            Circle()
                                .stroke(day.goalHit ? Color.mint : Color.secondary.opacity(0.6), lineWidth: 2)
                        )
                        .opacity(day.goalHit ? 1 : 0.7)

                    if day.isToday {
                        Circle()
                            .stroke(Color.white.opacity(0.35), lineWidth: 3)
                            .frame(width: 18, height: 18)
                    }
                }
                .accessibilityLabel(day.date.formatted(date: .abbreviated, time: .omitted))
                .accessibilityValue(day.goalHit ? QuestChatStrings.StatsView.weeklyGoalMet : QuestChatStrings.StatsView.weeklyGoalNotMet)
            }
        }
    }

    private func selectAchievement(_ item: StatsViewModel.SeasonAchievementItemViewModel) {
        guard let achievement = viewModel.achievement(for: item.id) else { return }
        selectedAchievement = achievement
    }

    private var summaryTiles: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                statCardWithBoost(title: QuestChatStrings.StatsView.summaryXPTileTitle, value: "\(store.xp)", icon: "sparkles", tint: .mint, boostLabel: viewModel.xpBoostLabel)
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

    private var achievementsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 🌸 Proper header card with Sakura (Quests-style)
            ZStack(alignment: .topLeading) {
                // Sakura background animation
                LottieView(
                    animationName: "sakura_branch",
                    loopMode: .loop,
                    animationSpeed: 1.0,
                    contentMode: .scaleAspectFill,
                    animationTrigger: sakuraTrigger,
                    freezeOnLastFrame: false
                )
                .frame(height: 120)
                .opacity(0.25)
                .offset(x: -16, y: -12)
                .allowsHitTesting(false)
                
                // Header content
                VStack(alignment: .leading, spacing: 4) {
                    Text("Season Achievements")
                        .font(.title3.bold())
                        .foregroundStyle(.primary)
                    
                    Text("Track your long-term progress and unlock rewards")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(uiColor: .secondarySystemBackground).opacity(0.45))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [Color.mint.opacity(0.5), Color.cyan.opacity(0.35), Color.purple.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            
            // 🏆 Achievements grid
            if viewModel.seasonAchievements.isEmpty {
                Text("No achievements available yet.")
                    .foregroundStyle(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(uiColor: .secondarySystemBackground).opacity(0.15))
                    .cornerRadius(12)
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 16) {
                    ForEach(viewModel.seasonAchievements) { item in
                        Button {
                            selectAchievement(item)
                        } label: {
                            SeasonAchievementBadgeView(
                                title: item.title,
                                iconName: item.iconName,
                                isUnlocked: item.isUnlocked,
                                progressFraction: CGFloat(item.progressFraction)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(uiColor: .secondarySystemBackground).opacity(0.15))
                .cornerRadius(12)
            }
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
    
    private func statCardWithBoost(title: String, value: String, icon: String, tint: Color, boostLabel: String?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 0) {
                Label(title, systemImage: icon)
                    .font(.headline)
                    .foregroundStyle(tint)
                    .fixedSize(horizontal: true, vertical: false)
                
                if let label = boostLabel {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                            .font(.caption2)
                        
                        Text(label)
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color.cyan.opacity(0.7),
                                        Color.purple.opacity(0.7)
                                    ]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    )
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.3), lineWidth: 0.5)
                    )
                    .foregroundColor(.white)
                    .fixedSize(horizontal: true, vertical: true)
                    .padding(.leading, 6)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .frame(height: 20)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: boostLabel != nil)
            
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
            Label("Focus Goal Streak", systemImage: "chart.dots.scatter")
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

            Text("Current streak: \(store.currentGoalStreak) day\(store.currentGoalStreak == 1 ? "" : "s")")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemBackground).opacity(0.16))
        .cornerRadius(14)
    }

    private var dailyGoalCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(focusGoalLabel, systemImage: "target")
                    .font(.headline)
                    .foregroundStyle(.mint)
                Spacer()
                if let label = focusAreaLabelForScope {
                    Text(label)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Text(focusGoalProgressText)
                .font(.subheadline.bold())

            ProgressView(value: Double(min(dailyGoalProgressForScope, dailyGoalMinutesForScope)), total: Double(dailyGoalMinutesForScope))
                .tint(.mint)

            if reachedFocusGoalForScope {
                Text("Goal hit! 🎯")
                    .font(.caption.bold())
                    .foregroundColor(.mint)
            }
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

#if DEBUG
    private var debugSeasonAchievementsSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                Toggle("Post notifications", isOn: $shouldPostAchievementNotifications)
                    .tint(.mint)

                Button {
                    viewModel.unlockAllSeasonAchievementsForDebug(
                        postNotifications: shouldPostAchievementNotifications
                    )
                } label: {
                    Label("Unlock all Season Achievement Progress", systemImage: "sparkles")
                }
                .disabled(!viewModel.hasLockedSeasonAchievements)

                Text("Unlocks every remaining Season achievement for debugging. Enable notifications to preview unlock overlays; tap slowly to avoid spamming.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } header: {
            Text("Debug: Season Achievement Progress")
        }
    }
#endif
}

#Preview {
    let container = DependencyContainer.shared
    StatsView(
        store: container.sessionStatsStore,
        viewModel: container.statsViewModel,
        questsViewModel: container.questsViewModel,
        healthBarViewModel: container.healthBarViewModel,
        focusViewModel: container.focusViewModel
    )
}
