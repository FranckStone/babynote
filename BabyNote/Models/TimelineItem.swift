import Foundation

struct TimelineItem: Identifiable {
    let id: String
    let recordedAt: Date
    let type: RecordType
    let title: String
    let detail: String
    let note: String

    static func build(
        feedings: [FeedingRecord],
        weights: [WeightRecord],
        medications: [MedicationRecord],
        checkups: [CheckupRecord]
    ) -> [TimelineItem] {
        let feedingItems = feedings.map {
            TimelineItem(
                id: "feeding-\($0.persistentModelID)",
                recordedAt: $0.startedAt,
                type: .feeding,
                title: $0.feedingType.displayName,
                detail: feedingDetail(for: $0),
                note: $0.note
            )
        }

        let weightItems = weights.map {
            TimelineItem(
                id: "weight-\($0.persistentModelID)",
                recordedAt: $0.recordedAt,
                type: .weight,
                title: "体重记录",
                detail: String(format: "%.1f kg", $0.weightKG),
                note: $0.note
            )
        }

        let medicationItems = medications.map {
            TimelineItem(
                id: "medication-\($0.persistentModelID)",
                recordedAt: $0.recordedAt,
                type: .medication,
                title: $0.name,
                detail: $0.dosage,
                note: $0.note
            )
        }

        let checkupItems = checkups.map {
            TimelineItem(
                id: "checkup-\($0.persistentModelID)",
                recordedAt: $0.recordedAt,
                type: .checkup,
                title: $0.location,
                detail: $0.summary,
                note: $0.note
            )
        }

        return (feedingItems + weightItems + medicationItems + checkupItems)
            .sorted { $0.recordedAt > $1.recordedAt }
    }

    private static func feedingDetail(for record: FeedingRecord) -> String {
        var parts: [String] = []
        if let amountML = record.amountML {
            parts.append("\(Int(amountML)) ml")
        }
        if let durationMinutes = record.durationMinutes {
            parts.append("\(durationMinutes) 分钟")
        }
        return parts.isEmpty ? "未填写时长或奶量" : parts.joined(separator: " · ")
    }
}
