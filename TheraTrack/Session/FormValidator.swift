import Foundation

enum FormValidator {
    // Named so the same literal text can be pre-rendered to audio once (see
    // SpeechFeedbackSpeaker.prewarm) and stay in sync with what's actually spoken,
    // rather than two copies of the wording risking drifting apart.
    static let kneeAlignmentMessage = "Keep your knees aligned."
    static let slowDownMessage = "Slow down the movement."
    static let exceedROMMessage = "Do not exceed your prescribed range of motion."

    /// Runs the rule-based safety checks for the current frame and returns any
    /// feedback messages that apply (empty if form looks fine this frame).
    static func evaluate(
        namedAngles: [String: Double],
        signature: ExerciseSignature,
        repCounter: RepCounter,
        constraints: [Constraint]
    ) -> [String] {
        var messages: [String] = []

        for key in signature.kneeAlignmentKeys {
            if let offset = namedAngles[key], abs(offset) > 0.15 {
                messages.append(kneeAlignmentMessage)
                break
            }
        }

        if repCounter.lastAngularSpeed > signature.maxSpeed {
            messages.append(slowDownMessage)
        }

        let maxROM = maxROMOverride(for: signature.name, constraints: constraints) ?? signature.defaultMaxROM

        if let primary = signature.primaryAngle(namedAngles) {
            if let maxROM, primary > maxROM {
                messages.append(exceedROMMessage)
            }
        }

        // Only judged at the instant the movement reverses direction at the top of
        // a rep (see `RepCounter.peakJustReached`) — using `lastPeakAngle`, the true
        // peak just locked in right then. Checking this continuously during the
        // rise would flag a rep that's still climbing fine as having fallen short;
        // checking it against an old rep's peak would judge the wrong rep entirely.
        if let underRangeMessage = signature.underRangeMessage, repCounter.peakJustReached, let peak = repCounter.lastPeakAngle {
            let movingUp = signature.activeAngle > signature.restAngle
            // The real target can never ask the user to exceed a personalized
            // max-ROM constraint — otherwise "reach full range" and "don't exceed
            // your prescribed limit" become mutually impossible to satisfy at once,
            // which is exactly what was happening: a 90° generic target combined
            // with a 50° personalized cap meant no angle could ever be "correct."
            let effectiveTarget: Double
            if let maxROM {
                effectiveTarget = movingUp ? Swift.min(signature.activeAngle, maxROM) : Swift.max(signature.activeAngle, maxROM)
            } else {
                effectiveTarget = signature.activeAngle
            }
            // Direction-aware: only flag falling SHORT of the target, in whichever
            // direction this exercise's active angle actually moves. Checking
            // |peak - target| instead would also flag *exceeding* it — e.g. raising
            // a knee higher than expected — as if that were a fault.
            //
            // Tolerance is sized off the exercise's own generic rest/active span, not
            // the (possibly much tighter) personalized target — otherwise a stricter
            // safety constraint also shrinks the margin for error, making an already
            // tighter window even harder to hit by feel. A fixed fraction of the full
            // span gives a realistically hittable band no matter how tight the
            // personalized cap is.
            let tolerance = abs(signature.activeAngle - signature.restAngle) * 0.2
            let shortfall = movingUp ? (effectiveTarget - peak) : (peak - effectiveTarget)
            if shortfall > tolerance {
                messages.append(underRangeMessage)
            }
        }

        return messages
    }

    /// Exposed for the debug log, so what's actually being checked against is
    /// visible instead of assumed.
    static func parsedMaxROM(for exerciseName: String, constraints: [Constraint]) -> Double? {
        maxROMOverride(for: exerciseName, constraints: constraints)
    }

    private static func maxROMOverride(for exerciseName: String, constraints: [Constraint]) -> Double? {
        let relevant = constraints.filter { $0.exerciseName == nil || $0.exerciseName == exerciseName }
        for constraint in relevant {
            if let value = firstDegreeNumber(in: constraint.text) {
                return value
            }
        }
        return nil
    }

    private static func firstDegreeNumber(in text: String) -> Double? {
        guard let regex = try? NSRegularExpression(
            pattern: #"(\d+(?:\.\d+)?)\s*(?:°|degrees?)"#,
            options: .caseInsensitive
        ) else { return nil }

        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              let numberRange = Range(match.range(at: 1), in: text) else { return nil }
        return Double(text[numberRange])
    }
}
