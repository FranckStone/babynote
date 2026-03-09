import CoreData
import Foundation

@objc(FetalMovementRecord)
final class FetalMovementRecord: NSManagedObject, Identifiable {
    @NSManaged var recordedAt: Date
    @NSManaged var durationMinutesValue: NSNumber?
    @NSManaged var movementCountValue: NSNumber?
    @NSManaged var note: String

    var durationMinutes: Int? {
        get { durationMinutesValue?.intValue }
        set { durationMinutesValue = newValue.map(NSNumber.init(value:)) }
    }

    var movementCount: Int? {
        get { movementCountValue?.intValue }
        set { movementCountValue = newValue.map(NSNumber.init(value:)) }
    }

    convenience init(
        context: NSManagedObjectContext,
        recordedAt: Date,
        durationMinutes: Int? = nil,
        movementCount: Int? = nil,
        note: String = ""
    ) {
        self.init(context: context)
        self.recordedAt = recordedAt
        self.durationMinutes = durationMinutes
        self.movementCount = movementCount
        self.note = note
    }
}

extension FetalMovementRecord {
    @nonobjc class func fetchRequest() -> NSFetchRequest<FetalMovementRecord> {
        NSFetchRequest<FetalMovementRecord>(entityName: "FetalMovementRecord")
    }
}
