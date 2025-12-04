import SwiftUI
import UIKit

struct ConfettiView: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear

        let emitter = CAEmitterLayer()
        emitter.emitterPosition = CGPoint(x: UIScreen.main.bounds.width / 2, y: -10)
        emitter.emitterShape = .line
        emitter.emitterSize = CGSize(width: UIScreen.main.bounds.width, height: 2)
        emitter.renderMode = .unordered   // keep it simple

        emitter.emitterCells = makeEmitterCells()
        view.layer.addSublayer(emitter)

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) { }

    // MARK: - Private

    private func makeEmitterCells() -> [CAEmitterCell] {
        let colors: [UIColor] = [
            UIColor(red: 1.00, green: 0.38, blue: 0.50, alpha: 1.0), // pink
            UIColor(red: 1.00, green: 0.80, blue: 0.25, alpha: 1.0), // yellow
            UIColor(red: 0.30, green: 0.85, blue: 1.00, alpha: 1.0), // cyan
            UIColor(red: 0.60, green: 0.75, blue: 1.00, alpha: 1.0), // blue
            UIColor(red: 0.60, green: 1.00, blue: 0.60, alpha: 1.0)  // green
        ]

        return colors.map { color in
            let cell = CAEmitterCell()
            cell.birthRate = 12
            cell.lifetime = 4.0

            cell.velocity = 220
            cell.velocityRange = 80
            cell.yAcceleration = 120

            cell.emissionLongitude = .pi
            cell.emissionRange = .pi / 4

            cell.spin = 3.5
            cell.spinRange = 1.5

            cell.scale = 0.9
            cell.scaleRange = 0.4

            // draw a colored circle image for THIS cell
            cell.contents = makeCircleImage(color: color)?.cgImage

            return cell
        }
    }

    private func makeCircleImage(color: UIColor) -> UIImage? {
        let size: CGFloat = 14
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))

        return renderer.image { context in
            let rect = CGRect(x: 0, y: 0, width: size, height: size)
            color.setFill()
            context.cgContext.fillEllipse(in: rect)
        }
    }
}

//
//  ConfettiView.swift
//  QuestChatNative
//
//  Created by Anthony Gagliardo on 12/4/25.
//

