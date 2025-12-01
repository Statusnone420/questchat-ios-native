import SwiftUI

struct HealthBarCardView: View {
    @ObservedObject var viewModel: HealthBarViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("HealthBar IRL")
                    .font(.headline)
                Spacer()
                Text("\(viewModel.hp) / 100 HP")
                    .font(.subheadline)
            }

            ProgressView(value: Double(viewModel.hp), total: 100)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            HStack(spacing: 12) {
                StatPill(icon: "drop.fill", label: "Hydration", value: "\(viewModel.inputs.hydrationCount)x")
                StatPill(icon: "figure.mind.and.body", label: "Self-care", value: "\(viewModel.inputs.selfCareSessions)")
                StatPill(icon: "bolt.fill", label: "Focus", value: "\(viewModel.inputs.focusSprints)")
            }

            HStack(spacing: 12) {
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

                Button("Self-care done") {
                    viewModel.logSelfCareSession()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
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
                    .font(.subheadline.bold())
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(Color(uiColor: .secondarySystemBackground).opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct GutStatusPicker: View {
    let selected: GutStatus
    let onSelect: (GutStatus) -> Void

    var body: some View {
        picker(title: "Gut", cases: GutStatus.allCases, selected: selected, color: .orange)
    }

    private func picker(title: String, cases: [GutStatus], selected: GutStatus, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: "heart.text.square")
                .font(.caption)
                .foregroundStyle(color)

            HStack(spacing: 8) {
                ForEach(cases, id: \._self) { status in
                    Button(action: { onSelect(status) }) {
                        Text(statusLabel(status))
                            .font(.caption.bold())
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(selected == status ? color : .gray.opacity(0.4))
                }
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

            HStack(spacing: 8) {
                ForEach(MoodStatus.allCases, id: \._self) { status in
                    Button(action: { onSelect(status) }) {
                        Text(statusLabel(status))
                            .font(.caption.bold())
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(selected == status ? .purple : .gray.opacity(0.4))
                }
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
