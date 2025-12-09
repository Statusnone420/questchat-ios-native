import SwiftUI
import Lottie

struct LottieView: UIViewRepresentable {
    let animationName: String
    let loopMode: LottieLoopMode
    let animationSpeed: CGFloat
    let contentMode: UIView.ContentMode
    let animationTrigger: UUID
    
    init(
        animationName: String,
        loopMode: LottieLoopMode = .playOnce,
        animationSpeed: CGFloat = 1.0,
        contentMode: UIView.ContentMode = .scaleAspectFit,
        animationTrigger: UUID = UUID()
    ) {
        self.animationName = animationName
        self.loopMode = loopMode
        self.animationSpeed = animationSpeed
        self.contentMode = contentMode
        self.animationTrigger = animationTrigger
    }
    
    func makeUIView(context: Context) -> UIView {
        let containerView = UIView()
        containerView.backgroundColor = .clear
        
        let animationView = LottieAnimationView(name: animationName)
        animationView.loopMode = loopMode
        animationView.animationSpeed = animationSpeed
        animationView.contentMode = contentMode
        animationView.backgroundBehavior = .pauseAndRestore
        animationView.translatesAutoresizingMaskIntoConstraints = false
        
        // Store reference to animation view for updates
        containerView.tag = animationTrigger.hashValue
        
        containerView.addSubview(animationView)
        
        NSLayoutConstraint.activate([
            animationView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            animationView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            animationView.topAnchor.constraint(equalTo: containerView.topAnchor),
            animationView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
        
        // Play and stop on last frame
        animationView.play { finished in
            if finished {
                // Keep showing the last frame (chest open)
                animationView.currentProgress = 1.0
            }
        }
        
        return containerView
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // Check if trigger changed (replay requested)
        if uiView.tag != animationTrigger.hashValue {
            uiView.tag = animationTrigger.hashValue
            
            // Find and replay the animation
            if let animationView = uiView.subviews.first as? LottieAnimationView {
                animationView.play { finished in
                    if finished {
                        animationView.currentProgress = 1.0
                    }
                }
            }
        }
    }
}
