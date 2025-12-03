import SwiftUI

struct WellbeingSliderRow: View {
    let label: String
    @Binding var rating: WellbeingRating

    private var sliderBinding: Binding<Double> {
        Binding<Double>(
            get: { Double(rating.rawValue) },
            set: { newValue in
                let clamped = min(max(Int(newValue.rounded()), 0), WellbeingRating.allCases.count - 1)
                rating = WellbeingRating(rawValue: clamped) ?? .notSet
            }
        )
    }

    private var tint: Color { rating.color }

    var body: some View {
        HStack(spacing: 12) {
            Label(label, systemImage: symbol(for: label))
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .leading)

            Slider(value: sliderBinding, in: 0...Double(WellbeingRating.allCases.count - 1), step: 1)
                .tint(tint)

            Text(rating.emoji)
                .font(.title3)
                .frame(width: 32, alignment: .trailing)
        }
        .padding(.vertical, 6)
    }

    private func symbol(for label: String) -> String {
        switch label.lowercased() {
        case "gut": return "heart.text.square"
        case "mood": return "face.smiling"
        case "sleep": return "bed.double.fill"
        default: return "star"
        }
    }
}
