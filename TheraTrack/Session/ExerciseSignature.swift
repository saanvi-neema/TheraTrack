import Foundation

/// Hand-specified, heuristic joint-angle signature for one default exercise.
/// These rest/active/threshold/speed numbers are v1 placeholder estimates, not
/// PT-verified values — they need real tuning once tested against actual movement.
struct ExerciseSignature: Sendable {
    let name: String
    /// Picks the single most relevant angle (degrees) for this exercise out of the
    /// full named-angle dictionary for the current frame.
    let primaryAngle: @Sendable ([String: Double]) -> Double?
    /// Angle at the resting/starting position.
    let restAngle: Double
    /// Angle at the fully-active/peak position.
    let activeAngle: Double
    /// Crossing this value (between rest and active) counts as a rep-phase transition.
    let repThreshold: Double
    /// Angular speed (deg/sec) above which we warn "slow down."
    let maxSpeed: Double
    /// Fallback max range-of-motion (degrees) if no numeric constraint overrides it.
    let defaultMaxROM: Double?
    /// Shown if a completed rep's peak angle falls well short of `activeAngle` — nil if not applicable.
    let underRangeMessage: String?
    /// Named angle keys checked for knee-alignment ("keep your knees aligned") violations.
    let kneeAlignmentKeys: [String]
    /// Left/right named-angle keys used to compute a symmetry score, if this exercise is bilateral.
    let symmetryPairKeys: (left: String, right: String)?

    static let all: [String: ExerciseSignature] = [
        DefaultExercise.sitToStand.rawValue: ExerciseSignature(
            name: DefaultExercise.sitToStand.rawValue,
            primaryAngle: { max($0["leftKnee"] ?? 0, $0["rightKnee"] ?? 0) },
            restAngle: 90, activeAngle: 170, repThreshold: 130,
            maxSpeed: 90, defaultMaxROM: nil,
            underRangeMessage: "Try to stand up fully.",
            kneeAlignmentKeys: ["kneeAlignmentLeft", "kneeAlignmentRight"],
            symmetryPairKeys: ("leftKnee", "rightKnee")
        ),
        DefaultExercise.shoulderAbduction.rawValue: ExerciseSignature(
            name: DefaultExercise.shoulderAbduction.rawValue,
            primaryAngle: { max($0["leftShoulderAbduction"] ?? 0, $0["rightShoulderAbduction"] ?? 0) },
            restAngle: 10, activeAngle: 90, repThreshold: 50,
            maxSpeed: 60, defaultMaxROM: 180,
            underRangeMessage: "Raise your arm slightly higher.",
            kneeAlignmentKeys: [],
            symmetryPairKeys: ("leftShoulderAbduction", "rightShoulderAbduction")
        ),
        DefaultExercise.heelSlides.rawValue: ExerciseSignature(
            name: DefaultExercise.heelSlides.rawValue,
            primaryAngle: { min($0["leftKnee"] ?? 180, $0["rightKnee"] ?? 180) },
            restAngle: 170, activeAngle: 100, repThreshold: 140,
            maxSpeed: 40, defaultMaxROM: 120,
            underRangeMessage: nil,
            kneeAlignmentKeys: ["kneeAlignmentLeft", "kneeAlignmentRight"],
            symmetryPairKeys: ("leftKnee", "rightKnee")
        ),
        DefaultExercise.kneeExtension.rawValue: ExerciseSignature(
            name: DefaultExercise.kneeExtension.rawValue,
            primaryAngle: { max($0["leftKnee"] ?? 0, $0["rightKnee"] ?? 0) },
            restAngle: 90, activeAngle: 175, repThreshold: 140,
            maxSpeed: 60, defaultMaxROM: nil,
            underRangeMessage: "Try to straighten your knee fully.",
            kneeAlignmentKeys: ["kneeAlignmentLeft", "kneeAlignmentRight"],
            symmetryPairKeys: ("leftKnee", "rightKnee")
        ),
        DefaultExercise.anklePumps.rawValue: ExerciseSignature(
            name: DefaultExercise.anklePumps.rawValue,
            primaryAngle: { max($0["leftAnkleLift"] ?? 0, $0["rightAnkleLift"] ?? 0) },
            restAngle: 0, activeAngle: 20, repThreshold: 10,
            maxSpeed: 30, defaultMaxROM: nil,
            underRangeMessage: nil,
            kneeAlignmentKeys: [],
            symmetryPairKeys: ("leftAnkleLift", "rightAnkleLift")
        ),
        DefaultExercise.standingMarch.rawValue: ExerciseSignature(
            name: DefaultExercise.standingMarch.rawValue,
            primaryAngle: { min($0["leftHip"] ?? 180, $0["rightHip"] ?? 180) },
            restAngle: 170, activeAngle: 100, repThreshold: 140,
            maxSpeed: 100, defaultMaxROM: nil,
            underRangeMessage: "Lift your knee a little higher.",
            kneeAlignmentKeys: [],
            symmetryPairKeys: ("leftHip", "rightHip")
        )
    ]
}
