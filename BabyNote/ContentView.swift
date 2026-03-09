import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FeedingRecord.startedAt, order: .reverse) private var feedings: [FeedingRecord]
    @Query(sort: \WeightRecord.recordedAt, order: .reverse) private var weights: [WeightRecord]
    @Query(sort: \MedicationRecord.recordedAt, order: .reverse) private var medications: [MedicationRecord]
    @Query(sort: \CheckupRecord.recordedAt, order: .reverse) private var checkups: [CheckupRecord]

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
            SampleDataSeeder.seedIfNeeded(
                modelContext: modelContext,
                feedings: feedings,
                weights: weights,
                medications: medications,
                checkups: checkups
            )
        }
    }
}
