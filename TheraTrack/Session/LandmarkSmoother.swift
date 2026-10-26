import Foundation
import CoreGraphics
import simd

/// Exponentially smooths raw per-frame joint positions to damp pose-detection jitter.
final class LandmarkSmoother {
    private let smoothingFactor: Double
    private var smoothed2D: [String: CGPoint] = [:]
    private var smoothed3D: [String: SIMD3<Float>] = [:]

    init(smoothingFactor: Double = 0.3) {
        self.smoothingFactor = smoothingFactor
    }

    func smooth(_ snapshot: PoseSnapshot) -> PoseSnapshot {
        var result2D: [String: (location: CGPoint, confidence: Float)] = [:]
        var result3D: [String: SIMD3<Float>] = [:]

        for (name, entry) in snapshot.points2D {
            if let previous = smoothed2D[name] {
                let newPoint = CGPoint(
                    x: previous.x + (entry.location.x - previous.x) * smoothingFactor,
                    y: previous.y + (entry.location.y - previous.y) * smoothingFactor
                )
                smoothed2D[name] = newPoint
                result2D[name] = (location: newPoint, confidence: entry.confidence)
            } else {
                smoothed2D[name] = entry.location
                result2D[name] = entry
            }
        }

        let alpha = Float(smoothingFactor)
        for (name, position) in snapshot.points3D {
            if let previous = smoothed3D[name] {
                let newPosition = previous + (position - previous) * alpha
                smoothed3D[name] = newPosition
                result3D[name] = newPosition
            } else {
                smoothed3D[name] = position
                result3D[name] = position
            }
        }

        return PoseSnapshot(points2D: result2D, points3D: result3D, timestamp: snapshot.timestamp)
    }
}
