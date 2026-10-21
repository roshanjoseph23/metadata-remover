import SwiftUI

/// Rule-of-thirds lines drawn inside the crop rectangle.
struct CropGuides: View {
    var body: some View {
        Canvas { context, canvasSize in
            var path = Path()
            for third in [1.0 / 3, 2.0 / 3] {
                path.move(to: CGPoint(x: canvasSize.width * third, y: 0))
                path.addLine(to: CGPoint(x: canvasSize.width * third, y: canvasSize.height))
                path.move(to: CGPoint(x: 0, y: canvasSize.height * third))
                path.addLine(to: CGPoint(x: canvasSize.width, y: canvasSize.height * third))
            }
            context.stroke(path, with: .color(.white.opacity(0.4)), lineWidth: 0.5)
        }
        .allowsHitTesting(false)
    }
}
