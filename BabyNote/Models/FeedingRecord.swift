import CoreData
import Foundation

enum FeedingType: String, Codable, CaseIterable, Identifiable {
    case formula
    case mixed

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .formula: "奶粉"
        case .mixed: "混合"
        }
    }
}

@objc(FeedingRecord)
final class FeedingRecord: NSManagedObject, Identifiable {
    @NSManaged var startedAt: Date
    @NSManaged var endedAt: Date?
    @NSManaged var formulaStartedAt: Date?
    @NSManaged var feedingTypeRawValue: String
    @NSManaged var amountML: NSNumber?
    @NSManaged var note: String

    var feedingType: FeedingType {
        get {
            if feedingTypeRawValue == "bottle" {
                return .formula
            }
            if feedingTypeRawValue == "leftBreast" || feedingTypeRawValue == "rightBreast" {
                return .mixed
            }
            return FeedingType(rawValue: feedingTypeRawValue) ?? .formula
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

    var breastDurationMinutes: Int? {
        guard feedingType == .mixed, let formulaStartedAt else { return nil }
        return max(Int(formulaStartedAt.timeIntervalSince(startedAt) / 60), 0)
    }

    var formulaDurationMinutes: Int? {
        guard let endedAt else { return nil }
        let formulaStart = feedingType == .mixed ? (formulaStartedAt ?? startedAt) : startedAt
        return max(Int(endedAt.timeIntervalSince(formulaStart) / 60), 0)
    }

    convenience init(
        context: NSManagedObjectContext,
        startedAt: Date,
        endedAt: Date? = nil,
        formulaStartedAt: Date? = nil,
        feedingType: FeedingType,
        amountML: Double? = nil,
        note: String = ""
    ) {
        self.init(context: context)
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.formulaStartedAt = formulaStartedAt
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
