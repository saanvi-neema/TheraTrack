import Foundation
import SwiftData

@Model
final class Exercise {
    var name: String
    var order: Int
    var targetReps: Int = 10

    init(name: String, order: Int, targetReps: Int = 10) {
        self.name = name
        self.order = order
        self.targetReps = targetReps
    }
}
