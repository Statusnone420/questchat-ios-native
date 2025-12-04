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
        emitter.renderMode = .backToFront

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

        var cells: [CAEmitterCell] = []

        for color in colors {
            // Round confetti (small dots)
            if let circleImage = makeCircleImage(color: color)?.cgImage {
                let cell = baseCell()
                cell.contents = circleImage
                cell.birthRate = 10
                cell.scale = 0.6
                cell.scaleRange = 0.3
                cell.spin = 3
                cell.spinRange = 1.5
                cells.append(cell)
            }

            // Long strips (classic confetti look)
            if let stripImage = makeStripImage(color: color)?.cgImage {
                let cell = baseCell()
                cell.contents = stripImage
                cell.birthRate = 6
                cell.scale = 1.0
                cell.scaleRange = 0.4
                cell.spin = 6
                cell.spinRange = 3
                cell.xAcceleration = CGFloat.random(in: -40...40)
                cells.append(cell)
            }
        }

        return cells
    }

    private func baseCell() -> CAEmitterCell {
        let cell = CAEmitterCell()
        cell.lifetime = 4.0

        cell.velocity = 240
        cell.velocityRange = 100
        cell.yAcceleration = 130

        cell.emissionLongitude = .pi
        cell.emissionRange = .pi / 3

        cell.alphaSpeed = -0.3   // fade out as they fall
        return cell
    }

    private func makeCircleImage(color: UIColor) -> UIImage? {
        let size: CGFloat = 10
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))

        return renderer.image { context in
            let rect = CGRect(x: 0, y: 0, width: size, height: size)
            color.setFill()
            context.cgContext.fillEllipse(in: rect)
        }
    }

    private func makeStripImage(color: UIColor) -> UIImage? {
        // Tall skinny rectangle
        let width: CGFloat = 6
        let height: CGFloat = 14
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height))

        return renderer.image { context in
            let rect = CGRect(x: 0, y: 0, width: width, height: height)
            color.setFill()
            context.cgContext.fill(rect)
            context.cgContext.setBlendMode(.normal)
        }
    }
}

//
//  ConfettiView.swift
//  QuestChatNative
//
//  Created by Anthony Gagliardo on 12/4/25.
//

