import CoreData
import Foundation

enum BloodGlucoseMoment: String, CaseIterable, Identifiable {
    case beforeBreakfast
    case afterBreakfast
    case beforeLunch
    case afterLunch
    case beforeDinner
    case afterDinner
    case beforeSleep

    var id: String { rawValue }

    var chartOrder: Int {
        switch self {
        case .beforeBreakfast: 0
        case .afterBreakfast: 1
        case .beforeLunch: 2
        case .afterLunch: 3
        case .beforeDinner: 4
        case .afterDinner: 5
        case .beforeSleep: 6
        }
    }

    var chartPositionKey: String {
        // Charts in grouped BarMark can render larger category keys first within each day.
        // Use reverse rank to keep the visual order as breakfast -> ... -> sleep.
        let reverseRank = BloodGlucoseMoment.allCases.count - chartOrder
        return String(format: "%02d_%@", reverseRank, displayName)
    }

    var displayName: String {
        switch self {
        case .beforeBreakfast: "早餐前"
        case .afterBreakfast: "早餐后"
        case .beforeLunch: "午餐前"
        case .afterLunch: "午餐后"
        case .beforeDinner: "晚餐前"
        case .afterDinner: "晚餐后"
        case .beforeSleep: "睡前"
        }
    }
}

@objc(BloodGlucoseRecord)
final class BloodGlucoseRecord: NSManagedObject, Identifiable {
    @NSManaged var recordedAt: Date
    @NSManaged var momentRawValue: String
    @NSManaged var valueMMOL: Double
    @NSManaged var note: String

    var moment: BloodGlucoseMoment {
        get { BloodGlucoseMoment(rawValue: momentRawValue) ?? .beforeBreakfast }
        set { momentRawValue = newValue.rawValue }
    }

    convenience init(
        context: NSManagedObjectContext,
        recordedAt: Date,
        moment: BloodGlucoseMoment,
        valueMMOL: Double,
        note: String = ""
    ) {
        self.init(context: context)
        self.recordedAt = recordedAt
        self.momentRawValue = moment.rawValue
        self.valueMMOL = valueMMOL
        self.note = note
    }
}

extension BloodGlucoseRecord {
    @nonobjc class func fetchRequest() -> NSFetchRequest<BloodGlucoseRecord> {
        NSFetchRequest<BloodGlucoseRecord>(entityName: "BloodGlucoseRecord")
    }
}
