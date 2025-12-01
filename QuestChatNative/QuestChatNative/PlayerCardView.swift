import SwiftUI

struct PlayerCardView: View {
    @ObservedObject var store: SessionStatsStore

    @AppStorage("playerDisplayName") private var playerDisplayName: String = "Player One"

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 4) {
                TextField("Player name", text: $playerDisplayName)
                    .font(.title.bold())
                    .multilineTextAlignment(.center)
                    .textFieldStyle(.plain)
                Text(store.playerTitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(uiColor: .secondarySystemBackground).opacity(0.18))
            .cornerRadius(14)

            VStack(alignment: .leading, spacing: 12) {
                statRow(label: "Level", value: "\(store.level)", tint: .mint)
                statRow(label: "Total XP", value: "\(store.xp)", tint: .cyan)
                statRow(label: "Current streak", value: "\(store.currentStreakDays) days", tint: .orange)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(uiColor: .secondarySystemBackground).opacity(0.16))
            .cornerRadius(16)

            HStack {
                Text(store.statusLine)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            Spacer()
        }
        .padding()
        .background(Color.black.ignoresSafeArea())
    }

    private func statRow(label: String, value: String, tint: Color) -> some View {
        HStack {
            Label(label, systemImage: "sparkles")
                .font(.headline)
                .foregroundStyle(tint)
            Spacer()
            Text(value)
                .font(.title3.bold())
        }
    }
}

#Preview {
    let store = SessionStatsStore()
    PlayerCardView(store: store)
}
