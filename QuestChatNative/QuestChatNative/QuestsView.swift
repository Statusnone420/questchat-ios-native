import SwiftUI

struct QuestsView: View {
    @ObservedObject var viewModel: QuestsViewModel
    @State private var bouncingQuestIDs: Set<String> = []
    @State private var showingXPBoostIDs: Set<String> = []

    var body: some View {
        List {
            Section("Daily quests") {
                ForEach(viewModel.dailyQuests) { quest in
                    Button {
                        viewModel.toggleQuest(quest)
                    } label: {
                        ZStack(alignment: .trailing) {
                            HStack(alignment: .firstTextBaseline, spacing: 12) {
                                Image(systemName: quest.isCompleted ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(quest.isCompleted ? .mint : .gray)
                                    .imageScale(.large)
                                    .scaleEffect(bouncingQuestIDs.contains(quest.id) ? 1.15 : 1.0)
                                    .animation(.interpolatingSpring(stiffness: 250, damping: 12), value: bouncingQuestIDs.contains(quest.id))

                                VStack(alignment: .leading, spacing: 6) {
                                    HStack(spacing: 6) {
                                        Text(quest.title)
                                            .font(.headline)
                                            .foregroundStyle(.primary)
                                        tierPill(for: quest)
                                    }

                                    Text(quest.detail)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Text("+\(quest.xpReward) XP")
                                    .font(.caption)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(.mint.opacity(0.15))
                                    .foregroundStyle(.mint)
                                    .clipShape(Capsule())
                            }

                            xpFlash(for: quest)
                        }
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(Color(.secondarySystemBackground))
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
        }
        .scrollContentBackground(.hidden)
        .background(Color.black.ignoresSafeArea())
        .overlay(alignment: .center) {
            if viewModel.hasQuestChestReady {
                questChestOverlay()
            }
        }
    }
}

private extension QuestsView {
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

    @ViewBuilder
    func xpFlash(for quest: Quest) -> some View {
        let isShowingBoost = showingXPBoostIDs.contains(quest.id)

        Text("+\(quest.xpReward) XP")
            .font(.caption.bold())
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.mint.opacity(0.2))
            .foregroundStyle(.mint)
            .clipShape(Capsule())
            .opacity(isShowingBoost ? 1 : 0)
            .offset(y: isShowingBoost ? -8 : -20)
            .animation(.easeOut(duration: 0.5), value: isShowingBoost)
    }

    @ViewBuilder
    func tierPill(for quest: Quest) -> some View {
        Text(quest.tier.displayName)
            .font(.caption2)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(tierColor(for: quest.tier).opacity(0.15))
            .foregroundStyle(tierColor(for: quest.tier))
            .clipShape(Capsule())
    }

    func tierColor(for tier: Quest.Tier) -> Color {
        switch tier {
        case .core:
            return .blue
        case .habit:
            return .teal
        case .bonus:
            return .purple
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

#Preview {
    QuestsView(viewModel: QuestsViewModel())
}
