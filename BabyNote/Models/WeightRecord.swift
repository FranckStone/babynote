import CoreData
import Foundation

@objc(WeightRecord)
final class WeightRecord: NSManagedObject, Identifiable {
    @NSManaged var recordedAt: Date
    @NSManaged var weightKG: Double
    @NSManaged var note: String

    convenience init(context: NSManagedObjectContext, recordedAt: Date, weightKG: Double, note: String = "") {
        self.init(context: context)
        self.recordedAt = recordedAt
        self.weightKG = weightKG
        self.note = note
    }
}

extension WeightRecord {
    @nonobjc class func fetchRequest() -> NSFetchRequest<WeightRecord> {
        NSFetchRequest<WeightRecord>(entityName: "WeightRecord")
    }
}
