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
    @State private var isComparisonEnabled = false

    private let maxSelectedDays = 5

    private var calendar: Calendar { .current }

    private var sortedRecords: [BloodGlucoseRecord] {
        records.sorted { $0.recordedAt < $1.recordedAt }
    }

    private var availableDaysSorted: [Date] {
        let unique = Set(records.map { calendar.startOfDay(for: $0.recordedAt) })
        return unique.sorted(by: <)
    }

    private var selectedDaysAsc: [Date] {
        availableDaysSorted
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

    private var diagnosisExceededEntries: [DailyMomentPoint] {
        chartPoints.filter { point in
            guard let upperLimit = diagnosisUpperLimit(for: point.moment) else { return false }
            return point.value >= upperLimit
        }
    }

    private var dailyControlExceededEntries: [DailyMomentPoint] {
        chartPoints.filter { point in
            guard let upperLimit = dailyControlUpperLimit(for: point.moment) else { return false }
            return point.value > upperLimit
        }
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
                            let exceedAmount = chartExceedAmount(for: point)
                            BarMark(
                                x: .value("日期", point.day, unit: .day),
                                y: .value("血糖", point.value)
                            )
                            .position(by: .value("时段", point.moment.displayName))
                            .foregroundStyle(exceedAmount == nil ? Color.accentColor : Color.red)
                            .annotation(position: .top, alignment: .center) {
                                VStack(spacing: 1) {
                                    Text(point.moment.displayName)
                                        .font(.caption2)
                                    Text(String(format: "%.1f", point.value))
                                        .font(.caption2.weight(.semibold))
                                    if let exceedAmount {
                                        Text("超出 \(String(format: "%.1f", exceedAmount))")
                                            .font(.caption2.weight(.semibold))
                                            .foregroundStyle(.red)
                                    }
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

                    Text("参考范围（仅参考，请以医生建议为准）")
                        .font(.subheadline.weight(.medium))
                    Text("1) 妊娠期糖尿病诊断阈值（75g OGTT）：空腹 < 5.1，1小时 < 10.0，2小时 < 8.5 mmol/L")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text("2) 日常控糖目标：餐前/睡前 ≤ 5.3，餐后1小时 ≤ 7.8（若测餐后2小时，建议 ≤ 6.7）mmol/L")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Toggle("对比当前展示数据并标出超标项", isOn: $isComparisonEnabled)
                        .font(.subheadline)
                    if isComparisonEnabled {
                        Text("图中标红按“日常控糖目标”判断，附加显示超出值。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    if isComparisonEnabled {
                        comparisonSection(
                            title: "按诊断阈值（空腹/餐后1小时可比）",
                            points: diagnosisExceededEntries,
                            limitResolver: diagnosisUpperLimit(for:)
                        )
                        comparisonSection(
                            title: "按日常控糖目标",
                            points: dailyControlExceededEntries,
                            limitResolver: dailyControlUpperLimit(for:)
                        )
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
        .navigationTitle("血糖统计")
        .onAppear {
            if selectedDays.isEmpty {
                selectedDays = Set(availableDaysSorted.suffix(maxSelectedDays))
            }
        }
    }

    private var daySelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("选择日期（最多 5 天）")
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

    private func diagnosisUpperLimit(for moment: BloodGlucoseMoment) -> Double? {
        switch moment {
        case .beforeBreakfast:
            return 5.1
        case .afterBreakfast, .afterLunch, .afterDinner:
            return 10.0
        case .beforeLunch, .beforeDinner, .beforeSleep:
            return nil
        }
    }

    private func dailyControlUpperLimit(for moment: BloodGlucoseMoment) -> Double? {
        switch moment {
        case .beforeBreakfast, .beforeLunch, .beforeDinner, .beforeSleep:
            return 5.3
        case .afterBreakfast, .afterLunch, .afterDinner:
            return 7.8
        }
    }

    private func chartExceedAmount(for point: DailyMomentPoint) -> Double? {
        guard isComparisonEnabled, let upperLimit = dailyControlUpperLimit(for: point.moment) else { return nil }
        let exceedAmount = point.value - upperLimit
        return exceedAmount > 0 ? exceedAmount : nil
    }

    @ViewBuilder
    private func comparisonSection(
        title: String,
        points: [DailyMomentPoint],
        limitResolver: @escaping (BloodGlucoseMoment) -> Double?
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)

            if points.isEmpty {
                Text("当前展示数据未发现超标")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(points) { point in
                    if let upperLimit = limitResolver(point.moment) {
                        Text("\(shortDate(point.day)) \(point.moment.displayName)：\(String(format: "%.1f", point.value))（阈值 \(String(format: "%.1f", upperLimit))）")
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
            }
        }
    }
}
