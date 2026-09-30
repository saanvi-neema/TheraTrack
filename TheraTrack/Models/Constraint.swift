import Foundation
import SwiftData

@Model
final class Constraint {
    var exerciseName: String?
    var text: String
    var order: Int

    init(exerciseName: String?, text: String, order: Int) {
        self.exerciseName = exerciseName
        self.text = text
        self.order = order
    }
}
