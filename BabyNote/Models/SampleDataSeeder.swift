import CoreData
import Foundation

enum SampleDataSeeder {
    static func seedIfNeeded(
        context: NSManagedObjectContext,
        feedings: [FeedingRecord],
        weights: [WeightRecord],
        medications: [MedicationRecord],
        checkups: [CheckupRecord],
        fetalMovements: [FetalMovementRecord],
        bloodGlucoses: [BloodGlucoseRecord]
    ) {
        guard feedings.isEmpty, weights.isEmpty, medications.isEmpty, checkups.isEmpty, fetalMovements.isEmpty, bloodGlucoses.isEmpty else {
            return
        }

        let now = Date()

        _ = FeedingRecord(
            context: context,
            startedAt: Calendar.current.date(byAdding: .hour, value: -2, to: now) ?? now,
            endedAt: Calendar.current.date(byAdding: .minute, value: -95, to: now),
            feedingType: .leftBreast,
            amountML: nil,
            note: "夜里比较顺利"
        )

        _ = WeightRecord(
            context: context,
            recordedAt: Calendar.current.date(byAdding: .day, value: -1, to: now) ?? now,
            weightKG: 63.4,
            note: "早餐前记录"
        )

        _ = MedicationRecord(
            context: context,
            recordedAt: Calendar.current.date(byAdding: .hour, value: -8, to: now) ?? now,
            name: "产检补铁",
            dosage: "1 片",
            note: "饭后服用"
        )

        _ = CheckupRecord(
            context: context,
            recordedAt: Calendar.current.date(byAdding: .day, value: -5, to: now) ?? now,
            location: "市妇幼",
            summary: "常规产检正常",
            attachmentPath: "",
            note: "下次两周后复查"
        )

        _ = FetalMovementRecord(
            context: context,
            recordedAt: Calendar.current.date(byAdding: .hour, value: -4, to: now) ?? now,
            durationMinutes: 12,
            movementCount: 8,
            note: "晚上比较明显"
        )

        _ = BloodGlucoseRecord(
            context: context,
            recordedAt: Calendar.current.date(byAdding: .hour, value: -1, to: now) ?? now,
            moment: .beforeSleep,
            valueMMOL: 5.6,
            note: ""
        )

        try? context.save()
    }
}
