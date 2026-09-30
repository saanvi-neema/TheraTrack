import Foundation
import SwiftData

@Model
final class ExercisePerformance {
    var exerciseName: String
    var repCount: Int
    var romAchieved: Double
    var symmetryScore: Double?
    var order: Int

    @Relationship(deleteRule: .cascade)
    var violations: [FormViolation] = []

    init(exerciseName: String, repCount: Int, romAchieved: Double, symmetryScore: Double?, order: Int) {
        self.exerciseName = exerciseName
        self.repCount = repCount
        self.romAchieved = romAchieved
        self.symmetryScore = symmetryScore
        self.order = order
    }
}
