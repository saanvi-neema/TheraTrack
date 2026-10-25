import Foundation
import CoreGraphics
import Vision

/// Exponentially smooths raw per-frame joint positions to damp the frame-to-frame
/// jitter inherent in pose detection. Unsmoothed jitter otherwise reads as false
/// "moving too fast" speed spikes and noisy angle/ratio measurements — especially
/// once the subject is far enough from the camera to show their full body, where
/// the same pixel-level noise is proportionally larger relative to body size.
final class LandmarkSmoother {
    private let smoothingFactor: Double
    private var smoothed: [VNHumanBodyPoseObservation.JointName: CGPoint] = [:]

    init(smoothingFactor: Double = 0.3) {
        self.smoothingFactor = smoothingFactor
    }

    func smooth(_ snapshot: PoseSnapshot) -> PoseSnapshot {
        var result: [VNHumanBodyPoseObservation.JointName: (location: CGPoint, confidence: Float)] = [:]

        for (name, entry) in snapshot.points {
            if let previous = smoothed[name] {
                let newPoint = CGPoint(
                    x: previous.x + (entry.location.x - previous.x) * smoothingFactor,
                    y: previous.y + (entry.location.y - previous.y) * smoothingFactor
                )
                smoothed[name] = newPoint
                result[name] = (location: newPoint, confidence: entry.confidence)
            } else {
                smoothed[name] = entry.location
                result[name] = entry
            }
        }

        return PoseSnapshot(points: result, timestamp: snapshot.timestamp)
    }
}
