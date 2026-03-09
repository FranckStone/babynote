import Foundation
import SwiftData

@Model
final class CheckupRecord {
    var recordedAt: Date
    var location: String
    var summary: String
    var attachmentPath: String
    var note: String

    init(
        recordedAt: Date,
        location: String,
        summary: String,
        attachmentPath: String = "",
        note: String = ""
    ) {
        self.recordedAt = recordedAt
        self.location = location
        self.summary = summary
        self.attachmentPath = attachmentPath
        self.note = note
    }
}
