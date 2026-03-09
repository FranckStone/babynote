import CoreData
import SwiftUI

struct StatsView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @FetchRequest(sortDescriptors: [SortDescriptor(\FeedingRecord.startedAt, order: .reverse)]) private var feedings: FetchedResults<FeedingRecord>
    @FetchRequest(sortDescriptors: [SortDescriptor(\WeightRecord.recordedAt, order: .reverse)]) private var weights: FetchedResults<WeightRecord>
    @FetchRequest(sortDescriptors: [SortDescriptor(\MedicationRecord.recordedAt, order: .reverse)]) private var medications: FetchedResults<MedicationRecord>
    @FetchRequest(sortDescriptors: [SortDescriptor(\FetalMovementRecord.recordedAt, order: .reverse)]) private var fetalMovements: FetchedResults<FetalMovementRecord>
    @FetchRequest(sortDescriptors: [SortDescriptor(\BloodGlucoseRecord.recordedAt, order: .reverse)]) private var bloodGlucoses: FetchedResults<BloodGlucoseRecord>

    private var averageFeedingIntervalHours: Double? {
        guard feedings.count >= 2 else { return nil }

        var totalHours: Double = 0
        var intervalCount = 0

        for index in 0..<(feedings.count - 1) {
            let newer = feedings[index]
            let older = feedings[index + 1]
            totalHours += newer.startedAt.timeIntervalSince(older.startedAt) / 3600
            intervalCount += 1
        }

        guard intervalCount > 0 else { return nil }
        return totalHours / Double(intervalCount)
    }

    private var statsColumns: [GridItem] {
        let count = horizontalSizeClass == .regular ? 2 : 1
        return Array(repeating: GridItem(.flexible(), spacing: 12), count: count)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    LazyVGrid(columns: statsColumns, spacing: 12) {
                        SummaryCard(
                            title: "喂奶记录总数",
                            value: "\(feedings.count)",
                            subtitle: averageFeedingIntervalHours.map { String(format: "平均间隔 %.1f 小时", $0) } ?? "至少需要两条喂奶记录",
                            tint: .pink
                        )

                        SummaryCard(
                            title: "体重记录总数",
                            value: "\(weights.count)",
                            subtitle: weights.last.map { "最早 \(WeightDisplay.jinText(fromKG: $0.weightKG))" } ?? "还没有记录",
                            tint: .orange
                        )

                        SummaryCard(
                            title: "药物记录总数",
                            value: "\(medications.count)",
                            subtitle: medications.first?.name ?? "还没有记录",
                            tint: .blue
                        )

                        SummaryCard(
                            title: "胎动记录总数",
                            value: "\(fetalMovements.count)",
                            subtitle: fetalMovements.first.map { latestFetalMovementSubtitle(for: $0) } ?? "还没有记录",
                            tint: .mint
                        )

                        NavigationLink {
                            BloodGlucoseStatsView(records: Array(bloodGlucoses))
                        } label: {
                            SummaryCard(
                                title: "血糖记录总数",
                                value: "\(bloodGlucoses.count)",
                                subtitle: bloodGlucoses.first.map { "\($0.moment.displayName) \(String(format: "%.1f", $0.valueMMOL)) mmol/L" } ?? "还没有记录",
                                tint: .red
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("下一步建议")
                            .font(.headline)

                        Text("第一版先保持轻量。后面可以继续加提醒、导出 PDF、图片附件和 iCloud 同步。")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(18)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
                .padding(20)
                .adaptiveContentWidth(horizontalSizeClass == .regular ? 980 : .infinity)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("统计")
        }
    }

    private func latestFetalMovementSubtitle(for record: FetalMovementRecord) -> String {
        var parts: [String] = []
        if let movementCount = record.movementCount {
            parts.append("\(movementCount) 次")
        }
        if let durationMinutes = record.durationMinutes {
            parts.append("\(durationMinutes) 分钟")
        }
        return parts.isEmpty ? "已记录" : parts.joined(separator: " · ")
    }
}
