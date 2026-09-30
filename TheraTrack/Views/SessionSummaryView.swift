import SwiftUI
import SwiftData

struct SessionSummaryView: View {
    let session: WorkoutSession
    let onDone: () -> Void

    @Query(sort: \WorkoutSession.startedAt, order: .reverse) private var allSessions: [WorkoutSession]

    private var previousSession: WorkoutSession? {
        allSessions.first { $0.workoutName == session.workoutName && $0.id != session.id }
    }

    private var sortedPerformances: [ExercisePerformance] {
        session.exercisePerformances.sorted { $0.order < $1.order }
    }

    private var allViolations: [FormViolation] {
        session.exercisePerformances.flatMap(\.violations).sorted { $0.timestamp < $1.timestamp }
    }

    private var mostFlaggedExercise: ExercisePerformance? {
        sortedPerformances.max { $0.violations.count < $1.violations.count }
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Exercises Completed") {
                    if sortedPerformances.isEmpty {
                        Text("No exercises were detected this session.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(sortedPerformances) { performance in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(performance.exerciseName).font(.headline)
                                Text("\(performance.repCount) reps · ROM \(Int(performance.romAchieved))°")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                if let symmetry = performance.symmetryScore {
                                    Text("Symmetry: \(Int(symmetry * 100))%")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }

                Section("Form Corrections") {
                    if allViolations.isEmpty {
                        Text("No form corrections needed. Great job!")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(allViolations) { violation in
                            Text(violation.message)
                        }
                    }
                }

                if let previousSession {
                    Section("Progress vs Last Session") {
                        ForEach(sortedPerformances) { performance in
                            if let prior = previousSession.exercisePerformances.first(where: { $0.exerciseName == performance.exerciseName }) {
                                let delta = performance.romAchieved - prior.romAchieved
                                Text("\(performance.exerciseName): ROM \(delta >= 0 ? "+" : "")\(Int(delta))° vs last time")
                            }
                        }
                    }
                }

                Section("Areas to Focus On") {
                    if let mostFlaggedExercise, !mostFlaggedExercise.violations.isEmpty {
                        Text("\(mostFlaggedExercise.exerciseName) had the most form corrections (\(mostFlaggedExercise.violations.count)). Consider focusing here next session.")
                    } else {
                        Text("No specific areas flagged this session.")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Session Summary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: onDone)
                }
            }
        }
    }
}
