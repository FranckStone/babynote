import Charts
import SwiftUI

private struct DailyMomentPoint: Identifiable {
    let day: Date
    let moment: BloodGlucoseMoment
    let value: Double

    var id: String {
        "\(day.timeIntervalSince1970)-\(moment.rawValue)"
    }
}

struct BloodGlucoseStatsView: View {
    let records: [BloodGlucoseRecord]
    @State private var selectedDays: Set<Date> = []

    private let maxSelectedDays = 5

    private var calendar: Calendar { .current }

    private var sortedRecords: [BloodGlucoseRecord] {
        records.sorted { $0.recordedAt < $1.recordedAt }
    }

    private var availableDaysDesc: [Date] {
        let unique = Set(records.map { calendar.startOfDay(for: $0.recordedAt) })
        return unique.sorted(by: >)
    }

    private var selectedDaysAsc: [Date] {
        availableDaysDesc
            .filter { selectedDays.contains($0) }
            .sorted(by: <)
    }

    private var selectedRecords: [BloodGlucoseRecord] {
        sortedRecords.filter { selectedDays.contains(calendar.startOfDay(for: $0.recordedAt)) }
    }

    private var averageValue: Double? {
        guard !selectedRecords.isEmpty else { return nil }
        let sum = selectedRecords.reduce(0.0) { $0 + $1.valueMMOL }
        return sum / Double(selectedRecords.count)
    }

    private var lookup: [String: BloodGlucoseRecord] {
        var map: [String: BloodGlucoseRecord] = [:]
        for record in selectedRecords.sorted(by: { $0.recordedAt > $1.recordedAt }) {
            let key = lookupKey(day: calendar.startOfDay(for: record.recordedAt), moment: record.moment)
            if map[key] == nil {
                map[key] = record
            }
        }
        return map
    }

    private var chartPoints: [DailyMomentPoint] {
        var points: [DailyMomentPoint] = []
        for day in selectedDaysAsc {
            for moment in BloodGlucoseMoment.allCases {
                let key = lookupKey(day: day, moment: moment)
                if let record = lookup[key] {
                    points.append(DailyMomentPoint(day: day, moment: moment, value: record.valueMMOL))
                }
            }
        }
        return points
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                daySelector

                if chartPoints.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "waveform.path.ecg")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                        Text("请选择日期查看血糖柱状图")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 36)
                } else {
                    Chart {
                        ForEach(chartPoints) { point in
                            BarMark(
                                x: .value("日期", point.day, unit: .day),
                                y: .value("血糖", point.value)
                            )
                            .position(by: .value("时段", point.moment.displayName))
                            .foregroundStyle(by: .value("日期", shortDate(point.day)))
                            .annotation(position: .top, alignment: .center) {
                                VStack(spacing: 1) {
                                    Text(point.moment.displayName)
                                        .font(.caption2)
                                    Text(String(format: "%.1f", point.value))
                                        .font(.caption2.weight(.semibold))
                                }
                                .foregroundStyle(.secondary)
                            }
                        }

                    }
                    .frame(height: 320)
                    .chartYAxisLabel("mmol/L")
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .day)) { value in
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
                    Text("记录总数：\(selectedRecords.count)")
                        .font(.subheadline)
                    if let averageValue {
                        Text("平均血糖：\(String(format: "%.2f", averageValue)) mmol/L")
                            .font(.subheadline)
                    }
                    Text("参考范围（仅参考，请以医生建议为准）：餐前/睡前 3.9–5.3 mmol/L，餐后 1 小时 < 7.8 mmol/L")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .padding(20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("血糖统计")
        .onAppear {
            if selectedDays.isEmpty {
                selectedDays = Set(availableDaysDesc.prefix(maxSelectedDays))
            }
        }
    }

    private var daySelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("选择日期（最多 5 天）")
                .font(.headline)

            if availableDaysDesc.isEmpty {
                Text("暂无可选日期")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(availableDaysDesc, id: \.self) { day in
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

    private func lookupKey(day: Date, moment: BloodGlucoseMoment) -> String {
        "\(calendar.startOfDay(for: day).timeIntervalSinceReferenceDate)-\(moment.rawValue)"
    }

    private func shortDate(_ day: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日"
        return formatter.string(from: day)
    }
}
