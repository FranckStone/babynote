import CoreData
import SwiftUI

@main
struct BabyNoteApp: App {
    private let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}

final class PersistenceController {
    static let shared = PersistenceController()

    private static let defaultBundleIdentifier = "com.frank.babynote"

    let container: NSPersistentContainer

    private init(inMemory: Bool = false) {
        let model = Self.makeManagedObjectModel()
        container = NSPersistentContainer(name: "BabyNote", managedObjectModel: model)

        let storeDescription = container.persistentStoreDescriptions.first
        if inMemory {
            storeDescription?.url = URL(fileURLWithPath: "/dev/null")
        }

        storeDescription?.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        storeDescription?.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)

        container.loadPersistentStores { _, error in
            if let error {
                fatalError("Failed to load persistent stores: \(error)")
            }
        }

        container.viewContext.transactionAuthor = Self.defaultBundleIdentifier
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    private static func makeManagedObjectModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()

        let feeding = NSEntityDescription()
        feeding.name = "FeedingRecord"
        feeding.managedObjectClassName = NSStringFromClass(FeedingRecord.self)
        feeding.properties = [
            attribute(name: "startedAt", type: .dateAttributeType),
            attribute(name: "endedAt", type: .dateAttributeType, isOptional: true),
            attribute(name: "feedingTypeRawValue", type: .stringAttributeType, defaultValue: FeedingType.leftBreast.rawValue),
            attribute(name: "amountML", type: .doubleAttributeType, isOptional: true),
            attribute(name: "note", type: .stringAttributeType, defaultValue: "")
        ]

        let weight = NSEntityDescription()
        weight.name = "WeightRecord"
        weight.managedObjectClassName = NSStringFromClass(WeightRecord.self)
        weight.properties = [
            attribute(name: "recordedAt", type: .dateAttributeType),
            attribute(name: "weightKG", type: .doubleAttributeType),
            attribute(name: "note", type: .stringAttributeType, defaultValue: "")
        ]

        let medication = NSEntityDescription()
        medication.name = "MedicationRecord"
        medication.managedObjectClassName = NSStringFromClass(MedicationRecord.self)
        medication.properties = [
            attribute(name: "recordedAt", type: .dateAttributeType),
            attribute(name: "name", type: .stringAttributeType, defaultValue: ""),
            attribute(name: "dosage", type: .stringAttributeType, defaultValue: ""),
            attribute(name: "note", type: .stringAttributeType, defaultValue: "")
        ]

        let checkup = NSEntityDescription()
        checkup.name = "CheckupRecord"
        checkup.managedObjectClassName = NSStringFromClass(CheckupRecord.self)
        checkup.properties = [
            attribute(name: "recordedAt", type: .dateAttributeType),
            attribute(name: "location", type: .stringAttributeType, defaultValue: ""),
            attribute(name: "summary", type: .stringAttributeType, defaultValue: ""),
            attribute(name: "attachmentPath", type: .stringAttributeType, defaultValue: ""),
            attribute(name: "note", type: .stringAttributeType, defaultValue: "")
        ]

        let fetalMovement = NSEntityDescription()
        fetalMovement.name = "FetalMovementRecord"
        fetalMovement.managedObjectClassName = NSStringFromClass(FetalMovementRecord.self)
        fetalMovement.properties = [
            attribute(name: "recordedAt", type: .dateAttributeType),
            attribute(name: "durationMinutesValue", type: .integer64AttributeType, isOptional: true),
            attribute(name: "movementCountValue", type: .integer64AttributeType, isOptional: true),
            attribute(name: "note", type: .stringAttributeType, defaultValue: "")
        ]

        let bloodGlucose = NSEntityDescription()
        bloodGlucose.name = "BloodGlucoseRecord"
        bloodGlucose.managedObjectClassName = NSStringFromClass(BloodGlucoseRecord.self)
        bloodGlucose.properties = [
            attribute(name: "recordedAt", type: .dateAttributeType),
            attribute(name: "momentRawValue", type: .stringAttributeType, defaultValue: BloodGlucoseMoment.beforeBreakfast.rawValue),
            attribute(name: "valueMMOL", type: .doubleAttributeType),
            attribute(name: "note", type: .stringAttributeType, defaultValue: "")
        ]

        model.entities = [feeding, weight, medication, checkup, fetalMovement, bloodGlucose]
        return model
    }

    private static func attribute(
        name: String,
        type: NSAttributeType,
        isOptional: Bool = false,
        defaultValue: Any? = nil
    ) -> NSAttributeDescription {
        let attribute = NSAttributeDescription()
        attribute.name = name
        attribute.attributeType = type
        attribute.isOptional = isOptional
        attribute.defaultValue = defaultValue
        return attribute
    }
}
