import Foundation

/// Joint-angle signature for one default exercise. `restAngle`/`activeAngle` are
/// generic goniometry reference values, not measured from this specific user.
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
    /// If true, a rep counts whenever a real movement excursion (already noise-floor
    /// gated) completes, instead of requiring the angle to cross a specific
    /// calibrated threshold value. Exercises whose angle proxy is noisy/imprecise
    /// (like Standing March's 2D knee-raise) kept missing a fixed threshold despite
    /// clearly real, repeated movement — this counts the movement itself.
    let countsByExcursion: Bool

    init(
        name: String,
        primaryAngle: @Sendable @escaping ([String: Double]) -> Double?,
        restAngle: Double, activeAngle: Double, repThreshold: Double,
        maxSpeed: Double, defaultMaxROM: Double?,
        underRangeMessage: String?,
        kneeAlignmentKeys: [String],
        symmetryPairKeys: (left: String, right: String)?,
        countsByExcursion: Bool = false
    ) {
        self.name = name
        self.primaryAngle = primaryAngle
        self.restAngle = restAngle
        self.activeAngle = activeAngle
        self.repThreshold = repThreshold
        self.maxSpeed = maxSpeed
        self.defaultMaxROM = defaultMaxROM
        self.underRangeMessage = underRangeMessage
        self.kneeAlignmentKeys = kneeAlignmentKeys
        self.symmetryPairKeys = symmetryPairKeys
        self.countsByExcursion = countsByExcursion
    }

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
            restAngle: 10, activeAngle: 45, repThreshold: 20,
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
        // not a hip angle — see JointAngleCalculator for why. Counts by excursion
        // (any real detected knee-raise-and-return), not by crossing a specific
        // threshold angle — the 2D proxy's exact values vary too much by camera
        // angle/body for a fixed threshold to reliably hit.
        DefaultExercise.standingMarch.rawValue: ExerciseSignature(
            name: DefaultExercise.standingMarch.rawValue,
            primaryAngle: { min($0["leftKneeRaise"] ?? 100, $0["rightKneeRaise"] ?? 100) },
            restAngle: 90, activeAngle: 60, repThreshold: 78,
            maxSpeed: 400, defaultMaxROM: nil,
            underRangeMessage: "Lift your knee a little higher.",
            kneeAlignmentKeys: [],
            symmetryPairKeys: ("leftKneeRaise", "rightKneeRaise"),
            countsByExcursion: true
        )
    ]
}
