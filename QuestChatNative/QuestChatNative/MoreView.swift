import SwiftUI

struct MoreView: View {
    @ObservedObject var viewModel: MoreViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    hydrationSection

                    LegacyMoreContentView()
                }
                .padding()
                .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("More")
        }
    }

    private var hydrationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Hydration")
                .font(.headline)
                .foregroundStyle(.secondary)

            VStack(spacing: 12) {
                Stepper(value: $viewModel.ouncesPerWaterTap, in: 1...64) {
                    HStack {
                        Text("Water per tap")
                        Spacer()
                        Text("\(viewModel.ouncesPerWaterTap) oz")
                            .foregroundStyle(.secondary)
                    }
                }

                Stepper(value: $viewModel.ouncesPerComfortTap, in: 1...64) {
                    HStack {
                        Text("Comfort beverage per tap")
                        Spacer()
                        Text("\(viewModel.ouncesPerComfortTap) oz")
                            .foregroundStyle(.secondary)
                    }
                }

                Stepper(value: $viewModel.dailyWaterGoalOunces, in: 8...256) {
                    HStack {
                        Text("Daily water goal")
                        Spacer()
                        Text("\(viewModel.dailyWaterGoalOunces) oz")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct LegacyMoreContentView: View {
    @Environment(\.openURL) private var openURL
    @AppStorage("hydrateNudgesEnabled") private var hydrateNudgesEnabled: Bool = true

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "ellipsis.circle")
                .foregroundStyle(.mint)
                .imageScale(.large)
            Text(QuestChatStrings.MoreView.moreComing)
                .font(.title3)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(QuestChatStrings.MoreView.timerDurationsTitle)
                        .foregroundStyle(.secondary)
                    Text(QuestChatStrings.MoreView.timerDurationsDescription)
                        .font(.headline)
                }

                Toggle(isOn: $hydrateNudgesEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(QuestChatStrings.MoreView.hydrationToggleTitle)
                            .font(.headline)
                        Text(QuestChatStrings.MoreView.hydrationToggleDescription)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .tint(.mint)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(uiColor: .secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 0) {
                NavigationLink {
                    AboutHealthBarView()
                } label: {
                    HStack {
                        Label("About HealthBar IRL", systemImage: "info.circle")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 8)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(uiColor: .secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Button {
                if let url = URL(string: "https://questchat.app") {
                    openURL(url)
                }
            } label: {
                Label(QuestChatStrings.MoreView.visitSite, systemImage: "safari")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.mint)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    MoreView(viewModel: MoreViewModel(hydrationSettingsStore: HydrationSettingsStore()))
}
