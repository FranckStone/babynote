import CoreData
import Foundation

@objc(CheckupRecord)
final class CheckupRecord: NSManagedObject, Identifiable {
    @NSManaged var recordedAt: Date
    @NSManaged var location: String
    @NSManaged var summary: String
    @NSManaged var attachmentPath: String
    @NSManaged var note: String

    convenience init(
        context: NSManagedObjectContext,
        recordedAt: Date,
        location: String,
        summary: String,
        attachmentPath: String = "",
        note: String = ""
    ) {
        self.init(context: context)
        self.recordedAt = recordedAt
        self.location = location
        self.summary = summary
        self.attachmentPath = attachmentPath
        self.note = note
    }
}

extension CheckupRecord {
    @nonobjc class func fetchRequest() -> NSFetchRequest<CheckupRecord> {
        NSFetchRequest<CheckupRecord>(entityName: "CheckupRecord")
    }
}
