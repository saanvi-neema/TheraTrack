import Foundation
import SwiftData

@Model
final class Workout {
    var name: String
    var createdAt: Date

    @Relationship(deleteRule: .cascade)
    var exercises: [Exercise] = []

    init(name: String, createdAt: Date = .now) {
        self.name = name
        self.createdAt = createdAt
    }
}
