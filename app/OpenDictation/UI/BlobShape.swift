import SwiftUI

struct BlobShape: Shape {
    var amplitude: Float
    var phase: Double

    var animatableData: AnimatablePair<Float, Double> {
        get { AnimatablePair(amplitude, phase) }
        set { amplitude = newValue.first; phase = newValue.second }
    }

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let baseRadius = min(rect.width, rect.height) / 2 * 0.8
        let points = 120
        var path = Path()

        for i in 0...points {
            let angle = (Double(i) / Double(points)) * 2 * .pi
            let d1 = sin(angle * 3 + phase) * Double(amplitude) * 0.30
            let d2 = sin(angle * 5 + phase * 1.3) * Double(amplitude) * 0.15
            let d3 = sin(angle * 7 + phase * 0.7) * Double(amplitude) * 0.10
            let displacement = 1.0 + d1 + d2 + d3
            let r = baseRadius * displacement

            let point = CGPoint(
                x: center.x + CGFloat(r * cos(angle)),
                y: center.y + CGFloat(r * sin(angle))
            )

            if i == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        return path
    }
}
