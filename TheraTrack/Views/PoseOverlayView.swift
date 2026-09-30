import SwiftUI
import Vision

struct PoseOverlayView: View {
    let points: [VNHumanBodyPoseObservation.JointName: (location: CGPoint, confidence: Float)]

    private static let connections: [(VNHumanBodyPoseObservation.JointName, VNHumanBodyPoseObservation.JointName)] = [
        (.leftShoulder, .rightShoulder),
        (.leftShoulder, .leftElbow), (.leftElbow, .leftWrist),
        (.rightShoulder, .rightElbow), (.rightElbow, .rightWrist),
        (.leftShoulder, .leftHip), (.rightShoulder, .rightHip), (.leftHip, .rightHip),
        (.leftHip, .leftKnee), (.leftKnee, .leftAnkle),
        (.rightHip, .rightKnee), (.rightKnee, .rightAnkle)
    ]

    private let confidenceThreshold: Float = 0.3

    var body: some View {
        Canvas { context, size in
            func convert(_ point: CGPoint) -> CGPoint {
                // Vision points are normalized (0-1, origin bottom-left); the front
                // camera preview is mirrored, so flip both axes for screen space.
                CGPoint(x: (1 - point.x) * size.width, y: (1 - point.y) * size.height)
            }

            for (a, b) in Self.connections {
                guard let pointA = points[a], pointA.confidence >= confidenceThreshold,
                      let pointB = points[b], pointB.confidence >= confidenceThreshold else { continue }
                var path = Path()
                path.move(to: convert(pointA.location))
                path.addLine(to: convert(pointB.location))
                context.stroke(path, with: .color(.green), lineWidth: 3)
            }

            for entry in points.values where entry.confidence >= confidenceThreshold {
                let center = convert(entry.location)
                let rect = CGRect(x: center.x - 4, y: center.y - 4, width: 8, height: 8)
                context.fill(Path(ellipseIn: rect), with: .color(.yellow))
            }
        }
    }
}
