import SwiftUI

struct MoreView: View {
    @Environment(\.openURL) private var openURL
    @AppStorage("focusDurationMinutes") private var focusDurationMinutes: Int = 25
    @AppStorage("selfCareDurationMinutes") private var selfCareDurationMinutes: Int = 5
    @AppStorage("hydrateNudgesEnabled") private var hydrateNudgesEnabled: Bool = true

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "ellipsis.circle")
                .foregroundStyle(.qcAccentPurpleBright)
                .imageScale(.large)
            Text("More coming soon")
                .font(.title3)
                .foregroundStyle(.white.opacity(0.7))

            VStack(alignment: .leading, spacing: 12) {
                Text("Focus duration")
                    .foregroundStyle(.white.opacity(0.7))
                Stepper(value: $focusDurationMinutes, in: 5...60) {
                    Text("\(focusDurationMinutes) minutes")
                        .font(.headline)
                        .foregroundStyle(.white)
                }
                .tint(.qcAccentPurple)

                Text("Self care duration")
                    .foregroundStyle(.white.opacity(0.7))
                Stepper(value: $selfCareDurationMinutes, in: 3...20) {
                    Text("\(selfCareDurationMinutes) minutes")
                        .font(.headline)
                        .foregroundStyle(.white)
                }
                .tint(.qcAccentPurple)

                Toggle(isOn: $hydrateNudgesEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Hydrate + posture nudges")
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text("In-app banners and local notifications when you cross focus milestones.")
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
                .tint(.qcAccentPurpleBright)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color.qcCardBackground)
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
            .tint(.qcAccentPurple)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.qcPrimaryBackground.ignoresSafeArea())
    }
}

#Preview {
    MoreView()
}
