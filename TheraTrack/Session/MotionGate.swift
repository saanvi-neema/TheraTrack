import Foundation
import CoreGraphics

/// Detects walking/relocating vs. actually performing an exercise in place, so
/// feedback doesn't fire while the user is adjusting the camera.
final class MotionGate {
    private struct Sample {
        let timestamp: TimeInterval
        let hipMidpoint: CGPoint
        let torsoLength: Double
    }

    private let window: TimeInterval
    private let lateralSpeedThreshold: Double
    private let scaleChangeRateThreshold: Double
    private var samples: [Sample] = []

    /// Exposed for the debug log, to calibrate the thresholds above against real numbers.
    private(set) var lastLateralSpeed: Double = 0
    private(set) var lastScaleChangeRate: Double = 0

    init(
        window: TimeInterval = 0.6,
        lateralSpeedThreshold: Double = 0.12,
        scaleChangeRateThreshold: Double = 0.25
    ) {
        self.window = window
        self.lateralSpeedThreshold = lateralSpeedThreshold
        self.scaleChangeRateThreshold = scaleChangeRateThreshold
    }

    func isRelocating(
        points: [String: (location: CGPoint, confidence: Float)],
        timestamp: TimeInterval
    ) -> Bool {
        let confidenceThreshold: Float = 0.3
        func point(_ name: String) -> CGPoint? {
            guard let entry = points[name], entry.confidence >= confidenceThreshold else { return nil }
            return entry.location
        }

        guard let leftHip = point("leftHip"), let rightHip = point("rightHip"),
              let leftShoulder = point("leftShoulder"), let rightShoulder = point("rightShoulder") else {
            // Not enough landmarks to judge either way — don't block on missing data.
            return false
        }

        let hipMid = CGPoint(x: (leftHip.x + rightHip.x) / 2, y: (leftHip.y + rightHip.y) / 2)
        let shoulderMid = CGPoint(x: (leftShoulder.x + rightShoulder.x) / 2, y: (leftShoulder.y + rightShoulder.y) / 2)
        let torsoLength = Double(hypot(shoulderMid.x - hipMid.x, shoulderMid.y - hipMid.y))

        samples.append(Sample(timestamp: timestamp, hipMidpoint: hipMid, torsoLength: torsoLength))
        samples.removeAll { timestamp - $0.timestamp > window }

        guard let oldest = samples.first, let newest = samples.last,
              newest.timestamp - oldest.timestamp > 0.2 else {
            // Too little history to judge yet — treat as still settling in. Resolves
            // in a fraction of a second rather than blocking on a fixed duration.
            return true
        }

        let dt = newest.timestamp - oldest.timestamp
        // Sideways repositioning: hip midpoint drifting across the frame.
        let lateralSpeed = abs(Double(newest.hipMidpoint.x - oldest.hipMidpoint.x)) / dt
        // Walking toward/away from the camera: apparent torso length (shoulder-to-hip
        // distance in frame) grows or shrinks as distance-to-camera changes, even when
        // there's little sideways drift (e.g. walking straight backward).
        let scaleChangeRate = abs(newest.torsoLength - oldest.torsoLength) / max(oldest.torsoLength, 0.01) / dt

        lastLateralSpeed = lateralSpeed
        lastScaleChangeRate = scaleChangeRate

        return lateralSpeed > lateralSpeedThreshold || scaleChangeRate > scaleChangeRateThreshold
    }
}
