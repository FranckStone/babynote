import CoreData
import SwiftUI

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.managedObjectContext) private var managedObjectContext
    @AppStorage("inactivityDimDelaySeconds") private var inactivityDimDelaySeconds = InactivityDimDelay.fiveMinutes.rawValue
    @AppStorage("inactivityDimBrightnessPercent") private var inactivityDimBrightnessPercent = 35
    @AppStorage("feedingOverdueAlarmEnabled") private var feedingOverdueAlarmEnabled = false
    @AppStorage("feedingOverdueDelayMinutes") private var feedingOverdueDelayMinutes = 180
    @FetchRequest(sortDescriptors: [SortDescriptor(\FeedingRecord.startedAt, order: .reverse)]) private var feedings: FetchedResults<FeedingRecord>
    @FetchRequest(sortDescriptors: [SortDescriptor(\WeightRecord.recordedAt, order: .reverse)]) private var weights: FetchedResults<WeightRecord>
    @FetchRequest(sortDescriptors: [SortDescriptor(\MedicationRecord.recordedAt, order: .reverse)]) private var medications: FetchedResults<MedicationRecord>
    @FetchRequest(sortDescriptors: [SortDescriptor(\CheckupRecord.recordedAt, order: .reverse)]) private var checkups: FetchedResults<CheckupRecord>
    @FetchRequest(sortDescriptors: [SortDescriptor(\FetalMovementRecord.recordedAt, order: .reverse)]) private var fetalMovements: FetchedResults<FetalMovementRecord>
    @FetchRequest(sortDescriptors: [SortDescriptor(\BloodGlucoseRecord.recordedAt, order: .reverse)]) private var bloodGlucoses: FetchedResults<BloodGlucoseRecord>
    @FetchRequest(sortDescriptors: [SortDescriptor(\ExcretionRecord.recordedAt, order: .reverse)]) private var excretions: FetchedResults<ExcretionRecord>
    @StateObject private var brightnessController = InactivityBrightnessController()
    @StateObject private var feedingAlarmController = FeedingAlarmController()
    @State private var hasTriggeredSeed = false

    private var feedingReminderSignature: String {
        feedings.map { record in
            let completedAt = record.endedAt ?? record.startedAt
            return "\(record.objectID.uriRepresentation().absoluteString)-\(record.startedAt.timeIntervalSinceReferenceDate)-\(completedAt.timeIntervalSinceReferenceDate)"
        }
        .joined(separator: "|")
    }

    private var latestFeedingReminderDate: Date? {
        feedings.first.map { $0.endedAt ?? $0.startedAt }
    }

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

            SettingsView()
                .tabItem {
                    Label("设置", systemImage: "gearshape.fill")
                }
        }
        .environmentObject(feedingAlarmController)
        .background {
            UserInteractionMonitorView {
                brightnessController.registerInteraction()
                feedingAlarmController.stopAlarmAfterUserInteraction()
            }
        }
        .overlay {
            if feedingAlarmController.isAlarmActive {
                feedingAlarmFullScreen
            }
        }
        .onAppear {
            updateScreenBehavior()
        }
        .onChange(of: scenePhase) { _ in
            updateScreenBehavior()
        }
        .onChange(of: inactivityDimDelaySeconds) { _ in
            updateScreenBehavior()
        }
        .onChange(of: inactivityDimBrightnessPercent) { _ in
            updateScreenBehavior()
        }
        .onAppear {
            updateFeedingReminder()
        }
        .onChange(of: feedingOverdueAlarmEnabled) { _ in
            updateFeedingReminder()
        }
        .onChange(of: feedingOverdueDelayMinutes) { _ in
            updateFeedingReminder()
        }
        .onChange(of: feedingReminderSignature) { _ in
            updateFeedingReminder()
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
                bloodGlucoses: Array(bloodGlucoses),
                excretions: Array(excretions)
            )
        }
    }

    private func updateScreenBehavior() {
        brightnessController.configure(
            delaySeconds: inactivityDimDelaySeconds,
            dimBrightnessPercent: inactivityDimBrightnessPercent,
            scenePhaseIsActive: scenePhase == .active
        )
    }

    private func updateFeedingReminder() {
        feedingAlarmController.update(
            enabled: feedingOverdueAlarmEnabled,
            delayMinutes: feedingOverdueDelayMinutes,
            latestFeedingDate: latestFeedingReminderDate
        )
    }

    private var feedingAlarmFullScreen: some View {
        ZStack {
            LinearGradient(
                colors: [Color.pink, Color.red.opacity(0.88)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: 22) {
                Image(systemName: "bell.and.waves.left.and.right.fill")
                    .font(.system(size: 74, weight: .semibold))
                    .foregroundStyle(.white)

                VStack(spacing: 10) {
                    Text(feedingAlarmController.alarmTitle)
                        .font(.largeTitle.bold())
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)

                    Text(feedingAlarmController.alarmMessage)
                        .font(.title3.weight(.medium))
                        .foregroundStyle(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                }

                Text("触摸屏幕任意位置即可停止")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.86))
                    .padding(.top, 8)
            }
            .padding(28)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            feedingAlarmController.stopAlarmAfterUserInteraction()
        }
        .ignoresSafeArea()
        .zIndex(100)
    }
}
