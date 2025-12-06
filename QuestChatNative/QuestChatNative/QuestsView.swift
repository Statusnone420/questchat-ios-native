import SwiftUI

struct QuestsView: View {
    @ObservedObject var viewModel: QuestsViewModel
    @ObservedObject private var statsStore = DependencyContainer.shared.sessionStatsStore
    private let seasonAchievementsStore = DependencyContainer.shared.seasonAchievementsStore
    @State private var bouncingQuestIDs: Set<String> = []
    @State private var showingXPBoostIDs: Set<String> = []
    @State private var showingRerollPicker = false
    @State private var selectedScope: QuestScope = .daily

    enum QuestScope {
        case daily
        case weekly
    }

    var body: some View {
        ZStack {
            questsContent
        }
    }
}

private extension QuestsView {
    var questsContent: some View {
        List {
            Section {
                headerCard
            }
            .listRowInsets(EdgeInsets(top: 12, leading: 20, bottom: 6, trailing: 20))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

            Section {
                scopeToggle
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)

            if selectedScope == .daily {
                Section {
                    ForEach(viewModel.sortedDailyQuests) { quest in
                        let isEventDriven = viewModel.isEventDrivenQuest(quest)
                        QuestCardView(
                            quest: quest,
                            tierColor: tierColor(for: quest.tier),
                            isBouncing: bouncingQuestIDs.contains(quest.id),
                            isShowingXPBoost: showingXPBoostIDs.contains(quest.id),
                            onTap: isEventDriven ? nil : {
                                viewModel.toggleQuest(quest)
                            }
                        )
                        .allowsHitTesting(!isEventDriven)
                        .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
                        .listRowSeparator(.hidden)
                        .onChange(of: quest.isCompleted) { isCompleted in
                            guard isCompleted else { return }
                            triggerCheckmarkBounce(for: quest)
                            triggerXPFlash(for: quest)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            if !quest.isCompleted && !viewModel.hasUsedRerollToday {
                                Button {
                                    viewModel.reroll(quest: quest)
                                } label: {
                                    Label(QuestChatStrings.QuestsView.rerollActionTitle, systemImage: "arrow.triangle.2.circlepath")
                                }
                                .tint(.orange)
                            }
                        }
                    }
                }
                .textCase(nil)
                .listSectionSeparator(.hidden)

                Section {
                    rerollFooter
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 20, trailing: 20))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            } else {
                Section {
                    if viewModel.weeklyTotalCount > 0 {
                        Text("\(viewModel.weeklyCompletedCount) / \(viewModel.weeklyTotalCount) weekly quests complete")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .listRowInsets(EdgeInsets(top: 4, leading: 20, bottom: 6, trailing: 20))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                    }

                    ForEach(viewModel.sortedWeeklyQuests) { quest in
                        let isEventDriven = viewModel.isEventDrivenWeeklyQuest(quest)
                        QuestCardView(
                            quest: quest,
                            tierColor: tierColor(for: quest.tier),
                            isBouncing: bouncingQuestIDs.contains(quest.id),
                            isShowingXPBoost: showingXPBoostIDs.contains(quest.id),
                            onTap: isEventDriven ? nil : {
                                viewModel.toggleWeeklyQuest(quest)
                            }
                        )
                        .allowsHitTesting(!isEventDriven)
                        .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
                        .listRowSeparator(.hidden)
                        .onChange(of: quest.isCompleted) { isCompleted in
                            guard isCompleted else { return }
                            triggerCheckmarkBounce(for: quest)
                            triggerXPFlash(for: quest)
                        }
                    }
                }
                .textCase(nil)
                .listSectionSeparator(.hidden)

            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .scrollIndicators(.hidden)
        .background(Color.black.ignoresSafeArea())
        .overlay(alignment: .center) {
            if selectedScope == .daily && viewModel.hasQuestChestReady {
                questChestOverlay()
            }
        }
        .onAppear {
            viewModel.handleQuestLogOpenedIfNeeded()
            let today = Calendar.current.startOfDay(for: Date())
            seasonAchievementsStore.applyProgress(
                conditionType: .questsTabOpenedDaysStreak,
                amount: 1,
                date: today
            )
        }
        .confirmationDialog(QuestChatStrings.QuestsView.rerollDialogTitle, isPresented: $showingRerollPicker, titleVisibility: .visible) {
            let incompleteQuests = viewModel.incompleteQuests
            if incompleteQuests.isEmpty {
                Button(QuestChatStrings.QuestsView.rerollDialogEmpty) {}
            } else {
                ForEach(incompleteQuests) { quest in
                    Button(quest.title) {
                        viewModel.reroll(quest: quest)
                    }
                }
            }
            Button(QuestChatStrings.QuestsView.rerollCancel, role: .cancel) {}
        }
    }

    var headerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(selectedScope == .daily ? QuestChatStrings.QuestsView.headerTitle : "Weekly quests")
                        .font(.title2.bold())
                    if selectedScope == .daily {
                        Text(QuestChatStrings.QuestsView.headerSubtitle(completed: viewModel.completedQuestsCount, total: viewModel.totalQuestsCount, totalXP: viewModel.totalDailyXP))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("\(viewModel.weeklyCompletedCount) / \(viewModel.weeklyTotalCount) weekly quests complete")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }

            if selectedScope == .daily {
                if viewModel.hasQuestChestReady {
                    Button {
                        viewModel.claimQuestChest()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "gift.fill")
                                .foregroundStyle(.yellow)
                            Text(QuestChatStrings.QuestsView.questChestReady)
                                .font(.subheadline.weight(.semibold))
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.yellow.opacity(0.15))
                        .foregroundStyle(.yellow)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                } else if !viewModel.allQuestsComplete {
                    Text(viewModel.allCoreDailyQuestsCompleted ? "Core quests complete – finish habits for extra XP." : QuestChatStrings.QuestsView.chestProgress(viewModel.remainingQuestsUntilChest))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    Text(QuestChatStrings.QuestsView.chestClaimed)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemBackground).opacity(0.18))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    var scopeToggle: some View {
        HStack(spacing: 10) {
            scopeButton(for: .daily, title: "Daily")
            scopeButton(for: .weekly, title: "Weekly")
        }
    }

