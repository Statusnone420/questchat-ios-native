import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @State private var pendingReset: ResetWindow?

    var body: some View {
        NavigationStack {
            List {
                Section(
                    footer: Text("Time-window resets remove recent sessions, XP, and health logs only. Full reset clears all local progress and settings; restart the app afterward for a fresh start.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                ) {
                    resetButton(title: "Reset last 5 minutes", window: .last5Minutes)
                    resetButton(title: "Reset last hour", window: .lastHour)
                    resetButton(title: "Reset last day", window: .lastDay)
                    resetButton(title: "Reset last week", window: .lastWeek)
                    resetButton(title: "Full reset", window: .full, role: .destructive)
                }
            }
            .navigationTitle("Settings")
            .alert("Confirm reset", isPresented: Binding(
                get: { pendingReset != nil },
                set: { newValue in
                    if !newValue { pendingReset = nil }
                }
            ), actions: {
                Button("Cancel", role: .cancel) {
                    pendingReset = nil
                }
                Button("Confirm", role: .destructive) {
                    if let window = pendingReset {
                        viewModel.reset(window: window)
                    }
                    pendingReset = nil
                }
            }, message: {
                if let pendingReset {
                    switch pendingReset {
                    case .full:
                        Text("This will erase all locally stored progress and settings. The app may need to be fully restarted afterward.")
                    default:
                        Text("This will remove data recorded in the selected time window, including sessions, XP, and health logs.")
                    }
                }
            })
        }
    }

    private func resetButton(title: String, window: ResetWindow, role: ButtonRole? = nil) -> some View {
        Button(role: role) {
            pendingReset = window
        } label: {
            Text(title)
                .foregroundColor(role == .destructive ? .red : .primary)
        }
    }
}

#Preview {
    SettingsView(viewModel: SettingsViewModel(resetter: GameDataResetter(
        healthStatsStore: HealthBarIRLStatsStore(),
        xpStore: SessionStatsStore(),
        sessionStatsStore: SessionStatsStore()
    )))
}
