import SwiftUI
import UIKit

struct TalentsView: View {
    @StateObject var viewModel: TalentsViewModel
    @State private var isShowingRespecConfirm = false

    private let columns: [GridItem] = Array(
        repeating: GridItem(.flexible(), spacing: 12, alignment: .top),
        count: 4
    )

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header

                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(viewModel.nodes) { node in
                        TalentNodeTile(
                            node: node,
                            rank: viewModel.rank(for: node),
                            isUnlocked: viewModel.isUnlocked(node),
                            canSpend: viewModel.canSpend(on: node)
                        ) {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                                viewModel.tap(node: node)
                            }
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }
                        .contentShape(Rectangle())
                        .highPriorityGesture(
                            LongPressGesture(minimumDuration: 0.35)
                                .onEnded { _ in
                                    viewModel.selectedTalent = node
                                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                                    TalentHaptics.prepareSelection()
                                }
                        )
                        .onAppear { TalentHaptics.prepareSelection() }
                        .popover(
                            item: Binding(
                                get: {
                                    viewModel.selectedTalent?.id == node.id ? viewModel.selectedTalent : nil
                                },
                                set: { newValue in
                                    if newValue == nil {
                                        TalentHaptics.selectionChanged()
                                        viewModel.selectedTalent = nil
                                    }
                                }
                            ),
                            attachmentAnchor: .rect(.bounds),
                            arrowEdge: .top
                        ) { node in
                            TalentDetailPopover(
                                node: node,
                                currentRank: viewModel.rank(for: node)
                            )
                            .presentationCompactAdaptation(.none)
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("IRL Talent Tree")
        .onAppear { TalentHaptics.prepareSelection() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("IRL Talent Tree")
                    .font(.largeTitle.bold())

                Spacer()

                Button("Respec") {
                    isShowingRespecConfirm = true
                }
                .font(.footnote.bold())
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.secondary.opacity(0.2))
                .clipShape(Capsule())

                Text("Lvl \(viewModel.level)")
                    .font(.footnote)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.thinMaterial)
                    .clipShape(Capsule())
            }

            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Text("Points:")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("\(viewModel.availablePoints)")
                        .font(.subheadline).bold()
                }

                HStack(spacing: 4) {
                    Text("Spent:")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("\(viewModel.pointsSpent)")
                        .font(.subheadline)
                }
            }
        }
        .alert("Reset all talents?", isPresented: $isShowingRespecConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                viewModel.respecAllTalents()
            }
        } message: {
            Text("This will clear all spent points so you can rebuild your tree.")
        }
    }
}

private struct TalentNodeTile: View {
    let node: TalentNode
    let rank: Int
    let isUnlocked: Bool
    let canSpend: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: {
            onTap()
        }) {
            VStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: 2)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(backgroundColor)
                    )
                    .overlay(
                        Image(systemName: node.sfSymbolName)
                            .font(.title3)
                            .opacity(iconOpacity)
                    )
                    .aspectRatio(1, contentMode: .fit)

                Text("\(rank)/\(node.maxRanks)")
                    .font(.caption2)
                    .foregroundStyle(rank > 0 ? .primary : .secondary)
            }
            .padding(4)
        }
        .buttonStyle(.plain)
        .disabled(!canSpend)
    }

    private var borderColor: Color {
        if rank >= node.maxRanks {
            return .primary
        } else if canSpend {
            return .primary.opacity(0.9)
        } else if isUnlocked {
            return .secondary
        } else {
            return .secondary.opacity(0.4)
        }
    }

    private var backgroundColor: Color {
        if rank > 0 {
            return Color.primary.opacity(0.12)
        } else if canSpend {
            return Color.primary.opacity(0.06)
        } else {
            return Color.clear
        }
    }

    private var iconOpacity: Double {
        if rank > 0 || canSpend {
            return 1.0
        } else {
            return 0.35
        }
    }
}

private struct TalentDetailSheet: View {
    let node: TalentNode
    let currentRank: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(node.name)
                .font(.title2.bold())
            Text("Rank \(currentRank)/\(node.maxRanks)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(node.description)
                .font(.body)
            Spacer()
        }
        .padding()
    }
}

private struct TalentDetailPopover: View {
    let node: TalentNode
    let currentRank: Int

    private var rankColor: Color {
        if currentRank <= 0 { return .secondary }
        let fraction = Double(currentRank) / Double(max(node.maxRanks, 1))
        switch fraction {
        case ..<0.34: return .teal
        case ..<0.67: return .blue
        case ..<1.0: return .purple
        default: return .yellow
        }
    }

    var body: some View {
        VStack(alignment: .center, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.accentColor.opacity(0.16))
                    .frame(width: 44, height: 44)
                Image(systemName: node.sfSymbolName)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
            }

            Text(node.name)
                .font(.subheadline.bold())
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.9)

            HStack(spacing: 6) {
                Image(systemName: "star.fill")
                    .font(.caption2)
                Text("Rank \(currentRank)/\(node.maxRanks)")
                    .font(.caption.bold())
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(rankColor.opacity(0.2))
            .foregroundStyle(rankColor)
            .clipShape(Capsule())

            Text(node.description)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(1.5)
        }
        .padding(16)
        .frame(maxWidth: 360)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground).opacity(0.22))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
        .onAppear { TalentHaptics.prepareSelection() }
        .onDisappear { TalentHaptics.prepareSelection() }
    }
}

private enum TalentHaptics {
    static let selection = UISelectionFeedbackGenerator()
    static func prepareSelection() { selection.prepare() }
    static func selectionChanged() { selection.selectionChanged() }
}
