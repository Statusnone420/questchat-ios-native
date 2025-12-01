import SwiftUI

struct PlayerCardView: View {
    @ObservedObject var store: SessionStatsStore

    @AppStorage("playerDisplayName") private var playerDisplayName: String = "Player One"

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 4) {
                TextField("Player name", text: $playerDisplayName)
                    .font(.title.bold())
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .textFieldStyle(.plain)
                Text(store.playerTitle)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.qcCardBackground)
            .cornerRadius(14)

            VStack(alignment: .leading, spacing: 12) {
                statRow(label: "Level", value: "\(store.level)", tint: .qcAccentPurpleBright)
                statRow(label: "Total XP", value: "\(store.xp)", tint: .qcAccentPurple)
                statRow(label: "Current streak", value: "\(store.currentStreakDays) days", tint: .qcAccentPurple)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.qcCardBackground)
            .cornerRadius(16)

            HStack {
                Text(store.statusLine)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
                Spacer()
            }

            Spacer()
        }
        .padding()
        .background(Color.qcPrimaryBackground.ignoresSafeArea())
    }

    private func statRow(label: String, value: String, tint: Color) -> some View {
        HStack {
            Label(label, systemImage: "sparkles")
                .font(.headline)
                .foregroundStyle(tint)
            Spacer()
            Text(value)
                .font(.title3.bold())
                .foregroundStyle(.white)
        }
    }
}

#Preview {
    let store = SessionStatsStore()
    PlayerCardView(store: store)
}
