import Foundation
import SwiftData

@Model
final class WorkoutSession {
    var workoutName: String
    var startedAt: Date
    var completedAt: Date

    @Relationship(deleteRule: .cascade)
    var exercisePerformances: [ExercisePerformance] = []

    init(workoutName: String, startedAt: Date, completedAt: Date) {
        self.workoutName = workoutName
        self.startedAt = startedAt
        self.completedAt = completedAt
    }
}
