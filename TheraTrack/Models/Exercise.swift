import Foundation
import SwiftData

@Model
final class Exercise {
    var name: String
    var order: Int

    init(name: String, order: Int) {
        self.name = name
        self.order = order
    }
}
