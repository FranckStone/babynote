import CoreData
import Foundation

@objc(MedicationRecord)
final class MedicationRecord: NSManagedObject, Identifiable {
    @NSManaged var recordedAt: Date
    @NSManaged var name: String
    @NSManaged var dosage: String
    @NSManaged var note: String

    convenience init(context: NSManagedObjectContext, recordedAt: Date, name: String, dosage: String, note: String = "") {
        self.init(context: context)
        self.recordedAt = recordedAt
        self.name = name
        self.dosage = dosage
        self.note = note
    }
}

extension MedicationRecord {
    @nonobjc class func fetchRequest() -> NSFetchRequest<MedicationRecord> {
        NSFetchRequest<MedicationRecord>(entityName: "MedicationRecord")
    }
}

struct MedicationPreset: Identifiable, Equatable {
    let id: String
    let name: String
    let dosageValue: Double
    let dosageUnit: String
    let detail: String

    var dosageText: String {
        MedicationDose(amount: dosageValue, unit: dosageUnit).displayText
    }

    static let pregnancyCommon: [MedicationPreset] = [
        MedicationPreset(
            id: "prenatal-vitamin",
            name: "孕妇复合维生素",
            dosageValue: 1,
            dosageUnit: "片",
            detail: "常见日常补充"
        ),
        MedicationPreset(
            id: "folic-acid",
            name: "叶酸",
            dosageValue: 1,
            dosageUnit: "片",
            detail: "孕早期常见"
        ),
        MedicationPreset(
            id: "iron",
            name: "铁剂",
            dosageValue: 1,
            dosageUnit: "片",
            detail: "贫血或缺铁时常见"
        ),
        MedicationPreset(
            id: "calcium",
            name: "钙剂",
            dosageValue: 1,
            dosageUnit: "片",
            detail: "常与维生素 D 搭配"
        ),
        MedicationPreset(
            id: "vitamin-d",
            name: "维生素 D",
            dosageValue: 1,
            dosageUnit: "粒",
            detail: "孕期常见补充"
        )
    ]
}

struct MedicationDose: Equatable {
    let amount: Double
    let unit: String

    var displayText: String {
        let amountText: String
        if abs(amount.rounded() - amount) < 0.001 {
            amountText = String(format: "%.0f", amount)
        } else {
            amountText = String(format: "%.1f", amount)
        }
        return "\(amountText) \(unit)"
    }

    static func parse(_ rawValue: String) -> MedicationDose? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let pattern = #"([0-9]+(?:\.[0-9]+)?)\s*(.*)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)
        guard let match = regex.firstMatch(in: trimmed, range: range),
              let amountRange = Range(match.range(at: 1), in: trimmed),
              let amount = Double(trimmed[amountRange]) else {
            return nil
        }

        var unit = ""
        if let unitRange = Range(match.range(at: 2), in: trimmed) {
            unit = String(trimmed[unitRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if unit.isEmpty {
            unit = "片"
        }
        return MedicationDose(amount: amount, unit: unit)
    }
}
