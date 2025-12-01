import SwiftUI

struct MoreView: View {
    @Environment(\.openURL) private var openURL
    @AppStorage("focusDurationMinutes") private var focusDurationMinutes: Int = 25
    @AppStorage("selfCareDurationMinutes") private var selfCareDurationMinutes: Int = 5

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "ellipsis.circle")
                .foregroundStyle(.mint)
                .imageScale(.large)
            Text("More coming soon")
                .font(.title3)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 12) {
                Text("Focus duration")
                    .foregroundStyle(.secondary)
                Stepper(value: $focusDurationMinutes, in: 5...60) {
                    Text("\(focusDurationMinutes) minutes")
                        .font(.headline)
                }
                .tint(.mint)

                Text("Self care duration")
                    .foregroundStyle(.secondary)
                Stepper(value: $selfCareDurationMinutes, in: 3...20) {
                    Text("\(selfCareDurationMinutes) minutes")
                        .font(.headline)
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
