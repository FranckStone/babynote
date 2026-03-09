import CoreData
import SwiftUI

struct ContentView: View {
    @Environment(\.managedObjectContext) private var managedObjectContext
    @FetchRequest(sortDescriptors: [SortDescriptor(\FeedingRecord.startedAt, order: .reverse)]) private var feedings: FetchedResults<FeedingRecord>
    @FetchRequest(sortDescriptors: [SortDescriptor(\WeightRecord.recordedAt, order: .reverse)]) private var weights: FetchedResults<WeightRecord>
    @FetchRequest(sortDescriptors: [SortDescriptor(\MedicationRecord.recordedAt, order: .reverse)]) private var medications: FetchedResults<MedicationRecord>
    @FetchRequest(sortDescriptors: [SortDescriptor(\CheckupRecord.recordedAt, order: .reverse)]) private var checkups: FetchedResults<CheckupRecord>
    @FetchRequest(sortDescriptors: [SortDescriptor(\FetalMovementRecord.recordedAt, order: .reverse)]) private var fetalMovements: FetchedResults<FetalMovementRecord>
    @FetchRequest(sortDescriptors: [SortDescriptor(\BloodGlucoseRecord.recordedAt, order: .reverse)]) private var bloodGlucoses: FetchedResults<BloodGlucoseRecord>
    @State private var hasTriggeredSeed = false

    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("首页", systemImage: "house.fill")
                }

            TimelineView()
                .tabItem {
                    Label("时间线", systemImage: "list.bullet.rectangle.portrait")
                }

            QuickLogView()
                .tabItem {
                    Label("快速记录", systemImage: "plus.circle.fill")
                }

            StatsView()
                .tabItem {
                    Label("统计", systemImage: "chart.line.uptrend.xyaxis")
                }
        }
        .task {
            guard !hasTriggeredSeed else { return }
            hasTriggeredSeed = true
            SampleDataSeeder.seedIfNeeded(
                context: managedObjectContext,
                feedings: Array(feedings),
                weights: Array(weights),
                medications: Array(medications),
                checkups: Array(checkups),
                fetalMovements: Array(fetalMovements),
                bloodGlucoses: Array(bloodGlucoses)
            )
        }
    }
}
