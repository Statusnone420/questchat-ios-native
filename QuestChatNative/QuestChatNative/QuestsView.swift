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

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(quest.title)
                                        .font(.headline)
                                        .foregroundStyle(.primary)
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
                }
            }
            .textCase(nil)
        }
        .scrollContentBackground(.hidden)
        .background(Color.black.ignoresSafeArea())
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
}

#Preview {
    QuestsView(viewModel: QuestsViewModel())
}
