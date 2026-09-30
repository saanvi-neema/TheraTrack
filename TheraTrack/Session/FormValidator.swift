import Foundation

enum FormValidator {
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
                messages.append("Keep your knees aligned.")
                break
            }
        }

        if repCounter.lastAngularSpeed > signature.maxSpeed {
            messages.append("Slow down the movement.")
        }

        if let primary = signature.primaryAngle(namedAngles) {
            let maxROM = maxROMOverride(for: signature.name, constraints: constraints) ?? signature.defaultMaxROM
            if let maxROM, primary > maxROM {
                messages.append("Do not exceed your prescribed range of motion.")
            }
        }

        if let underRangeMessage = signature.underRangeMessage, let peak = repCounter.lastPeakAngle {
            let tolerance = abs(signature.activeAngle - signature.restAngle) * 0.15
            if abs(peak - signature.activeAngle) > tolerance {
                messages.append(underRangeMessage)
            }
        }

        return messages
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
