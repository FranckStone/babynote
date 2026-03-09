import SwiftData
import SwiftUI

@main
struct BabyNoteApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            FeedingRecord.self,
            WeightRecord.self,
            MedicationRecord.self,
            CheckupRecord.self,
            FetalMovementRecord.self,
        ])

        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
