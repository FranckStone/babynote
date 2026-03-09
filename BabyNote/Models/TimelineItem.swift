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
    let id: String
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
        let feedingItems = feedings.map {
            TimelineItem(
                id: "feeding-\($0.objectID.uriRepresentation().absoluteString)",
                recordedAt: $0.startedAt,
                type: .feeding,
                title: $0.feedingType.displayName,
                detail: feedingDetail(for: $0),
                note: $0.note,
                record: .feeding($0)
            )
        }

        let weightItems = weights.map {
            TimelineItem(
                id: "weight-\($0.objectID.uriRepresentation().absoluteString)",
                recordedAt: $0.recordedAt,
                type: .weight,
                title: "体重记录",
                detail: WeightDisplay.jinText(fromKG: $0.weightKG),
                note: $0.note,
                record: .weight($0)
            )
        }

        let medicationItems = medications.map {
            TimelineItem(
                id: "medication-\($0.objectID.uriRepresentation().absoluteString)",
                recordedAt: $0.recordedAt,
                type: .medication,
                title: $0.name,
                detail: $0.dosage,
                note: $0.note,
                record: .medication($0)
            )
        }

        let checkupItems = checkups.map {
            TimelineItem(
                id: "checkup-\($0.objectID.uriRepresentation().absoluteString)",
                recordedAt: $0.recordedAt,
                type: .checkup,
                title: $0.location,
                detail: $0.summary,
                note: $0.note,
                record: .checkup($0)
            )
        }

        let fetalMovementItems = fetalMovements.map {
            TimelineItem(
                id: "fetalMovement-\($0.objectID.uriRepresentation().absoluteString)",
                recordedAt: $0.recordedAt,
                type: .fetalMovement,
                title: "胎动记录",
                detail: fetalMovementDetail(for: $0),
                note: $0.note,
                record: .fetalMovement($0)
            )
        }

        let bloodGlucoseItems = bloodGlucoses.map {
            TimelineItem(
                id: "bloodGlucose-\($0.objectID.uriRepresentation().absoluteString)",
                recordedAt: $0.recordedAt,
                type: .bloodGlucose,
                title: "血糖监测",
                detail: bloodGlucoseDetail(for: $0),
                note: $0.note,
                record: .bloodGlucose($0)
            )
        }

        return (feedingItems + weightItems + medicationItems + checkupItems + fetalMovementItems + bloodGlucoseItems)
            .sorted { $0.recordedAt > $1.recordedAt }
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
