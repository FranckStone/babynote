import Foundation
import SwiftData

@Model
final class FetalMovementRecord {
    var recordedAt: Date
    var durationMinutes: Int?
    var movementCount: Int?
    var note: String

    init(recordedAt: Date, durationMinutes: Int? = nil, movementCount: Int? = nil, note: String = "") {
        self.recordedAt = recordedAt
        self.durationMinutes = durationMinutes
        self.movementCount = movementCount
        self.note = note
    }
}
