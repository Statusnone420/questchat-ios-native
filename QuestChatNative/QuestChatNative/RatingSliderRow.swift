import SwiftUI
import UIKit

struct RatingSliderRow: View {
    let title: String
    let systemImage: String
    let tint: Color
    let value: Binding<Int?>
    let labels: [String]
    let allowsClearing: Bool
    let valueDescription: (Int) -> String
    @State private var lastHapticStep: Int?

    private var sliderBinding: Binding<Double> {
        Binding<Double>(
            get: { Double(value.wrappedValue ?? 3) },
            set: { newValue in value.wrappedValue = Int(newValue) }
        )
    }

    private var currentLabel: String {
        guard let rating = value.wrappedValue else { return "Not set" }
        return valueDescription(rating)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Label(title, systemImage: systemImage)
                    .font(.caption)
                    .foregroundStyle(tint)
                    .frame(width: 90, alignment: .leading)

                Text(currentLabel)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if allowsClearing, value.wrappedValue != nil {
                    Button("Reset") {
                        value.wrappedValue = nil
                    }
                    .font(.caption)
                }
            }

            Slider(value: sliderBinding, in: 1...5, step: 1)
                .onChange(of: value.wrappedValue) { newValue in
                    guard let step = newValue else {
                        lastHapticStep = nil
                        return
                    }

                    if step != lastHapticStep {
                        UISelectionFeedbackGenerator().selectionChanged()
                        lastHapticStep = step
                    }
                }

            HStack(spacing: 8) {
                ForEach(Array(labels.enumerated()), id: \.offset) { index, label in
                    Text(label)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: alignment(for: index))
                }
            }
        }
    }

    private func alignment(for index: Int) -> Alignment {
        if index == 0 { return .leading }
        if index == labels.count - 1 { return .trailing }
        return .center
    }
}
