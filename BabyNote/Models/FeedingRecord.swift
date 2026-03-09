import CoreData
import Foundation

enum FeedingType: String, Codable, CaseIterable, Identifiable {
    case leftBreast
    case rightBreast
    case formula

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .leftBreast: "左侧母乳"
        case .rightBreast: "右侧母乳"
        case .formula: "奶粉"
        }
    }
}

@objc(FeedingRecord)
final class FeedingRecord: NSManagedObject, Identifiable {
    @NSManaged var startedAt: Date
    @NSManaged var endedAt: Date?
    @NSManaged var feedingTypeRawValue: String
    @NSManaged var amountML: NSNumber?
    @NSManaged var note: String

    var feedingType: FeedingType {
        get {
            if feedingTypeRawValue == "bottle" {
                return .formula
            }
            return FeedingType(rawValue: feedingTypeRawValue) ?? .leftBreast
        }
        set { feedingTypeRawValue = newValue.rawValue }
    }

    var amountMLValue: Double? {
        get { amountML?.doubleValue }
        set { amountML = newValue.map(NSNumber.init(value:)) }
    }

    var durationMinutes: Int? {
        guard let endedAt else { return nil }
        return max(Int(endedAt.timeIntervalSince(startedAt) / 60), 0)
    }

    convenience init(
        context: NSManagedObjectContext,
        startedAt: Date,
        endedAt: Date? = nil,
        feedingType: FeedingType,
        amountML: Double? = nil,
        note: String = ""
    ) {
        self.init(context: context)
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.feedingTypeRawValue = feedingType.rawValue
        self.amountMLValue = amountML
        self.note = note
    }
}

extension FeedingRecord {
    @nonobjc class func fetchRequest() -> NSFetchRequest<FeedingRecord> {
        NSFetchRequest<FeedingRecord>(entityName: "FeedingRecord")
    }
}
