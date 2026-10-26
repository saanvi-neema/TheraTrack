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
    /// Set the moment a rep completes — a real up-and-back cycle, which is much
    /// stronger evidence of "this exercise is actually happening" than any single
    /// snapshot of the joint angle, and is what exercise recognition keys off now.
    private(set) var lastRepCompletedAt: TimeInterval?

    private var angleRanges: [String: (min: Double, max: Double)] = [:]
    private var phase: Phase = .atRest
    var isInActivePhase: Bool { phase == .active }
    private var peakSincePhaseStart: Double?

    /// Tracks the extremum of ANY noticeable movement attempt and returns, even
    /// one too small to cross `repThreshold` and count as a full rep — so "you
    /// didn't reach far enough" feedback can fire for a half-hearted attempt, not
    /// only for fully-completed reps. Without this, a movement too small to ever
    /// register as a rep also never set `lastPeakAngle`, so it got no feedback at
    /// all instead of being told to go further.
    private var excursionPeak: Double?
    /// True only while a real, deliberate movement is in progress (bigger than
    /// sensor noise) — ALL feedback is gated on this, not just the under-range
    /// check, so nothing fires while setting up the camera, standing idle, or
    /// adjusting position between exercises.
    private(set) var isInExcursion = false

    /// Angular speed is measured over this rolling window, not frame-to-frame —
    /// a single-frame derivative amplifies ordinary pose-detection jitter (most of
    /// all near a fully-extended joint, where `acos` is most sensitive to tiny
    /// position noise) into a false reading of hundreds of °/s even while holding
    /// still, which falsely triggered "slow down" regardless of actual movement.
    private let speedWindow: TimeInterval = 0.3
    private var speedSamples: [(timestamp: TimeInterval, value: Double)] = []

    /// Per-side excursion state for `countsByExcursion` exercises, keyed by the
    /// side's own named-angle key. Needed because the combined `primary` signal
    /// (e.g. min of left/right knee raise) can stay perpetually "active" during
    /// alternating-leg movement like marching — while one leg comes down the other
    /// is already going up, so the combined signal never dips back to rest between
    /// reps, merging many real reps into one. Tracking each side's own lift-and-
    /// return independently counts one rep per leg, matching what actually happened.
    private var sideInExcursion: [String: Bool] = [:]

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

        speedSamples.append((timestamp: timestamp, value: primary))
        speedSamples.removeAll { timestamp - $0.timestamp > speedWindow }
        if let oldest = speedSamples.first, timestamp - oldest.timestamp > 0.1 {
            lastAngularSpeed = abs(primary - oldest.value) / (timestamp - oldest.timestamp)
        }

        let movingUp = signature.activeAngle > signature.restAngle

        let span = abs(signature.activeAngle - signature.restAngle)
        // Must be a clear, deliberate movement — not just bigger than sensor noise.
        // At 8% of span this was only marginally above typical 3D-angle jitter, so
        // standing still could cross it on noise alone and trigger feedback for
        // movement that never happened.
        let noiseFloor = span * 0.3
        let deviation = movingUp ? (primary - calibratedRestAngle) : (calibratedRestAngle - primary)
        if deviation > noiseFloor {
            if isInExcursion {
                excursionPeak = movingUp ? Swift.max(excursionPeak ?? primary, primary) : Swift.min(excursionPeak ?? primary, primary)
            } else {
                isInExcursion = true
                excursionPeak = primary
            }
        } else if isInExcursion {
            if let excursionPeak {
                lastPeakAngle = excursionPeak
            }
            isInExcursion = false
            excursionPeak = nil
        }

        if signature.countsByExcursion {
            // Counted per side, not off the combined `primary` signal above — see
            // `sideInExcursion`'s doc comment for why. Entering and leaving the
            // excursion use different thresholds (the same hysteresis-gap idea as
            // the phase-based counter below), so ordinary signal jitter near one
            // single boundary can't flip the state back and forth and count the
            // same real rep multiple times.
            let hysteresisGap = span * 0.1
            let enterFloor = noiseFloor + hysteresisGap / 2
            let exitFloor = noiseFloor - hysteresisGap / 2
            if let pair = signature.symmetryPairKeys {
                for key in [pair.left, pair.right] {
                    guard let value = namedAngles[key] else { continue }
                    let sideDeviation = movingUp ? (value - calibratedRestAngle) : (calibratedRestAngle - value)
                    let wasActive = sideInExcursion[key] ?? false
                    if !wasActive, sideDeviation > enterFloor {
                        sideInExcursion[key] = true
                    } else if wasActive, sideDeviation < exitFloor {
                        sideInExcursion[key] = false
                        repCount += 1
                        lastRepCompletedAt = timestamp
                    }
                }
            }
            return
        }

        let threshold = calibratedRepThreshold
        // A single crossing value lets ordinary pose-jitter near that exact angle
        // flip the phase back and forth several times during one continuous
        // motion, each flip counting as a full rep — e.g. 2 real reps reading as
        // 5. Entering and exiting "active" now require crossing slightly different
        // thresholds, creating a dead zone around the midpoint that a small wobble
        // can't repeatedly cross.
        let hysteresisGap = span * 0.1
        switch phase {
        case .atRest:
            peakSincePhaseStart = primary
            let enterThreshold = movingUp ? threshold + hysteresisGap / 2 : threshold - hysteresisGap / 2
            let crossed = movingUp ? primary >= enterThreshold : primary <= enterThreshold
            if crossed { phase = .active }
        case .active:
            peakSincePhaseStart = movingUp
                ? Swift.max(peakSincePhaseStart ?? primary, primary)
                : Swift.min(peakSincePhaseStart ?? primary, primary)
            let exitThreshold = movingUp ? threshold - hysteresisGap / 2 : threshold + hysteresisGap / 2
            let crossed = movingUp ? primary <= exitThreshold : primary >= exitThreshold
            if crossed {
                phase = .atRest
                repCount += 1
                lastPeakAngle = peakSincePhaseStart
                lastRepCompletedAt = timestamp
            }
        }
    }

    /// This user's actual resting angle for this exercise, refined live from
    /// observed movement — starts at the generic textbook default and blends
    /// toward the real observed low end once there's data, so differences in body,
    /// camera angle, or chair height stop being graded against a one-size-fits-all
    /// number. The active/target angle is deliberately NOT personalized this way,
    /// since that's the clinical goal being checked, not a baseline.
    var calibratedRestAngle: Double {
        guard primaryMax >= primaryMin, primaryMin.isFinite, primaryMax.isFinite else {
            return signature.restAngle
        }
        let movingUp = signature.activeAngle > signature.restAngle
        let observedRest = movingUp ? primaryMin : primaryMax
        return (signature.restAngle + observedRest) / 2
    }

    /// `signature.repThreshold`, re-expressed as the same fraction of the way from
    /// `calibratedRestAngle` to `signature.activeAngle` — so rep-phase crossing
    /// adapts along with the personalized rest baseline.
    var calibratedRepThreshold: Double {
        let rest = calibratedRestAngle
        let span = signature.activeAngle - signature.restAngle
        guard span != 0 else { return signature.repThreshold }
        let fraction = (signature.repThreshold - signature.restAngle) / span
        return rest + fraction * (signature.activeAngle - rest)
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
