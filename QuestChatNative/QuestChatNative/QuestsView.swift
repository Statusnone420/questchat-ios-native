import SwiftUI

struct QuestsView: View {
    @ObservedObject var viewModel: QuestsViewModel
    @State private var bouncingQuestIDs: Set<String> = []
    @State private var showingXPBoostIDs: Set<String> = []
    @State private var showingRerollPicker = false

    var body: some View {
        List {
            Section {
                headerCard
            }
            .listRowInsets(EdgeInsets(top: 12, leading: 20, bottom: 6, trailing: 20))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

            Section {
                ForEach(viewModel.dailyQuests) { quest in
                    QuestCardView(
                        quest: quest,
                        tierColor: tierColor(for: quest.tier),
                        isBouncing: bouncingQuestIDs.contains(quest.id),
                        isShowingXPBoost: showingXPBoostIDs.contains(quest.id),
                        onTap: {
                            viewModel.toggleQuest(quest)
                        }
                    )
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
                                Label("Reroll", systemImage: "arrow.triangle.2.circlepath")
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
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.black.ignoresSafeArea())
        .overlay(alignment: .center) {
            if viewModel.hasQuestChestReady {
                questChestOverlay()
            }
        }
        .confirmationDialog("Reroll a quest", isPresented: $showingRerollPicker, titleVisibility: .visible) {
            let incompleteQuests = viewModel.incompleteQuests
            if incompleteQuests.isEmpty {
                Button("No incomplete quests") {}
            } else {
                ForEach(incompleteQuests) { quest in
                    Button(quest.title) {
                        viewModel.reroll(quest: quest)
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        }
    }
}

private extension QuestsView {
    var headerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Daily quests")
                        .font(.title2.bold())
                    Text("\(viewModel.completedQuestsCount) / \(viewModel.totalQuestsCount) complete • \(viewModel.totalDailyXP) XP total")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            if viewModel.hasQuestChestReady {
                Button {
                    viewModel.claimQuestChest()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "gift.fill")
                            .foregroundStyle(.yellow)
                        Text("Quest Chest ready – tap to claim bonus XP")
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
                Text("Complete \(viewModel.remainingQuestsUntilChest) more quests to unlock the chest")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Text("Quest Chest claimed for today")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemBackground).opacity(0.18))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    var rerollFooter: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("You can reroll one incomplete quest per day.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            if viewModel.canRerollToday {
                Button {
                    showingRerollPicker = true
                } label: {
                    HStack {
                        Text("Reroll a quest")
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
                Text("Reroll used for today")
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

                Text("Daily quests cleared!")
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)

                Text("You unlocked a Quest Chest for +\(viewModel.questChestRewardAmount) XP. Keep the streak alive!")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)

                Button {
                    viewModel.claimQuestChest()
                } label: {
                    Text("Claim reward")
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
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
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
                            xpPill
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(quest.title)
                                .font(.headline)
                                .foregroundStyle(.primary)
                                .opacity(contentOpacity)
                            Text(quest.detail)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .opacity(contentOpacity)
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(uiColor: .secondarySystemBackground).opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                if isShowingXPBoost {
                    Text("+\(quest.xpReward) XP")
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
            .opacity(contentOpacity)
    }

    private var xpPill: some View {
        Text("+\(quest.xpReward) XP")
            .font(.caption.bold())
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.mint.opacity(0.18))
            .foregroundStyle(.mint)
            .clipShape(Capsule())
            .opacity(contentOpacity)
    }

    private var contentOpacity: Double {
        quest.isCompleted ? 0.6 : 1.0
    }
}

#Preview {
    QuestsView(viewModel: QuestsViewModel())
}
