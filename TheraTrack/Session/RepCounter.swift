import Foundation

/// Tracks rep count, achieved range of motion, and per-side angle history for one
/// exercise across a whole session (persists even if the user is auto-switched away
/// and back, so reps keep accumulating rather than resetting).
final class RepCounter {
    let signature: ExerciseSignature

    private(set) var repCount = 0
    private(set) var primaryMin = Double.infinity
    private(set) var primaryMax = -Double.infinity
    private(set) var lastAngularSpeed: Double = 0
    private(set) var lastPeakAngle: Double?

    private var angleRanges: [String: (min: Double, max: Double)] = [:]
    private var phase: Phase = .atRest
    private var lastPrimaryAngle: Double?
    private var lastTimestamp: TimeInterval?
    private var peakSincePhaseStart: Double?

    private enum Phase { case atRest, active }

    init(signature: ExerciseSignature) {
        self.signature = signature
    }

    func update(namedAngles: [String: Double], timestamp: TimeInterval) {
        for (key, value) in namedAngles {
            let existing = angleRanges[key]
            angleRanges[key] = (min: Swift.min(existing?.min ?? value, value), max: Swift.max(existing?.max ?? value, value))
        }

        guard let primary = signature.primaryAngle(namedAngles) else { return }

        primaryMin = Swift.min(primaryMin, primary)
        primaryMax = Swift.max(primaryMax, primary)

        if let lastPrimaryAngle, let lastTimestamp {
            let dt = timestamp - lastTimestamp
            if dt > 0.01 {
                lastAngularSpeed = abs(primary - lastPrimaryAngle) / dt
            }
        }
        lastPrimaryAngle = primary
        lastTimestamp = timestamp

        let movingUp = signature.activeAngle > signature.restAngle
        switch phase {
        case .atRest:
            peakSincePhaseStart = primary
            let crossed = movingUp ? primary >= signature.repThreshold : primary <= signature.repThreshold
            if crossed { phase = .active }
        case .active:
            peakSincePhaseStart = movingUp
                ? Swift.max(peakSincePhaseStart ?? primary, primary)
                : Swift.min(peakSincePhaseStart ?? primary, primary)
            let crossed = movingUp ? primary <= signature.repThreshold : primary >= signature.repThreshold
            if crossed {
                phase = .atRest
                repCount += 1
                lastPeakAngle = peakSincePhaseStart
            }
        }
    }

    var romAchieved: Double {
        guard primaryMax >= primaryMin else { return 0 }
        return primaryMax - primaryMin
    }

    var symmetryScore: Double? {
        guard let pair = signature.symmetryPairKeys,
              let left = angleRanges[pair.left], let right = angleRanges[pair.right] else { return nil }
        let leftROM = left.max - left.min
        let rightROM = right.max - right.min
        let larger = Swift.max(leftROM, rightROM, 1)
        return Swift.max(0, 1 - abs(leftROM - rightROM) / larger)
    }
}
