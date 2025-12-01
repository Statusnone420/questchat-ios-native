import SwiftUI

struct MoreView: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "ellipsis.circle")
                .foregroundStyle(.mint)
                .imageScale(.large)
            Text("More coming soon")
                .font(.title3)
                .foregroundStyle(.secondary)

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