    func scopeButton(for scope: QuestScope, title: String) -> some View {
        let isSelected = selectedScope == scope

        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedScope = scope
            }
        } label: {
            Text(title)
                .font(.subheadline.bold())
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(isSelected ? Color.white.opacity(0.18) : Color(uiColor: .secondarySystemBackground).opacity(0.16))
                .foregroundStyle(isSelected ? .primary : .secondary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    var rerollFooter: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(QuestChatStrings.QuestsView.rerollFooterDescription)
                .font(.footnote)
                .foregroundStyle(.secondary)

            if viewModel.canRerollToday {
                Button {
                    showingRerollPicker = true
                } label: {
                    HStack {
                        Text(QuestChatStrings.QuestsView.rerollButtonTitle)
                            .font(.subheadline.bold())
                        Spacer()
                        Image(systemName: "arrow.triangle.2.circlepath")
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color(uiColor: .secondarySystemBackground).opacity(0.18))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
            } else {
                Text(QuestChatStrings.QuestsView.rerollUsed)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    func triggerCheckmarkBounce(for quest: Quest) {
        bouncingQuestIDs.insert(quest.id)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            withAnimation(.interpolatingSpring(stiffness: 250, damping: 12)) {
                _ = bouncingQuestIDs.remove(quest.id)
            }
        }
    }

    func triggerXPFlash(for quest: Quest) {
        showingXPBoostIDs.insert(quest.id)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeOut(duration: 0.5)) {
                _ = showingXPBoostIDs.remove(quest.id)
            }
        }
    }

    func tierColor(for tier: Quest.Tier) -> Color {
        switch tier {
        case .core:
            .blue
        case .habit:
            .teal
        case .bonus:
            .purple
        }
    }

    @ViewBuilder
    func questChestOverlay() -> some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: "gift.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.yellow)

                Text(QuestChatStrings.QuestsView.questChestClearedTitle)
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)

                Text(QuestChatStrings.QuestsView.questChestClearedBody(reward: viewModel.questChestRewardAmount))
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)

                Button {
                    viewModel.claimQuestChest()
                } label: {
                    Text(QuestChatStrings.QuestsView.claimRewardButton)
                        .font(.headline)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                        .background(.mint)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
            .padding(24)
            .background(Color(.systemBackground))
            .cornerRadius(20)
            .shadow(radius: 16)
            .padding()
        }
    }
}

