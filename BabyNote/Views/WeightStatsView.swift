import Charts
import SwiftUI

private struct DailyWeightPoint: Identifiable {
    let day: Date
    let jin: Double

    var id: TimeInterval { day.timeIntervalSince1970 }
}

struct WeightStatsView: View {
    let records: [WeightRecord]
    @State private var selectedDays: Set<Date> = []

    private let maxSelectedDays = 14

    private var calendar: Calendar { .current }

    private var availableDaysSorted: [Date] {
        let unique = Set(records.map { calendar.startOfDay(for: $0.recordedAt) })
        return unique.sorted(by: <)
    }

    private var selectedDaysAsc: [Date] {
        availableDaysSorted
            .filter { selectedDays.contains($0) }
            .sorted(by: <)
    }

    private var latestRecordByDay: [Date: WeightRecord] {
        var map: [Date: WeightRecord] = [:]
        for record in records.sorted(by: { $0.recordedAt > $1.recordedAt }) {
            let day = calendar.startOfDay(for: record.recordedAt)
            if map[day] == nil {
                map[day] = record
            }
        }
        return map
    }

    private var points: [DailyWeightPoint] {
        selectedDaysAsc.compactMap { day in
            guard let record = latestRecordByDay[day] else { return nil }
            return DailyWeightPoint(day: day, jin: WeightDisplay.kgToJin(record.weightKG))
        }
    }

    private var latestValue: Double? {
        points.last?.jin
    }

    private var earliestValue: Double? {
        points.first?.jin
    }

    private var changeValue: Double? {
        guard let latestValue, let earliestValue else { return nil }
        return latestValue - earliestValue
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                daySelector

                if points.isEmpty {
                    emptyState(text: "请选择日期查看体重趋势")
                } else {
                    Chart(points) { point in
                        LineMark(
                            x: .value("日期", point.day, unit: .day),
                            y: .value("体重", point.jin)
                        )
                        .foregroundStyle(Color.orange)
                        .interpolationMethod(.catmullRom)

                        PointMark(
                            x: .value("日期", point.day, unit: .day),
                            y: .value("体重", point.jin)
                        )
                        .foregroundStyle(Color.orange)
                        .annotation(position: .top) {
                            Text(String(format: "%.1f", point.jin))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(height: 300)
                    .chartYAxisLabel("斤")
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
                    if let latestValue {
                        Text("最新体重：\(String(format: "%.1f", latestValue)) 斤")
                            .font(.subheadline)
                    }
                    if let earliestValue {
                        Text("起始体重：\(String(format: "%.1f", earliestValue)) 斤")
                            .font(.subheadline)
                    }
                    if let changeValue {
                        Text("变化：\(changeValue >= 0 ? "+" : "")\(String(format: "%.1f", changeValue)) 斤")
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
        .navigationTitle("体重统计")
        .onAppear {
            if selectedDays.isEmpty {
                selectedDays = Set(availableDaysSorted.suffix(maxSelectedDays))
            }
        }
    }

    private var daySelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("选择日期（最多 14 天）")
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
            Image(systemName: "chart.line.uptrend.xyaxis")
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
