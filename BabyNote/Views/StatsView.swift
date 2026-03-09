import SwiftData
import SwiftUI

struct StatsView: View {
    @Query(sort: \FeedingRecord.startedAt, order: .reverse) private var feedings: [FeedingRecord]
    @Query(sort: \WeightRecord.recordedAt, order: .reverse) private var weights: [WeightRecord]
    @Query(sort: \MedicationRecord.recordedAt, order: .reverse) private var medications: [MedicationRecord]
    @Query(sort: \FetalMovementRecord.recordedAt, order: .reverse) private var fetalMovements: [FetalMovementRecord]

    private var averageFeedingIntervalHours: Double? {
        guard feedings.count >= 2 else { return nil }
        let ordered = feedings.sorted { $0.startedAt < $1.startedAt }
        let intervals = zip(ordered, ordered.dropFirst()).map {
            $1.startedAt.timeIntervalSince($0.startedAt) / 3600
        }
        guard !intervals.isEmpty else { return nil }
        return intervals.reduce(0, +) / Double(intervals.count)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    SummaryCard(
                        title: "喂奶记录总数",
                        value: "\(feedings.count)",
                        subtitle: averageFeedingIntervalHours.map { String(format: "平均间隔 %.1f 小时", $0) } ?? "至少需要两条喂奶记录",
                        tint: .pink
                    )

                    SummaryCard(
                        title: "体重记录总数",
                        value: "\(weights.count)",
                        subtitle: weights.last.map { String(format: "最早 %.1f kg", $0.weightKG) } ?? "还没有记录",
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
