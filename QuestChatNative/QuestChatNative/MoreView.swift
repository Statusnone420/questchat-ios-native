import SwiftUI

struct MoreView: View {
    @ObservedObject var viewModel: MoreViewModel

    var body: some View {
        NavigationStack {
            Form {
                Section("Hydration") {
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
            .navigationTitle("More")
        }
    }
}

#Preview {
    MoreView(viewModel: MoreViewModel(hydrationSettingsStore: HydrationSettingsStore()))
}
