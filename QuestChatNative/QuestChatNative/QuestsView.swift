import SwiftUI

struct QuestsView: View {
    @ObservedObject var viewModel: QuestsViewModel

    var body: some View {
        List {
            Section("Daily quests") {
                ForEach(viewModel.dailyQuests) { quest in
                    Button {
                        viewModel.toggleQuest(quest)
                    } label: {
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            Image(systemName: quest.isCompleted ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(quest.isCompleted ? .mint : .gray)
                                .imageScale(.large)

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
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(Color(.secondarySystemBackground))
                }
            }
            .textCase(nil)
        }
        .scrollContentBackground(.hidden)
        .background(Color.black.ignoresSafeArea())
    }
}

#Preview {
    QuestsView(viewModel: QuestsViewModel())
}
