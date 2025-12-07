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
        ZStack {
            talentTreeBackground
            talentsContent
        }
        .background(Color.black.ignoresSafeArea())
    }

    private var talentsContent: some View {
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

    private var talentTreeBackground: some View {
        ZStack {
            backgroundAura
                .ignoresSafeArea()

            GeometryReader { proxy in
                let width = proxy.size.width

                VStack {
                    Spacer()  // push tree toward bottom

                    ZStack {
                        Image("TalentTreeStage1")
                            .resizable()
                            .scaledToFit()
                            .frame(width: width * 2.5)
                            .offset(y: proxy.size.height * 0.12 + 16) // nudged down to match others
                            .opacity(viewModel.treeStage == 1 ? 1 : 0)

                        Image("TalentTreeStage2")
                            .resizable()
                            .scaledToFit()
                            .frame(width: width * 2.5)
                            .offset(y: proxy.size.height * 0.12)
                            .opacity(viewModel.treeStage == 2 ? 1 : 0)

                        Image("TalentTreeStage3")
                            .resizable()
                            .scaledToFit()
                            .frame(width: width * 2.5)
                            .offset(y: proxy.size.height * 0.12)
                            .opacity(viewModel.treeStage == 3 ? 1 : 0)

                        Image("TalentTreeStage4")
                            .resizable()
                            .scaledToFit()
                            .frame(width: width * 2.5)
                            .offset(y: proxy.size.height * 0.12)
                            .opacity(viewModel.treeStage == 4 ? 1 : 0)
                        
                        Image("TalentTreeStage5")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: width * 2.5)
                                    .offset(y: proxy.size.height * 0.12)
                                    .opacity(viewModel.treeStage == 5 ? 1 : 0)

                                Image("TalentTreeStage6")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: width * 2.5)
                                    .offset(y: proxy.size.height * 0.12)
                                    .opacity(viewModel.treeStage == 6 ? 1 : 0)

                                Image("TalentTreeStage7")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: width * 2.5)
                                    .offset(y: proxy.size.height * 0.12)
                                    .opacity(viewModel.treeStage == 7 ? 1 : 0)

                                Image("TalentTreeStage8")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: width * 2.5)
                                    .offset(y: proxy.size.height * 0.12)
                                    .opacity(viewModel.treeStage == 8 ? 1 : 0)

                                Image("TalentTreeStage9")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: width * 2.5)
                                    .offset(y: proxy.size.height * 0.12)
                                    .opacity(viewModel.treeStage == 9 ? 1 : 0)

                                Image("TalentTreeStage10")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: width * 2.5)
                                    .offset(y: proxy.size.height * 0.12)
                                    .opacity(viewModel.treeStage == 10 ? 1 : 0)
                    }
                    .opacity(0.5)
                    .blendMode(.screen)
                    .allowsHitTesting(false)
                    .animation(.easeInOut(duration: 0.45), value: viewModel.treeStage)
                }
                .frame(width: proxy.size.width,
                       height: proxy.size.height,
                       alignment: .bottom)
            }
            .ignoresSafeArea(edges: .bottom)
        }
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

    @ViewBuilder
    private var backgroundAura: some View {
        switch viewModel.masteryTier {
        case 0:
            Color.black

        case 1:
            LinearGradient(
                colors: [
                    Color.teal.opacity(0.12),
                    Color.purple.opacity(0.16)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .overlay(Color.black.opacity(0.6))

        default:
            LinearGradient(
                colors: [
                    Color.teal.opacity(0.18),
                    Color.purple.opacity(0.22)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .overlay(Color.black.opacity(0.55))
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
    @State private var ringProgress: CGFloat = 0

    var body: some View {
        let baseTile = VStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(borderColor, lineWidth: 2)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(backgroundColor)
                )
                .overlay(
                    iconOverlay
                )
                .overlay(masteredRingOverlay)
                .aspectRatio(1, contentMode: .fit)

            Text("\(currentRank)/\(node.maxRanks)")
                .font(.caption2)
                .foregroundStyle(rankForeground)
        }
        .padding(4)
        .frame(maxWidth: .infinity, minHeight: 88)

        baseTile
            .scaleEffect(pulse ? 1.08 : 1.0)
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
            .onAppear { if isMastered { ringProgress = 1 } }
            .onChange(of: isMastered) { newValue in
                ringProgress = newValue ? 1 : 0
            }
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: pulse)
    }

    private var haloOverlay: some View {
        GeometryReader { _ in
            let rect = RoundedRectangle(cornerRadius: 24, style: .continuous)
            rect
                .stroke(Color.purple.opacity(0.6), lineWidth: 4)
                .scaleEffect(pulse ? 1.18 : 0.9)
                .opacity(pulse ? 1.0 : 0.0)   // only visible during pulse
        }
        .allowsHitTesting(false)
    }

    private func pulseOnce() {
        ringProgress = 0
        pulse = true
        withAnimation(.easeOut(duration: 0.35)) {
            ringProgress = 1
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            pulse = false
            if masteryPulseID == node.id {
                masteryPulseID = nil
            }
        }
    }

    private var borderColor: Color {
        switch visualState {
        case .mastered:
            return Color.clear
        case .invested:
            return Color.primary.opacity(0.9)
        case .available:
            return Color.primary.opacity(0.6)
        case .locked:
            return Color.secondary.opacity(0.4)
        }
    }

    private var backgroundColor: Color {
        switch visualState {
        case .mastered:
            return Color.primary.opacity(0.18)
        case .invested:
            return Color.primary.opacity(0.12)
        case .available:
            return Color.primary.opacity(0.06)
        case .locked:
            return Color.clear
        }
    }

    private var iconOpacity: Double {
        visualState == .locked ? 0.35 : 1.0
    }

    private var rankForeground: Color {
        switch visualState {
        case .mastered:
            return .primary
        case .invested:
            return .primary
        case .available:
            return .secondary
        case .locked:
            return .secondary
        }
    }

    private var iconOverlay: some View {
        ZStack {
            if isMastered {
                Circle()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 34, height: 34)
            }

            Image(systemName: node.sfSymbolName)
                .font(iconFont)
                .opacity(iconOpacity)
        }
    }

    private var iconFont: Font {
        isMastered ? .system(size: 22, weight: .semibold) : .title3
    }

    private var masteredRingOverlay: some View {
        Group {
            if isMastered {
                let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
                shape
                    .trim(from: 0, to: ringProgress)
                    .stroke(masteredGradient, lineWidth: 3)
                    .rotationEffect(.degrees(-90))
            }
        }
        .allowsHitTesting(false)
    }

    private var masteredGradient: AngularGradient {
        AngularGradient(colors: [.teal, .purple, .teal], center: .center)
    }

    private var visualState: TileVisualState {
        if isMastered { return .mastered }
        if currentRank > 0 { return .invested }
        if canSpend { return .available }
        return .locked
    }
}

private enum TileVisualState {
    case locked
    case available
    case invested
    case mastered
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
