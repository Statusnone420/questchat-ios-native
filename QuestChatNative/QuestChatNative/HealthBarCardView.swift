import SwiftUI

struct HealthBarCardView: View {
    @ObservedObject var viewModel: HealthBarViewModel

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

            ProgressView(value: Double(viewModel.hp), total: 100)
                .tint(.teal)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

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

            PillPicker(options: GutStatus.allCases, selected: selected, highlightColor: .orange, labelProvider: statusLabel) { status in
                onSelect(status)
            }
        }
    }

    private func statusLabel(_ status: GutStatus) -> String {
        switch status {
        case .none: return "—"
        case .great: return "Great"
        case .meh: return "Meh"
        case .rough: return "Rough"
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

            PillPicker(options: MoodStatus.allCases, selected: selected, highlightColor: .teal, labelProvider: statusLabel) { status in
                onSelect(status)
            }
        }
    }

    private func statusLabel(_ status: MoodStatus) -> String {
        switch status {
        case .none: return "—"
        case .good: return "Good"
        case .neutral: return "Neutral"
        case .bad: return "Bad"
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
                    Text(labelProvider(option))
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .frame(maxWidth: .infinity)
                        .background(isSelected ? highlightColor.opacity(0.25) : Color.clear)
                        .overlay(
                            Capsule()
                                .strokeBorder(isSelected ? highlightColor : Color.gray.opacity(0.3), lineWidth: isSelected ? 1.5 : 1)
                        )
                        .foregroundStyle(isSelected ? highlightColor : .primary)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
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
