import Foundation
import AVFoundation
import Vision
import Observation

@Observable
final class LiveSessionViewModel {
    private let workout: Workout
    private let poseService = PoseEstimationService()
    private let recognizer = ExerciseRecognizer()
    private var repCounters: [String: RepCounter] = [:]
    private var violationLog: [String: [(message: String, date: Date)]] = [:]
    private var lastFeedbackShownAt: [String: TimeInterval] = [:]
    private let feedbackRepeatCooldown: TimeInterval = 4
    private let sessionStartedAt = Date()

    private(set) var currentExerciseName: String?
    private(set) var latestPoints: [VNHumanBodyPoseObservation.JointName: (location: CGPoint, confidence: Float)] = [:]
    private(set) var feedbackMessage: String?

    var previewLayer: AVCaptureVideoPreviewLayer { poseService.previewLayer }

    private var exerciseNames: [String] {
        workout.exercises.sorted { $0.order < $1.order }.map(\.name)
    }

    var currentRepCount: Int {
        guard let currentExerciseName else { return 0 }
        return repCounters[currentExerciseName]?.repCount ?? 0
    }

    init(workout: Workout) {
        self.workout = workout
        for name in workout.exercises.map(\.name) {
            if let signature = ExerciseSignature.all[name] {
                repCounters[name] = RepCounter(signature: signature)
            }
        }
        poseService.onPoseUpdate = { [weak self] snapshot in
            self?.handle(snapshot: snapshot)
        }
    }

    func start() {
        poseService.requestAccessAndStart()
    }

    func stop() {
        poseService.stop()
    }

    private func handle(snapshot: PoseSnapshot) {
        latestPoints = snapshot.points
        let namedAngles = JointAngleCalculator.namedAngles(from: snapshot)

        let recognized = recognizer.update(
            namedAngles: namedAngles,
            timestamp: snapshot.timestamp,
            currentExercise: currentExerciseName,
            allowedExercises: exerciseNames
        )
        if recognized != currentExerciseName {
            currentExerciseName = recognized
            feedbackMessage = nil
        }

        guard let currentExerciseName,
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

        guard let message = messages.first else { return }
        let lastShown = lastFeedbackShownAt[currentExerciseName] ?? -.infinity
        if snapshot.timestamp - lastShown >= feedbackRepeatCooldown {
            feedbackMessage = message
            lastFeedbackShownAt[currentExerciseName] = snapshot.timestamp
            violationLog[currentExerciseName, default: []].append((message: message, date: Date()))
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
