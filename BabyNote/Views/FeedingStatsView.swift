import Charts
import SwiftUI

private struct DailyFeedingPoint: Identifiable {
    let day: Date
    let count: Int

    var id: TimeInterval { day.timeIntervalSince1970 }
}

struct FeedingStatsView: View {
    let records: [FeedingRecord]
    @State private var selectedDays: Set<Date> = []

    private let maxSelectedDays = 7

    private var calendar: Calendar { .current }

    private var availableDaysSorted: [Date] {
        let unique = Set(records.map { calendar.startOfDay(for: $0.startedAt) })
        return unique.sorted(by: <)
    }

    private var selectedDaysAsc: [Date] {
        availableDaysSorted
            .filter { selectedDays.contains($0) }
            .sorted(by: <)
    }

    private var points: [DailyFeedingPoint] {
        let grouped = Dictionary(grouping: records) { calendar.startOfDay(for: $0.startedAt) }
        return selectedDaysAsc.map { day in
            DailyFeedingPoint(day: day, count: grouped[day]?.count ?? 0)
        }
    }

    private var selectedRecordCount: Int {
        points.reduce(0) { $0 + $1.count }
    }

    private var averagePerDay: Double? {
        guard !points.isEmpty else { return nil }
        return Double(selectedRecordCount) / Double(points.count)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                daySelector

                if points.isEmpty {
                    emptyState(text: "请选择日期查看喂奶图表")
                } else {
                    Chart(points) { point in
                        BarMark(
                            x: .value("日期", point.day, unit: .day),
                            y: .value("次数", point.count)
                        )
                        .foregroundStyle(Color.pink)
                        .annotation(position: .top) {
                            Text("\(point.count) 次")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(height: 300)
                    .chartYAxisLabel("次")
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .day)) {
                            AxisGridLine()
                            AxisTick()
                            AxisValueLabel(format: .dateTime.month().day())
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("统计摘要")
                        .font(.headline)
                    Text("选中天数：\(selectedDaysAsc.count) / \(maxSelectedDays)")
                        .font(.subheadline)
                    Text("喂奶总次数：\(selectedRecordCount)")
                        .font(.subheadline)
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
            .padding(20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("喂奶统计")
        .onAppear {
            if selectedDays.isEmpty {
                selectedDays = Set(availableDaysSorted.suffix(maxSelectedDays))
            }
        }
    }

    private var daySelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("选择日期（最多 7 天）")
                .font(.headline)

            if availableDaysSorted.isEmpty {
                Text("暂无可选日期")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(availableDaysSorted, id: \.self) { day in
                            let isSelected = selectedDays.contains(day)

                            Button {
                                toggleDaySelection(day)
                            } label: {
                                Text(shortDate(day))
                                    .font(.subheadline.weight(.medium))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(isSelected ? Color.accentColor : Color(.secondarySystemBackground))
                                    .foregroundStyle(isSelected ? .white : .primary)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private func toggleDaySelection(_ day: Date) {
        if selectedDays.contains(day) {
            selectedDays.remove(day)
            return
        }

        guard selectedDays.count < maxSelectedDays else { return }
        selectedDays.insert(day)
    }

    private func shortDate(_ day: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日"
        return formatter.string(from: day)
    }

    private func emptyState(text: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.bar")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
    }
}
