import CoreData
import SwiftUI

private struct ExcretionDayGroup: Identifiable {
    let day: Date
    let records: [ExcretionRecord]
    let poopCount: Int
    let peeCount: Int

    var id: Date { day }
}

private struct ExcretionStatsData {
    let dailyGroups: [ExcretionDayGroup]
    let totalPoopCount: Int
    let totalPeeCount: Int

    var totalCount: Int { totalPoopCount + totalPeeCount }

    var averagePerDay: Double? {
        guard !dailyGroups.isEmpty else { return nil }
        return Double(totalCount) / Double(dailyGroups.count)
    }
}

struct ExcretionStatsView: View {
    @FetchRequest(sortDescriptors: [SortDescriptor(\ExcretionRecord.recordedAt, order: .forward)]) private var fetchedRecords: FetchedResults<ExcretionRecord>

    var body: some View {
        let stats = makeStats()

        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if stats.dailyGroups.isEmpty {
                    emptyState
                } else {
                    LazyVStack(spacing: 10) {
                        ForEach(stats.dailyGroups) { group in
                            dailyCard(group)
                        }
                    }
                }

                summaryCard(stats)
            }
            .padding(20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("屎尿统计")
    }

    private func makeStats() -> ExcretionStatsData {
        let calendar = Calendar.current
        var totalPoopCount = 0
        var totalPeeCount = 0

        for record in fetchedRecords {
            if record.type == .poop {
                totalPoopCount += 1
            } else {
                totalPeeCount += 1
            }
        }

        let grouped = Dictionary(grouping: fetchedRecords) { calendar.startOfDay(for: $0.recordedAt) }
        let dailyGroups = grouped
            .map { day, records in
                ExcretionDayGroup(
                    day: day,
                    records: records,
                    poopCount: records.count(where: { $0.type == .poop }),
                    peeCount: records.count(where: { $0.type == .pee })
                )
            }
            .sorted { $0.day > $1.day }

        return ExcretionStatsData(
            dailyGroups: dailyGroups,
            totalPoopCount: totalPoopCount,
            totalPeeCount: totalPeeCount
        )
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "toilet.fill")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("暂无屎尿数据")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
    }

    private func summaryCard(_ stats: ExcretionStatsData) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("统计摘要")
                .font(.headline)
            Text("天数：\(stats.dailyGroups.count)")
                .font(.subheadline)
            Text("总次数：\(stats.totalCount)")
                .font(.subheadline)
            Text("拉屎：\(stats.totalPoopCount) 次")
                .font(.subheadline)
            Text("撒尿：\(stats.totalPeeCount) 次")
                .font(.subheadline)
            if let averagePerDay = stats.averagePerDay {
                Text("日均：\(String(format: "%.1f", averagePerDay)) 次")
                    .font(.subheadline)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func dailyCard(_ group: ExcretionDayGroup) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(DateDisplay.shortDate(group.day))
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(dayCountText(group))
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 0) {
                ForEach(group.records) { record in
                    excretionRow(record)

                    if record !== group.records.last {
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

    private func dayCountText(_ group: ExcretionDayGroup) -> String {
        var parts: [String] = []
        if group.poopCount > 0 {
            parts.append("拉屎 \(group.poopCount)")
        }
        if group.peeCount > 0 {
            parts.append("撒尿 \(group.peeCount)")
        }
        return parts.joined(separator: " · ")
    }

    private func excretionRow(_ record: ExcretionRecord) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 2) {
                Text(DateDisplay.clockTime(record.recordedAt))
                    .font(.subheadline.monospacedDigit().weight(.semibold))
                Text(DateDisplay.dayPeriod(record.recordedAt))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 44, alignment: .leading)

            VStack(alignment: .leading, spacing: 5) {
                Text(record.type.displayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(record.type == .poop ? .brown : .blue)

                if !record.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(record.note)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 10)
    }
}
