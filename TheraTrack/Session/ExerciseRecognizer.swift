import Foundation

/// Picks which planned exercise the current pose most resembles, and only switches
/// the "current" exercise once a different one has scored best for a sustained
/// period (avoids flickering between exercises frame-to-frame).
final class ExerciseRecognizer {
    private let sustainedDuration: TimeInterval
    private var candidateName: String?
    private var candidateSince: TimeInterval?

    init(sustainedDuration: TimeInterval = 2.0) {
        self.sustainedDuration = sustainedDuration
    }

    func update(
        namedAngles: [String: Double],
        timestamp: TimeInterval,
        currentExercise: String?,
        allowedExercises: [String]
    ) -> String? {
        var bestName: String?
        var bestDistance = Double.greatestFiniteMagnitude

        for exerciseName in allowedExercises {
            guard let signature = ExerciseSignature.all[exerciseName],
                  let angle = signature.primaryAngle(namedAngles) else { continue }

            let low = min(signature.restAngle, signature.activeAngle)
            let high = max(signature.restAngle, signature.activeAngle)
            let distance: Double
            if angle < low {
                distance = low - angle
            } else if angle > high {
                distance = angle - high
            } else {
                distance = 0
            }

            if distance < bestDistance {
                bestDistance = distance
                bestName = exerciseName
            }
        }

        guard let bestName else { return currentExercise }

        if bestName == currentExercise {
            candidateName = nil
            candidateSince = nil
            return currentExercise
        }

        if candidateName == bestName, let since = candidateSince {
            if timestamp - since >= sustainedDuration {
                candidateName = nil
                candidateSince = nil
                return bestName
            }
        } else {
            candidateName = bestName
            candidateSince = timestamp
        }

        return currentExercise
    }
}
