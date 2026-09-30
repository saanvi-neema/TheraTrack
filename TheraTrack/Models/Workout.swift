import Foundation
import SwiftData

@Model
final class Workout {
    var name: String
    var createdAt: Date

    @Relationship(deleteRule: .cascade)
    var exercises: [Exercise] = []

    var specialInstructions: String?
    var documentData: Data?
    var documentFileName: String?

    @Relationship(deleteRule: .cascade)
    var constraints: [Constraint] = []

    init(name: String, createdAt: Date = .now) {
        self.name = name
        self.createdAt = createdAt
    }
}
