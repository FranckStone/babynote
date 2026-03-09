import CoreData
import Foundation

@objc(MedicationRecord)
final class MedicationRecord: NSManagedObject, Identifiable {
    @NSManaged var recordedAt: Date
    @NSManaged var name: String
    @NSManaged var dosage: String
    @NSManaged var note: String

    convenience init(context: NSManagedObjectContext, recordedAt: Date, name: String, dosage: String, note: String = "") {
        self.init(context: context)
        self.recordedAt = recordedAt
        self.name = name
        self.dosage = dosage
        self.note = note
    }
}

extension MedicationRecord {
    @nonobjc class func fetchRequest() -> NSFetchRequest<MedicationRecord> {
        NSFetchRequest<MedicationRecord>(entityName: "MedicationRecord")
    }
}
