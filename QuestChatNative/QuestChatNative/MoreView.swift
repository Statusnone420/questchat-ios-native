import SwiftUI

struct MoreView: View {
    @Environment(\.openURL) private var openURL
    @AppStorage("hydrateNudgesEnabled") private var hydrateNudgesEnabled: Bool = true

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "ellipsis.circle")
                .foregroundStyle(.mint)
                .imageScale(.large)
            Text("More coming soon")
                .font(.title3)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Timer durations")
                        .foregroundStyle(.secondary)
                    Text("Adjust each category directly from the Focus tab.")
                        .font(.headline)
                }

                Toggle(isOn: $hydrateNudgesEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Hydrate + posture nudges")
                            .font(.headline)
                        Text("In-app banners and local notifications when you cross focus milestones.")
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
                Label("Visit questchat.app", systemImage: "safari")
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
