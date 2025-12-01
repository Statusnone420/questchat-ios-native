import SwiftUI

struct HealthBarCardView: View {
    @ObservedObject var viewModel: HealthBarViewModel

    private var header: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Health")
                    .font(.headline)
                Text("HP: \(viewModel.hp)/100")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            StatPill(icon: "drop.fill", label: "Hydration", value: "\(viewModel.inputs.hydrationCount)")
        }
    }

    private var statRow: some View {
        HStack(spacing: 12) {
            StatPill(icon: "drop.fill", label: "Hydration", value: "\(viewModel.inputs.hydrationCount)")
            StatPill(icon: "hands.sparkles.fill", label: "Self-care", value: "\(viewModel.inputs.selfCareSessions)")
            StatPill(icon: "bolt.fill", label: "Focus", value: "\(viewModel.inputs.focusSprints)")
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("HealthBar IRL")
                    .font(.headline.weight(.semibold))
                Spacer()
                Text("\(viewModel.hp) / 100 HP")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.gray.opacity(0.25))
                    Capsule()
                        .fill(viewModel.healthBarColor)
                        .frame(width: geometry.size.width * viewModel.hpPercentage)
                        .animation(.easeInOut(duration: 0.25), value: viewModel.hpPercentage)
                }
            }
            .frame(height: 14)

            HStack(spacing: 8) {
                StatPill(icon: "drop.fill", label: "Hydration", value: "\(viewModel.inputs.hydrationCount)x")
                StatPill(icon: "figure.mind.and.body", label: "Self-care", value: "\(viewModel.inputs.selfCareSessions)")
                StatPill(icon: "bolt.fill", label: "Focus", value: "\(viewModel.inputs.focusSprints)")
            }

            HStack(alignment: .top, spacing: 12) {
                GutStatusPicker(selected: viewModel.inputs.gutStatus) { status in
                    viewModel.setGutStatus(status)
                }
                MoodStatusPicker(selected: viewModel.inputs.moodStatus) { status in
                    viewModel.setMoodStatus(status)
                }
            }

            HStack(spacing: 12) {
                Button("Drank water") {
                    viewModel.logHydration()
                }
                .buttonStyle(.borderedProminent)
                .tint(.teal)

                Button("Self-care done") {
                    viewModel.logSelfCareSession()
                }
                .buttonStyle(.borderedProminent)
                .tint(.teal.opacity(0.75))
            }
            .font(.subheadline.weight(.semibold))
        }
        .padding(14)
        .background(Color(uiColor: .secondarySystemBackground).opacity(0.65))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct StatPill: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.subheadline)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.subheadline.weight(.semibold))
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(Color(uiColor: .secondarySystemBackground).opacity(0.35))
        .clipShape(Capsule())
    }
}

struct GutStatusPicker: View {
    let selected: GutStatus
    let onSelect: (GutStatus) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Gut", systemImage: "heart.text.square")
                .font(.caption)
                .foregroundStyle(.orange)