private struct QuestCardView: View {
    let quest: Quest
    let tierColor: Color
    let isBouncing: Bool
    let isShowingXPBoost: Bool
    let onTap: (() -> Void)?

    var body: some View {
        let isCompleted = quest.isCompleted
        Button(action: {
            onTap?()
        }) {
            ZStack(alignment: .topTrailing) {
                HStack(alignment: .top, spacing: 12) {
                    icon
                        .font(.title3)
                        .foregroundStyle(iconColor)
                        .scaleEffect(isBouncing ? 1.12 : 1.0)
                        .animation(.interpolatingSpring(stiffness: 250, damping: 12), value: isBouncing)

                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .center) {
                            tierPill
                            Spacer()
                            VStack(alignment: .trailing, spacing: 4) {
                                xpPill

                                if quest.isCompleted {
                                    completedPill
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(quest.title)
                                .font(.headline)
                                .foregroundStyle(.primary)
                            Text(quest.detail)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            if shouldShowProgressBar {
                                QuestProgressView(
                                    fraction: quest.progressFraction,
                                    label: "\(quest.progress) / \(quest.target)"
                                )
                                .padding(.top, 4)
                            }
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(uiColor: .secondarySystemBackground).opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                if isShowingXPBoost {
                    Text(QuestChatStrings.xpRewardText(quest.xpReward))
                        .font(.caption.bold())
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.mint.opacity(0.2))
                        .foregroundStyle(.mint)
                        .clipShape(Capsule())
                        .offset(y: -12)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .animation(.easeOut(duration: 0.4), value: isShowingXPBoost)
                }
            }
        }
        .buttonStyle(.plain)
        .opacity(isCompleted ? 0.6 : 1.0)
    }

    private var icon: some View {
        let iconName: String
        if quest.isCompleted {
            iconName = "checkmark.circle.fill"
        } else {
            switch quest.tier {
            case .core:
                iconName = "target"
            case .habit:
                iconName = "leaf.fill"
            case .bonus:
                iconName = "sparkles"
            }
        }

        return Image(systemName: iconName)
    }

    private var iconColor: Color {
        quest.isCompleted ? .mint : tierColor
    }

    private var tierPill: some View {
        Text(quest.tier.displayName)
            .font(.caption2.bold())
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(tierColor.opacity(0.18))
            .foregroundStyle(tierColor)
            .clipShape(Capsule())
    }

    private var xpPill: some View {
        Text(QuestChatStrings.xpRewardText(quest.xpReward))
            .font(.caption.bold())
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.mint.opacity(0.18))
            .foregroundStyle(.mint)
            .clipShape(Capsule())
    }

    private var completedPill: some View {
        Text("Completed")
            .font(.caption2)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(Color.secondary.opacity(0.25)))
            .foregroundStyle(.secondary)
    }

    private var shouldShowProgressBar: Bool {
        if quest.type == .weekly {
            return quest.target > 1
        }

        return quest.hasProgress
    }
}

private struct QuestProgressView: View {
    let fraction: Double
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ProgressView(value: fraction)
                .progressViewStyle(.linear)
                .tint(.mint)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    QuestsView(viewModel: DependencyContainer.shared.questsViewModel)
}
