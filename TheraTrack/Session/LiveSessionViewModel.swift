import Foundation
import AVFoundation
import Vision
import Observation

@Observable
final class LiveSessionViewModel {
    private let workout: Workout
    private let poseService = PoseEstimationService()
    private let speaker = SpeechFeedbackSpeaker()
    private let smoother = LandmarkSmoother()
    private let motionGate = MotionGate()
    private var repCounters: [String: RepCounter] = [:]
    private var targetReps: [String: Int] = [:]
    private var violationLog: [String: [(message: String, date: Date)]] = [:]
    private var lastFeedbackShownAt: [String: TimeInterval] = [:]
    private let feedbackRepeatCooldown: TimeInterval = 4
    private let sessionStartedAt = Date()

    /// Exercises run in the fixed order the user set up when creating the workout,
    /// advancing automatically once each one's rep target is hit — no camera-based
    /// recognition of *which* exercise is happening, since that was unreliable and
    /// the plan is already fully known up front.
    private var currentExerciseIndex = 0

    private(set) var currentExerciseName: String?
    private(set) var isSessionComplete = false
    private(set) var latestPoints: [VNHumanBodyPoseObservation.JointName: (location: CGPoint, confidence: Float)] = [:]
    private(set) var feedbackMessage: String?
    private(set) var debugLines: [String] = []
    private(set) var debugHistory: [String] = []
    private var lastDebugHistoryAppend: TimeInterval = -.infinity
    private var firstFrameTimestamp: TimeInterval?

    var previewLayer: AVCaptureVideoPreviewLayer { poseService.previewLayer }

    private var exerciseNames: [String] {
        workout.exercises.sorted { $0.order < $1.order }.map(\.name)
    }

    var currentRepTarget: Int? {
        guard let currentExerciseName else { return nil }
        return targetReps[currentExerciseName]
    }

    var currentRepCount: Int {
        guard let currentExerciseName else { return 0 }
        return repCounters[currentExerciseName]?.repCount ?? 0
    }

    init(workout: Workout) {
        self.workout = workout
        let ordered = workout.exercises.sorted { $0.order < $1.order }
        for exercise in ordered {
            if let signature = ExerciseSignature.all[exercise.name] {
                repCounters[exercise.name] = RepCounter(signature: signature)
            }
            targetReps[exercise.name] = exercise.targetReps
        }
        currentExerciseName = ordered.first?.name

        poseService.onPoseUpdate = { [weak self] snapshot in
            self?.handle(snapshot: snapshot)
        }
    }

    /// Announces the exercise by name whenever the session starts it or switches
    /// to it — the on-screen name pill is unreadable from exercise distance, so
    /// this is how you actually find out which exercise is currently active.
    func announceCurrentExercise() {
        guard let currentExerciseName else { return }
        speaker.speak("Now starting \(currentExerciseName)")
    }

    func start() {
        poseService.requestAccessAndStart()
    }

    func stop() {
        poseService.stop()
    }

    private func handle(snapshot rawSnapshot: PoseSnapshot) {
        let snapshot = smoother.smooth(rawSnapshot)
        latestPoints = snapshot.points
        let namedAngles = JointAngleCalculator.namedAngles(from: snapshot)
        let isRelocating = motionGate.isRelocating(points: snapshot.points, timestamp: snapshot.timestamp)

        updateDebugLines(namedAngles: namedAngles, timestamp: snapshot.timestamp, isRelocating: isRelocating)

        guard !isSessionComplete, !isRelocating,
              let currentExerciseName,
              let signature = ExerciseSignature.all[currentExerciseName],
              let repCounter = repCounters[currentExerciseName] else { return }

        repCounter.update(namedAngles: namedAngles, timestamp: snapshot.timestamp)

        let relevantConstraints = workout.constraints.filter {
            $0.exerciseName == nil || $0.exerciseName == currentExerciseName
        }
        let messages = FormValidator.evaluate(
            namedAngles: namedAngles,
            signature: signature,
            repCounter: repCounter,
            constraints: relevantConstraints
        )

        if let message = messages.first {
            let lastShown = lastFeedbackShownAt[currentExerciseName] ?? -.infinity
            if snapshot.timestamp - lastShown >= feedbackRepeatCooldown {
                feedbackMessage = message
                lastFeedbackShownAt[currentExerciseName] = snapshot.timestamp
                violationLog[currentExerciseName, default: []].append((message: message, date: Date()))
                speaker.speak(message)
            }
        }

        if let target = targetReps[currentExerciseName], repCounter.repCount >= target {
            advanceToNextExercise()
        }
    }