            HStack(spacing: 8) {
                ForEach(GutStatus.allCases, id: \.self) { status in
                    let isSelected = status == selected

                    Button {
                        onSelect(status)
                    } label: {
                        gutChip(for: status, isSelected: isSelected)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func gutChip(for status: GutStatus, isSelected: Bool) -> some View {
        switch status {
        case .none:
            return StatusIconChip(
                systemName: "slash.circle",
                baseColor: .gray,
                isSelected: isSelected,
                accessibilityLabel: "Gut: not logged"
            )
        case .great:
            return StatusIconChip(
                systemName: "checkmark.circle.fill",
                baseColor: .green,
                isSelected: isSelected,
                accessibilityLabel: "Gut: great"
            )
        case .meh:
            return StatusIconChip(
                systemName: "minus.circle.fill",
                baseColor: .yellow,
                isSelected: isSelected,
                accessibilityLabel: "Gut: meh"
            )
        case .rough:
            return StatusIconChip(
                systemName: "xmark.circle.fill",
                baseColor: .red,
                isSelected: isSelected,
                accessibilityLabel: "Gut: rough"
            )
        }
    }
}

struct MoodStatusPicker: View {
    let selected: MoodStatus
    let onSelect: (MoodStatus) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Mood", systemImage: "face.smiling")
                .font(.caption)
                .foregroundStyle(.purple)

            HStack(spacing: 8) {
                ForEach(MoodStatus.allCases, id: \.self) { status in
                    let isSelected = status == selected

                    Button {
                        onSelect(status)
                    } label: {
                        moodChip(for: status, isSelected: isSelected)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func moodChip(for status: MoodStatus, isSelected: Bool) -> some View {
        switch status {
        case .none:
            return StatusIconChip(
                systemName: "slash.circle",
                baseColor: .gray,
                isSelected: isSelected,
                accessibilityLabel: "Mood: not logged"
            )
        case .good:
            return StatusIconChip(
                systemName: "face.smiling",
                baseColor: .green,
                isSelected: isSelected,
                accessibilityLabel: "Mood: good"
            )
        case .neutral:
            return StatusIconChip(
                systemName: "face.neutral",
                baseColor: .yellow,
                isSelected: isSelected,
                accessibilityLabel: "Mood: neutral"
            )
        case .bad:
            return StatusIconChip(
                systemName: "face.frown",
                baseColor: .red,
                isSelected: isSelected,
                accessibilityLabel: "Mood: bad"
            )
        }
    }
}

struct PillPicker<Option: Hashable>: View {
    let options: [Option]
    let selected: Option
    let highlightColor: Color
    let labelProvider: (Option) -> String
    let onSelect: (Option) -> Void

    var body: some View {
        HStack(spacing: 8) {
            ForEach(options, id: \.self) { option in
                let isSelected = option == selected

                Button {
                    onSelect(option)
                } label: {
                    StatusChip(
                        title: labelProvider(option),
                        isSelected: isSelected,
                        highlightColor: highlightColor
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct StatusChip: View {
    let title: String
    let isSelected: Bool
    let highlightColor: Color

    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(isSelected ? highlightColor.opacity(0.25) : Color.clear)
            .overlay(
                Capsule()
                    .strokeBorder(isSelected ? highlightColor : Color.gray.opacity(0.35), lineWidth: isSelected ? 1.5 : 1)
            )
            .foregroundStyle(isSelected ? highlightColor : .primary)
            .clipShape(Capsule())
    }
}

struct StatusIconChip: View {
    let systemName: String
    let baseColor: Color
    let isSelected: Bool
    let accessibilityLabel: String

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 16, weight: .semibold))
            .frame(width: 40, height: 32)
            .foregroundColor(isSelected ? .black : baseColor)
            .background(
                Capsule()
                    .fill(isSelected ? baseColor : Color(.secondarySystemBackground))
            )
            .overlay(
                Capsule()
                    .stroke(baseColor.opacity(isSelected ? 1.0 : 0.4), lineWidth: 1)
            )
            .scaleEffect(isSelected ? 1.05 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isSelected)
            .accessibilityLabel(Text(accessibilityLabel))
    }
}

struct HealthBarCardView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleInputs = DailyHealthInputs(
            hydrationCount: 3,
            selfCareSessions: 1,
            focusSprints: 2,
            gutStatus: .great,
            moodStatus: .good
        )

        let viewModel = HealthBarViewModel(storage: PreviewHealthBarStorage(inputs: sampleInputs))

        return HealthBarCardView(viewModel: viewModel)
            .padding()
            .background(Color.black)
            .previewLayout(.sizeThatFits)
    }

    private struct PreviewHealthBarStorage: HealthBarStorageProtocol {
        var inputs: DailyHealthInputs

        func loadTodayInputs() -> DailyHealthInputs { inputs }
        func saveTodayInputs(_ inputs: DailyHealthInputs) { }
    }
}
