import Foundation
import SwiftData

@Model
final class MedicationRecord {
    var recordedAt: Date
    var name: String
    var dosage: String
    var note: String

    init(recordedAt: Date, name: String, dosage: String, note: String = "") {
        self.recordedAt = recordedAt
        self.name = name
        self.dosage = dosage
        self.note = note
    }
}
