import CoreData
import SwiftUI

private struct FeedingStatsItem: Identifiable {
    let record: FeedingRecord
    let previousStartedAt: Date?

    var id: ObjectIdentifier {
        ObjectIdentifier(record)
    }
}

private struct FeedingDayGroup: Identifiable {
    let day: Date
    let items: [FeedingStatsItem]

    var id: Date { day }
}

private struct FeedingStatsData {
    let dailyGroups: [FeedingDayGroup]
    let totalCount: Int
    let totalFormulaAmount: Double

    var averagePerDay: Double? {
        guard !dailyGroups.isEmpty else { return nil }
        return Double(totalCount) / Double(dailyGroups.count)
    }
}

struct FeedingStatsView: View {
    @FetchRequest(sortDescriptors: [SortDescriptor(\FeedingRecord.startedAt, order: .forward)]) private var fetchedRecords: FetchedResults<FeedingRecord>

    var body: some View {
        let stats = makeStats()

        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if stats.dailyGroups.isEmpty {
                    emptyState
                } else {
                    LazyVStack(spacing: 10) {
                        ForEach(stats.dailyGroups) { group in
                            dailyCard(day: group.day, items: group.items)
                        }
                    }
                }

                summaryCard(stats)
            }
            .padding(20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("喂奶统计")
    }

    private func makeStats() -> FeedingStatsData {
        let calendar = Calendar.current
        var items: [FeedingStatsItem] = []
        items.reserveCapacity(fetchedRecords.count)
        var previousStartedAt: Date?
        var totalFormulaAmount: Double = 0

        for record in fetchedRecords {
            items.append(FeedingStatsItem(record: record, previousStartedAt: previousStartedAt))
            previousStartedAt = record.startedAt
            totalFormulaAmount += record.amountMLValue ?? 0
        }

        let grouped = Dictionary(grouping: items) { calendar.startOfDay(for: $0.record.startedAt) }
        let dailyGroups = grouped
            .map { FeedingDayGroup(day: $0.key, items: $0.value) }
            .sorted { $0.day > $1.day }

        return FeedingStatsData(
            dailyGroups: dailyGroups,
            totalCount: items.count,
            totalFormulaAmount: totalFormulaAmount
        )
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "drop.fill")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("暂无喂奶数据")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
    }

    private func summaryCard(_ stats: FeedingStatsData) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("统计摘要")
                .font(.headline)
            Text("天数：\(stats.dailyGroups.count)")
                .font(.subheadline)
            Text("喂奶总次数：\(stats.totalCount)")
                .font(.subheadline)
            if stats.totalFormulaAmount > 0 {
                Text("奶粉总量：\(formatAmount(stats.totalFormulaAmount))")
                    .font(.subheadline)
            }
            if let averagePerDay = stats.averagePerDay {
                Text("日均喂奶：\(String(format: "%.1f", averagePerDay)) 次")
                    .font(.subheadline)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func dailyCard(day: Date, items: [FeedingStatsItem]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(DateDisplay.shortDate(day))
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(items.count) 次")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 0) {
                ForEach(items) { item in
                    feedingRow(item)

                    if item.id != items.last?.id {
                        Divider()
                            .padding(.leading, 44)
                    }
                }
            }
        }
        .padding(14)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func feedingRow(_ item: FeedingStatsItem) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 2) {
                Text(DateDisplay.clockTime(item.record.startedAt))
                    .font(.subheadline.monospacedDigit().weight(.semibold))
                Text(DateDisplay.dayPeriod(item.record.startedAt))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 44, alignment: .leading)

            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline) {
                    Text(item.record.feedingType.displayName)
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text(feedingAmountText(item.record))
                        .font(.subheadline.monospacedDigit().weight(.semibold))
                        .foregroundStyle(.pink)
                }

                HStack(spacing: 8) {
                    Label(intervalText(previousStartedAt: item.previousStartedAt, currentStartedAt: item.record.startedAt), systemImage: "clock")
                    if item.record.feedingType == .mixed, let breastDurationMinutes = item.record.breastDurationMinutes {
                        Label("母乳 \(breastDurationMinutes) 分钟", systemImage: "timer")
                    }
                    if item.record.feedingType == .mixed, let formulaDurationMinutes = item.record.formulaDurationMinutes {
                        Label("奶粉 \(formulaDurationMinutes) 分钟", systemImage: "timer")
                    } else if let durationMinutes = item.record.durationMinutes {
                        Label("\(durationMinutes) 分钟", systemImage: "timer")
                    }
                }
                .font(.footnote)
                .foregroundStyle(.secondary)

                if !item.record.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(item.record.note)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
        }
        .padding(.vertical, 10)
    }

    private func feedingAmountText(_ record: FeedingRecord) -> String {
        if let amountML = record.amountMLValue {
            return formatAmount(amountML)
        }

        if let durationMinutes = record.durationMinutes {
            return "\(durationMinutes) 分钟"
        }

        return "未填写"
    }

    private func formatAmount(_ amountML: Double) -> String {
        if amountML.rounded() == amountML {
            return "\(Int(amountML)) ml"
        }

        return "\(String(format: "%.1f", amountML)) ml"
    }

    private func intervalText(previousStartedAt: Date?, currentStartedAt: Date) -> String {
        guard let previousStartedAt else {
            return "首次记录"
        }

        let minutes = max(Int(currentStartedAt.timeIntervalSince(previousStartedAt) / 60), 0)
        let hours = minutes / 60
        let remainingMinutes = minutes % 60

        if hours > 0, remainingMinutes > 0 {
            return "间隔 \(hours)小时\(remainingMinutes)分钟"
        }
        if hours > 0 {
            return "间隔 \(hours)小时"
        }
        return "间隔 \(remainingMinutes)分钟"
    }
}
