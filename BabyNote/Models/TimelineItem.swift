import CoreData
import Foundation

enum TimelineRecord {
    case feeding(FeedingRecord)
    case weight(WeightRecord)
    case medication(MedicationRecord)
    case checkup(CheckupRecord)
    case fetalMovement(FetalMovementRecord)
    case bloodGlucose(BloodGlucoseRecord)
}

struct TimelineItem: Identifiable {
    let id: NSManagedObjectID
    let recordedAt: Date
    let type: RecordType
    let title: String
    let detail: String
    let note: String
    let record: TimelineRecord

    static func build(
        feedings: [FeedingRecord],
        weights: [WeightRecord],
        medications: [MedicationRecord],
        checkups: [CheckupRecord],
        fetalMovements: [FetalMovementRecord],
        bloodGlucoses: [BloodGlucoseRecord]
    ) -> [TimelineItem] {
        (feedings.map(makeItem) +
         weights.map(makeItem) +
         medications.map(makeItem) +
         checkups.map(makeItem) +
         fetalMovements.map(makeItem) +
         bloodGlucoses.map(makeItem))
            .sorted { $0.recordedAt > $1.recordedAt }
    }

    static func buildRecent(
        limit: Int,
        feedings: [FeedingRecord],
        weights: [WeightRecord],
        medications: [MedicationRecord],
        checkups: [CheckupRecord],
        fetalMovements: [FetalMovementRecord],
        bloodGlucoses: [BloodGlucoseRecord]
    ) -> [TimelineItem] {
        guard limit > 0 else { return [] }

        let groups: [[TimelineRecord]] = [
            feedings.map(TimelineRecord.feeding),
            weights.map(TimelineRecord.weight),
            medications.map(TimelineRecord.medication),
            checkups.map(TimelineRecord.checkup),
            fetalMovements.map(TimelineRecord.fetalMovement),
            bloodGlucoses.map(TimelineRecord.bloodGlucose)
        ]

        var indices = Array(repeating: 0, count: groups.count)
        var recentItems: [TimelineItem] = []
        recentItems.reserveCapacity(limit)

        while recentItems.count < limit {
            var nextGroupIndex: Int?
            var nextDate = Date.distantPast

            for groupIndex in groups.indices {
                let group = groups[groupIndex]
                let itemIndex = indices[groupIndex]
                guard itemIndex < group.count else { continue }

                let candidateDate = recordedAt(for: group[itemIndex])
                if nextGroupIndex == nil || candidateDate > nextDate {
                    nextGroupIndex = groupIndex
                    nextDate = candidateDate
                }
            }

            guard let nextGroupIndex else { break }
            recentItems.append(makeItem(from: groups[nextGroupIndex][indices[nextGroupIndex]]))
            indices[nextGroupIndex] += 1
        }

        return recentItems
    }

    private static func makeItem(_ record: FeedingRecord) -> TimelineItem {
        TimelineItem(
            id: record.objectID,
            recordedAt: record.startedAt,
            type: .feeding,
            title: record.feedingType.displayName,
            detail: feedingDetail(for: record),
            note: record.note,
            record: .feeding(record)
        )
    }

    private static func makeItem(_ record: WeightRecord) -> TimelineItem {
        TimelineItem(
            id: record.objectID,
            recordedAt: record.recordedAt,
            type: .weight,
            title: "体重记录",
            detail: WeightDisplay.jinText(fromKG: record.weightKG),
            note: record.note,
            record: .weight(record)
        )
    }

    private static func makeItem(_ record: MedicationRecord) -> TimelineItem {
        TimelineItem(
            id: record.objectID,
            recordedAt: record.recordedAt,
            type: .medication,
            title: record.name,
            detail: record.dosage,
            note: record.note,
            record: .medication(record)
        )
    }

    private static func makeItem(_ record: CheckupRecord) -> TimelineItem {
        TimelineItem(
            id: record.objectID,
            recordedAt: record.recordedAt,
            type: .checkup,
            title: record.location,
            detail: record.summary,
            note: record.note,
            record: .checkup(record)
        )
    }

    private static func makeItem(_ record: FetalMovementRecord) -> TimelineItem {
        TimelineItem(
            id: record.objectID,
            recordedAt: record.recordedAt,
            type: .fetalMovement,
            title: "胎动记录",
            detail: fetalMovementDetail(for: record),
            note: record.note,
            record: .fetalMovement(record)
        )
    }

    private static func makeItem(_ record: BloodGlucoseRecord) -> TimelineItem {
        TimelineItem(
            id: record.objectID,
            recordedAt: record.recordedAt,
            type: .bloodGlucose,
            title: "血糖监测",
            detail: bloodGlucoseDetail(for: record),
            note: record.note,
            record: .bloodGlucose(record)
        )
    }

    private static func makeItem(from record: TimelineRecord) -> TimelineItem {
        switch record {
        case .feeding(let record):
            makeItem(record)
        case .weight(let record):
            makeItem(record)
        case .medication(let record):
            makeItem(record)
        case .checkup(let record):
            makeItem(record)
        case .fetalMovement(let record):
            makeItem(record)
        case .bloodGlucose(let record):
            makeItem(record)
        }
    }

    private static func recordedAt(for record: TimelineRecord) -> Date {
        switch record {
        case .feeding(let record):
            record.startedAt
        case .weight(let record):
            record.recordedAt
        case .medication(let record):
            record.recordedAt
        case .checkup(let record):
            record.recordedAt
        case .fetalMovement(let record):
            record.recordedAt
        case .bloodGlucose(let record):
            record.recordedAt
        }
    }

    private static func feedingDetail(for record: FeedingRecord) -> String {
        var parts: [String] = []
        if let amountML = record.amountMLValue {
            parts.append("\(Int(amountML)) ml")
        }
        if let durationMinutes = record.durationMinutes {
            parts.append("\(durationMinutes) 分钟")
        }
        return parts.isEmpty ? "未填写时长或奶量" : parts.joined(separator: " · ")
    }

    private static func fetalMovementDetail(for record: FetalMovementRecord) -> String {
        var parts: [String] = []
        if let movementCount = record.movementCount {
            parts.append("\(movementCount) 次")
        }
        if let durationMinutes = record.durationMinutes {
            parts.append("\(durationMinutes) 分钟")
        }
        return parts.isEmpty ? "未填写次数或时长" : parts.joined(separator: " · ")
    }

    private static func bloodGlucoseDetail(for record: BloodGlucoseRecord) -> String {
        "\(record.moment.displayName) · \(String(format: "%.1f", record.valueMMOL)) mmol/L"
    }
}
