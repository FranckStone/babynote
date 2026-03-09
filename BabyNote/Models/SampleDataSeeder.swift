import Foundation
import SwiftData

enum SampleDataSeeder {
    static func seedIfNeeded(
        modelContext: ModelContext,
        feedings: [FeedingRecord],
        weights: [WeightRecord],
        medications: [MedicationRecord],
        checkups: [CheckupRecord]
    ) {
        guard feedings.isEmpty, weights.isEmpty, medications.isEmpty, checkups.isEmpty else {
            return
        }

        let now = Date()

        modelContext.insert(
            FeedingRecord(
                startedAt: Calendar.current.date(byAdding: .hour, value: -2, to: now) ?? now,
                endedAt: Calendar.current.date(byAdding: .minute, value: -95, to: now),
                feedingType: .leftBreast,
                amountML: nil,
                note: "夜里比较顺利"
            )
        )

        modelContext.insert(
            WeightRecord(
                recordedAt: Calendar.current.date(byAdding: .day, value: -1, to: now) ?? now,
                weightKG: 63.4,
                note: "早餐前记录"
            )
        )

        modelContext.insert(
            MedicationRecord(
                recordedAt: Calendar.current.date(byAdding: .hour, value: -8, to: now) ?? now,
                name: "产检补铁",
                dosage: "1 片",
                note: "饭后服用"
            )
        )

        modelContext.insert(
            CheckupRecord(
                recordedAt: Calendar.current.date(byAdding: .day, value: -5, to: now) ?? now,
                location: "市妇幼",
                summary: "常规产检正常",
                attachmentPath: "",
                note: "下次两周后复查"
            )
        )

        try? modelContext.save()
    }
}
