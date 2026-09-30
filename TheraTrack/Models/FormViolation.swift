import Foundation
import SwiftData

@Model
final class FormViolation {
    var message: String
    var timestamp: Date
    var order: Int

    init(message: String, timestamp: Date, order: Int) {
        self.message = message
        self.timestamp = timestamp
        self.order = order
    }
}
