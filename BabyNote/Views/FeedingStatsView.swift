import CoreData
import SwiftUI

private struct FeedingStatsItem: Identifiable {
    let record: FeedingRecord
    let previousStartedAt: Date?

    var id: ObjectIdentifier {
        ObjectIdentifier(record)
    }
}

struct FeedingStatsView: View {
    @FetchRequest(sortDescriptors: [SortDescriptor(\FeedingRecord.startedAt, order: .reverse)]) private var fetchedRecords: FetchedResults<FeedingRecord>

    private var calendar: Calendar { .current }

    private var records: [FeedingRecord] {
        Array(fetchedRecords)
    }

    private var sortedRecords: [FeedingRecord] {
        records.sorted { $0.startedAt < $1.startedAt }
    }

    private var dailyItems: [(day: Date, items: [FeedingStatsItem])] {
        var items: [FeedingStatsItem] = []

        for index in sortedRecords.indices {
            let previous = index > sortedRecords.startIndex ? sortedRecords[sortedRecords.index(before: index)] : nil
            items.append(FeedingStatsItem(record: sortedRecords[index], previousStartedAt: previous?.startedAt))
        }

        let grouped = Dictionary(grouping: items) { calendar.startOfDay(for: $0.record.startedAt) }
        return grouped
            .map { day, items in
                (day: day, items: items.sorted { $0.record.startedAt < $1.record.startedAt })
            }
            .sorted { $0.day > $1.day }
    }

    private var averagePerDay: Double? {
        guard !dailyItems.isEmpty else { return nil }
        return Double(records.count) / Double(dailyItems.count)
    }

    private var totalFormulaAmount: Double {
        records.reduce(0) { $0 + ($1.amountMLValue ?? 0) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if dailyItems.isEmpty {
                    emptyState
                } else {
                    VStack(spacing: 10) {
                        ForEach(dailyItems, id: \.day) { group in
                            dailyCard(day: group.day, items: group.items)
                        }
                    }
                }

                summaryCard
            }
            .padding(20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("喂奶统计")
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

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("统计摘要")
                .font(.headline)
            Text("天数：\(dailyItems.count)")
                .font(.subheadline)
            Text("喂奶总次数：\(records.count)")
                .font(.subheadline)
            if totalFormulaAmount > 0 {
                Text("奶粉总量：\(formatAmount(totalFormulaAmount))")
                    .font(.subheadline)
            }
            if let averagePerDay {
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
                Text(shortDate(day))
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
                Text(shortTime(item.record.startedAt))
                    .font(.subheadline.monospacedDigit().weight(.semibold))
                Text(timePeriod(item.record.startedAt))
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

    private func shortDate(_ day: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日"
        return formatter.string(from: day)
    }

    private func shortTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private func timePeriod(_ date: Date) -> String {
        let hour = calendar.component(.hour, from: date)
        switch hour {
        case 7..<12:
            return "上午"
        case 12..<19:
            return "下午"
        default:
            return "晚上"
        }
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
