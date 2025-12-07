import SwiftUI
import UIKit

struct TalentsView: View {
    @StateObject var viewModel: TalentsViewModel
    @State private var isShowingRespecConfirm = false
    @State private var tileFrames: [String: CGRect] = [:]

    private let columns: [GridItem] = Array(
        repeating: GridItem(.flexible(), spacing: 12, alignment: .top),
        count: 4
    )

    private func popoverArrowEdge(for node: TalentNode) -> Edge {
        guard let rect = tileFrames[node.id] else { return .top }
        let screenHeight = UIScreen.main.bounds.height
        let bottomSpace = screenHeight - rect.maxY
        return bottomSpace < 240 ? .bottom : .top
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header

                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(viewModel.nodes) { node in
                        TalentTileView(
                            node: node,
                            currentRank: viewModel.rank(for: node),
                            isUnlocked: viewModel.isUnlocked(node),
                            isMastered: viewModel.rank(for: node) == node.maxRanks,
                            canSpend: viewModel.canSpend(on: node),
                            masteryPulseID: $viewModel.masteryPulseID,
                            onTap: {
                                guard viewModel.canSpend(on: node) else { return }
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                                    viewModel.incrementRank(for: node)
                                }
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            },
                            onLongPress: {
                                viewModel.selectedTalent = node
                                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                                TalentHaptics.prepareSelection()
                            }
                        )
                        .onAppear { TalentHaptics.prepareSelection() }
                        .background(
                            GeometryReader { proxy in
                                Color.clear
                                    .preference(key: TalentTileFramePreferenceKey.self, value: [node.id: proxy.frame(in: .global)])
                            }
                        )
                        .onPreferenceChange(TalentTileFramePreferenceKey.self) { frames in
                            for (id, rect) in frames { tileFrames[id] = rect }
                        }
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
                            arrowEdge: popoverArrowEdge(for: node)
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

private struct TalentTileView: View {
    let node: TalentNode
    let currentRank: Int
    let isUnlocked: Bool
    let isMastered: Bool
    let canSpend: Bool
    @Binding var masteryPulseID: String?
    let onTap: () -> Void
    let onLongPress: () -> Void

    @State private var pulse = false

    var body: some View {
        let baseTile = VStack(spacing: 6) {
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

            Text("\(currentRank)/\(node.maxRanks)")
                .font(.caption2)
                .foregroundStyle(currentRank > 0 ? .primary : .secondary)
        }
        .padding(4)
        .frame(maxWidth: .infinity, minHeight: 88)

        baseTile
            .scaleEffect(pulse ? 1.05 : 1.0)
            .overlay(haloOverlay)
            .contentShape(Rectangle())
            .onTapGesture {
                guard canSpend else { return }
                onTap()
            }
            .onLongPressGesture(minimumDuration: 0.35) {
                onLongPress()
            }
            .onChange(of: masteryPulseID) { newValue in
                guard newValue == node.id else { return }
                pulseOnce()
            }
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: pulse)
    }

    private var haloOverlay: some View {
        GeometryReader { _ in
            let rect = RoundedRectangle(cornerRadius: 24, style: .continuous)
            rect
                .stroke(Color.teal.opacity(pulse ? 0.0 : 0.6), lineWidth: 4)
                .scaleEffect(pulse ? 1.25 : 1.0)
                .opacity(pulse ? 0.0 : 1.0)
        }
        .allowsHitTesting(false)
    }

    private func pulseOnce() {
        pulse = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            pulse = false
            if masteryPulseID == node.id {
                masteryPulseID = nil
            }
        }
    }

    private var borderColor: Color {
        if isMastered {
            return .teal
        } else if canSpend {
            return .primary.opacity(0.9)
        } else if isUnlocked {
            return .secondary
        } else {
            return .secondary.opacity(0.4)
        }
    }

    private var backgroundColor: Color {
        if currentRank > 0 {
            return Color.primary.opacity(0.12)
        } else if canSpend {
            return Color.primary.opacity(0.06)
        } else {
            return Color.clear
        }
    }

    private var iconOpacity: Double {
        if currentRank > 0 || canSpend {
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

private struct TalentTileFramePreferenceKey: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

private enum TalentHaptics {
    static let selection = UISelectionFeedbackGenerator()
    static func prepareSelection() { selection.prepare() }
    static func selectionChanged() { selection.selectionChanged() }
}
