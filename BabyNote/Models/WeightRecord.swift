import Foundation
import SwiftData

@Model
final class WeightRecord {
    var recordedAt: Date
    var weightKG: Double
    var note: String

    init(recordedAt: Date, weightKG: Double, note: String = "") {
        self.recordedAt = recordedAt
        self.weightKG = weightKG
        self.note = note
    }
}
