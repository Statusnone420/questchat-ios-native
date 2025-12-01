import SwiftUI
import UIKit

struct DurationWheelPickerView: UIViewRepresentable {
    @Binding var totalSeconds: Int
    var maxMinutes: Int = 59

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> UIPickerView {
        let picker = UIPickerView()
        picker.dataSource = context.coordinator
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIView(_ uiView: UIPickerView, context: Context) {
        let minutes = max(0, min(maxMinutes, totalSeconds / 60))
        let seconds = max(0, min(59, totalSeconds % 60))
        uiView.selectRow(minutes, inComponent: 0, animated: false)
        uiView.selectRow(seconds, inComponent: 1, animated: false)
    }

    final class Coordinator: NSObject, UIPickerViewDataSource, UIPickerViewDelegate {
        let parent: DurationWheelPickerView
        private let feedback = UISelectionFeedbackGenerator()

        init(_ parent: DurationWheelPickerView) {
            self.parent = parent
            super.init()
            feedback.prepare()
        }

        func numberOfComponents(in pickerView: UIPickerView) -> Int { 2 }

        func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
            switch component {
            case 0: return parent.maxMinutes + 1
            default: return 60
            }
        }

        func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
            String(row)
        }

        func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
            let minutes = pickerView.selectedRow(inComponent: 0)
            let seconds = pickerView.selectedRow(inComponent: 1)
            parent.totalSeconds = minutes * 60 + seconds

            feedback.selectionChanged()
        }
    }
}
