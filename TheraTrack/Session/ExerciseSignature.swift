import Foundation

/// Joint-angle signature for one default exercise. `restAngle`/`activeAngle` are
/// generic population-average reference values from published goniometry norms
/// (e.g. shoulder abduction to shoulder height ≈ 90°, hip flexion for a knee raise
/// ≈ 90-120°, full knee extension ≈ 180° interior angle i.e. 0° flexion, seated
/// knee flexion ≈ 90°, ankle dorsi/plantarflexion ≈ 15-20°/40-50°) — not numbers
/// measured from this specific user. `activeAngle` is the clinical target and is
/// intentionally left fixed, since it's the thing form-checking is judging against;
/// `restAngle` is personalized live per user via `RepCounter.calibratedRestAngle`,
/// since a resting pose is about an individual's body/camera setup, not a clinical
/// target.
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
            restAngle: 90, activeAngle: 175, repThreshold: 130,
            maxSpeed: 90, defaultMaxROM: nil,
            underRangeMessage: "Try to stand up fully.",
            kneeAlignmentKeys: ["kneeAlignmentLeft", "kneeAlignmentRight"],
            symmetryPairKeys: ("leftKnee", "rightKnee")
        ),
        DefaultExercise.shoulderAbduction.rawValue: ExerciseSignature(
            name: DefaultExercise.shoulderAbduction.rawValue,
            primaryAngle: { max($0["leftShoulderAbduction"] ?? 0, $0["rightShoulderAbduction"] ?? 0) },
            restAngle: 10, activeAngle: 90, repThreshold: 50,
            maxSpeed: 180, defaultMaxROM: 180,
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
            restAngle: 90, activeAngle: 178, repThreshold: 140,
            maxSpeed: 60, defaultMaxROM: nil,
            underRangeMessage: "Try to straighten your knee fully.",
            kneeAlignmentKeys: ["kneeAlignmentLeft", "kneeAlignmentRight"],
            symmetryPairKeys: ("leftKnee", "rightKnee")
        ),
        // "AnkleLift" is a vertical-displacement proxy (knee-to-ankle y-gap), not a
        // goniometry angle — Vision has no foot/toe landmark to measure true ankle
        // dorsi/plantarflexion, so these numbers are a scaled heuristic, not a
        // sourced clinical value, and lean more heavily on live calibration.
        DefaultExercise.anklePumps.rawValue: ExerciseSignature(
            name: DefaultExercise.anklePumps.rawValue,
            primaryAngle: { max($0["leftAnkleLift"] ?? 0, $0["rightAnkleLift"] ?? 0) },
            restAngle: 0, activeAngle: 20, repThreshold: 10,
            maxSpeed: 30, defaultMaxROM: nil,
            underRangeMessage: nil,
            kneeAlignmentKeys: [],
            symmetryPairKeys: ("leftAnkleLift", "rightAnkleLift")
        ),
        // Uses "KneeRaise" (a torso-length-scaled vertical knee-to-hip distance),
        // not a hip angle — viewed head-on, the hip-shoulder-knee angle barely
        // changes as the knee rises because that motion is mostly toward the
        // camera, not across it, and gets badly foreshortened in a 2D projection.
        DefaultExercise.standingMarch.rawValue: ExerciseSignature(
            name: DefaultExercise.standingMarch.rawValue,
            primaryAngle: { min($0["leftKneeRaise"] ?? 100, $0["rightKneeRaise"] ?? 100) },
            restAngle: 90, activeAngle: 20, repThreshold: 55,
            // This metric's scale isn't degrees, so it isn't comparable to the other
            // exercises' maxSpeed values — a normal-paced rep swings through a much
            // bigger number on this scale than the same motion would in true degrees.
            maxSpeed: 400, defaultMaxROM: nil,
            underRangeMessage: "Lift your knee a little higher.",
            kneeAlignmentKeys: [],
            symmetryPairKeys: ("leftKneeRaise", "rightKneeRaise")
        )
    ]
}
