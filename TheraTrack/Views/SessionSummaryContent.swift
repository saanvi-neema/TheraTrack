import SwiftUI
import SwiftData

/// Session-analysis content shared between the live-session summary and History tab.
struct SessionSummaryContent<Extra: View>: View {
    let session: WorkoutSession
    @ViewBuilder var extra: () -> Extra

    @Query(sort: \WorkoutSession.startedAt, order: .reverse) private var allSessions: [WorkoutSession]

    private struct ViolationSummary: Identifiable {
        let id = UUID()
        let exerciseName: String
        let message: String
        let count: Int
    }

    private var previousSession: WorkoutSession? {
        // Find the most recent session of the same workout that happened BEFORE
        // this one — not just "any other session with this name" — so that
        // browsing an old session from History never compares it against a
        // session that happened later.
        allSessions.first { $0.workoutName == session.workoutName && $0.startedAt < session.startedAt }
    }

    private var sortedPerformances: [ExercisePerformance] {
        session.exercisePerformances.sorted { $0.order < $1.order }
    }

    private var groupedViolations: [ViolationSummary] {
        sortedPerformances.flatMap { performance in
            Dictionary(grouping: performance.violations, by: \.message).map { message, violations in
                ViolationSummary(exerciseName: performance.exerciseName, message: message, count: violations.count)
            }
        }
        .sorted { $0.count > $1.count }
    }

    private var mostFlaggedExercise: ExercisePerformance? {
        sortedPerformances.max { $0.violations.count < $1.violations.count }
    }

    var body: some View {
        List {
            Section("Exercises Completed") {
                if sortedPerformances.isEmpty {
                    Text("No exercises were completed this session.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(sortedPerformances) { performance in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(performance.exerciseName).font(.headline)
                            Text("\(performance.repCount) reps completed")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("Range of motion: \(Int(performance.romAchieved))°")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if let symmetry = performance.symmetryScore {
                                Text("Left/right balance: \(Int(symmetry * 100))%")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            Section {
                if groupedViolations.isEmpty {
                    Text("No form corrections needed. Great job!")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(groupedViolations) { summary in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(summary.exerciseName)
                                .font(.subheadline.weight(.medium))
                            Text("\(summary.message) — flagged \(summary.count) time\(summary.count == 1 ? "" : "s")")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } header: {
                Text("Form Corrections")
            } footer: {
                Text("Range of motion is how far you moved during the exercise. Left/right balance compares how evenly both sides moved (100% = perfectly even).")
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

            extra()
        }
    }
}
