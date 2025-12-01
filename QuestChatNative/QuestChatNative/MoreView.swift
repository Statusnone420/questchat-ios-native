import SwiftUI

struct MoreView: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(spacing: 16) {
            Text("More coming soon")
                .font(.title3)
                .foregroundStyle(.secondary)

            Button {
                if let url = URL(string: "https://questchat.app") {
                    openURL(url)
                }
            } label: {
                Label("Visit questchat.app", systemImage: "safari")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

#Preview {
    MoreView()
}
