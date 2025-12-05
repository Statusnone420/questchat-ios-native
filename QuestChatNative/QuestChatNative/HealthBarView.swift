import SwiftUI

struct HealthBarView: View {
    @StateObject var viewModel: HealthBarViewModel

    init(viewModel: HealthBarViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 20) {
                    healthHeaderCard
                    vitalsCard
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .scrollBounceBehavior(.basedOnSize)
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Health")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.black, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    private var healthHeaderCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("HealthBar IRL")
                    .font(.headline.weight(.semibold))
                Spacer()
                Text("Level \(viewModel.level)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            RPGStatBar(
                iconName: "heart.fill",
                label: "HP",
                color: .red,
                progress: viewModel.hpProgress,
                segments: viewModel.hpSegments
            )

            HStack {
                Spacer()
                Text("\(viewModel.currentHP) / \(viewModel.maxHP) HP")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 6) {
                ProgressView(value: viewModel.xpProgress, total: 1)
                    .tint(.mint)

                HStack {
                    Text("XP")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(viewModel.xpInCurrentLevel) / \(max(viewModel.xpToNextLevel, 1))")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 10) {
                statusBadge(title: "Gut", value: viewModel.gutStatusText, systemImage: "heart.text.square", tint: .orange)
                statusBadge(title: "Mood", value: viewModel.moodStatusText, systemImage: "face.smiling", tint: .green)
                statusBadge(title: "Sleep", value: viewModel.sleepStatusText, systemImage: "moon.fill", tint: .purple)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemBackground).opacity(0.65))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var vitalsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .lastTextBaseline) {
                Text("Vitals")
                    .font(.headline.weight(.semibold))
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(viewModel.hydrationSummaryText)
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    if let cups = viewModel.hydrationCupsText {
                        Text(cups)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            StatusBarRow(
                iconName: "drop.fill",
                label: "Hydration",
                tint: .blue,
                progress: viewModel.hydrationProgress,
                segments: 10,
                detailText: viewModel.hydrationSummaryText
            )

            StatusBarRow(
                iconName: "moon.fill",
                label: "Sleep",
                tint: .purple,
                progress: viewModel.sleepProgress,
                segments: 8,
                detailText: viewModel.sleepStatusText
            )

            StatusBarRow(
                iconName: "face.smiling",
                label: "Mood",
                tint: .green,
                progress: viewModel.moodProgress,
                segments: 8,
                detailText: viewModel.moodStatusText
            )

            StatusBarRow(
                iconName: "bolt.fill",
                label: "Stamina",
                tint: .orange,
                progress: viewModel.staminaProgress,
                segments: 8,
                detailText: viewModel.staminaLabel
            )
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemBackground).opacity(0.45))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func statusBadge(title: String, value: String, systemImage: String, tint: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.caption.bold())
                .foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.subheadline.weight(.semibold))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemBackground).opacity(0.35))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

#Preview {
    HealthBarView(viewModel: DependencyContainer.shared.healthBarViewModel)
}