    private func advanceToNextExercise() {
        currentExerciseIndex += 1
        feedbackMessage = nil
        let ordered = exerciseNames
        if currentExerciseIndex < ordered.count {
            currentExerciseName = ordered[currentExerciseIndex]
            announceCurrentExercise()
        } else {
            currentExerciseName = nil
            isSessionComplete = true
            speaker.speak("Workout complete. Great job.")
        }
    }

    private func updateDebugLines(namedAngles: [String: Double], timestamp: TimeInterval, isRelocating: Bool) {
        var lines: [String] = []
        lines.append(
            "relocating=\(isRelocating) lateral=\(String(format: "%.2f", motionGate.lastLateralSpeed)) scale=\(String(format: "%.2f", motionGate.lastScaleChangeRate))"
        )
        for name in exerciseNames {
            guard let signature = ExerciseSignature.all[name], let counter = repCounters[name] else {
                lines.append("\(name): no data")
                continue
            }
            let angleText = signature.primaryAngle(namedAngles).map { "\(Int($0))°" } ?? "—"
            let marker = name == currentExerciseName ? "→" : " "
            let targetText = targetReps[name].map { "/\($0)" } ?? ""
            lines.append("\(marker)\(name): \(angleText) rest=\(Int(counter.calibratedRestAngle))° reps=\(counter.repCount)\(targetText)")
        }
        if let currentExerciseName, let counter = repCounters[currentExerciseName] {
            lines.append("speed: \(Int(counter.lastAngularSpeed))°/s")

            let relevant = workout.constraints.filter { $0.exerciseName == nil || $0.exerciseName == currentExerciseName }
            let constraintTexts = relevant.map(\.text)
            let parsedMaxROM = FormValidator.parsedMaxROM(for: currentExerciseName, constraints: relevant)
            let defaultMaxROM = ExerciseSignature.all[currentExerciseName]?.defaultMaxROM
            let effectiveMaxROM = parsedMaxROM ?? defaultMaxROM
            lines.append(
                "constraints: \(constraintTexts.isEmpty ? "none" : constraintTexts.joined(separator: "; "))"
                + " | maxROM in use: \(effectiveMaxROM.map { "\(Int($0))°" } ?? "none")"
                + " (parsed=\(parsedMaxROM.map { "\(Int($0))°" } ?? "nil"), default=\(defaultMaxROM.map { "\(Int($0))°" } ?? "nil"))"
            )
        }
        debugLines = lines

        if firstFrameTimestamp == nil { firstFrameTimestamp = timestamp }

        if timestamp - lastDebugHistoryAppend >= 0.3 {
            lastDebugHistoryAppend = timestamp
            let elapsed = timestamp - (firstFrameTimestamp ?? timestamp)
            debugHistory.append(String(format: "%5.1fs  ", elapsed) + lines.joined(separator: "  |  "))
        }
    }

    func endSession() -> WorkoutSession {
        poseService.stop()

        let session = WorkoutSession(workoutName: workout.name, startedAt: sessionStartedAt, completedAt: Date())
        session.exercisePerformances = exerciseNames.enumerated().compactMap { index, name in
            guard let counter = repCounters[name] else { return nil }
            let performance = ExercisePerformance(
                exerciseName: name,
                repCount: counter.repCount,
                romAchieved: counter.romAchieved,
                symmetryScore: counter.symmetryScore,
                order: index
            )
            performance.violations = (violationLog[name] ?? []).enumerated().map { violationIndex, entry in
                FormViolation(message: entry.message, timestamp: entry.date, order: violationIndex)
            }
            return performance
        }
        return session
    }
}
