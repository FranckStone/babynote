import CoreData
import Foundation

enum ExcretionType: String, CaseIterable, Identifiable {
    case poop
    case pee

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .poop: "拉屎"
        case .pee: "撒尿"
        }
    }
}

@objc(ExcretionRecord)
final class ExcretionRecord: NSManagedObject, Identifiable {
    @NSManaged var recordedAt: Date
    @NSManaged var typeRawValue: String
    @NSManaged var note: String

    var type: ExcretionType {
        get { ExcretionType(rawValue: typeRawValue) ?? .poop }
        set { typeRawValue = newValue.rawValue }
    }

    convenience init(
        context: NSManagedObjectContext,
        recordedAt: Date,
        type: ExcretionType,
        note: String = ""
    ) {
        self.init(context: context)
        self.recordedAt = recordedAt
        self.typeRawValue = type.rawValue
        self.note = note
    }
}

extension ExcretionRecord {
    @nonobjc class func fetchRequest() -> NSFetchRequest<ExcretionRecord> {
        NSFetchRequest<ExcretionRecord>(entityName: "ExcretionRecord")
    }
}
