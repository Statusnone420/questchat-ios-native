import SwiftUI

struct MoreView: View {
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
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea())
    }
}

#Preview {
    MoreView()
}
