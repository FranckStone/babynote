import Charts
import CoreData
import SwiftUI

private struct DailyMomentPoint: Identifiable {
    let day: Date
    let moment: BloodGlucoseMoment
    let value: Double
    let recordedAt: Date?

    var id: String {
        "\(day.timeIntervalSince1970)-\(moment.rawValue)"
    }
}

struct BloodGlucoseStatsView: View {
    @FetchRequest(sortDescriptors: [SortDescriptor(\BloodGlucoseRecord.recordedAt, order: .reverse)]) private var fetchedRecords: FetchedResults<BloodGlucoseRecord>
    @State private var isComparisonEnabled = false

    private var calendar: Calendar { .current }

    private var records: [BloodGlucoseRecord] {
        Array(fetchedRecords)
    }

    private var sortedRecords: [BloodGlucoseRecord] {
        records.sorted { $0.recordedAt < $1.recordedAt }
    }

    private var availableDaysSorted: [Date] {
        let unique = Set(records.map { calendar.startOfDay(for: $0.recordedAt) })
        return unique.sorted(by: <)
    }

    private var displayedDaysDesc: [Date] {
        availableDaysSorted.sorted(by: >)
    }

    private var displayedRecords: [BloodGlucoseRecord] {
        sortedRecords
    }

    private var averageValue: Double? {
        guard !displayedRecords.isEmpty else { return nil }
        let sum = displayedRecords.reduce(0.0) { $0 + $1.valueMMOL }
        return sum / Double(displayedRecords.count)
    }

    private var lookup: [String: BloodGlucoseRecord] {
        var map: [String: BloodGlucoseRecord] = [:]
        for record in displayedRecords.sorted(by: { $0.recordedAt > $1.recordedAt }) {
            let key = lookupKey(day: calendar.startOfDay(for: record.recordedAt), moment: record.moment)
            if map[key] == nil {
                map[key] = record
            }
        }
        return map
    }

    private var chartPoints: [DailyMomentPoint] {
        var points: [DailyMomentPoint] = []
        for day in displayedDaysDesc {
            for moment in BloodGlucoseMoment.allCases {
                let key = lookupKey(day: day, moment: moment)
                let record = lookup[key]
                points.append(
                    DailyMomentPoint(
                        day: day,
                        moment: moment,
                        value: record?.valueMMOL ?? 0,
                        recordedAt: record?.recordedAt
                    )
                )
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
            VStack(alignment: .leading, spacing: 12) {
                if chartPoints.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "waveform.path.ecg")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                        Text("暂无血糖数据")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 36)
                } else {
                    VStack(spacing: 10) {
                        ForEach(displayedDaysDesc, id: \.self) { day in
                            dailyCard(for: day)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("统计摘要")
                        .font(.headline)
                    Text("天数：\(displayedDaysDesc.count)")
                        .font(.subheadline)
                    Text("记录总数：\(displayedRecords.count)")
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

    private func shortTime(_ date: Date?) -> String {
        guard let date else { return "--:--" }
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
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

    private func points(for day: Date) -> [DailyMomentPoint] {
        chartPoints.filter { calendar.isDate($0.day, inSameDayAs: day) }
    }

    private func axisTimeLabel(for momentLabel: String, in points: [DailyMomentPoint]) -> String {
        let point = points.first { $0.moment.displayName == momentLabel }
        return shortTime(point?.recordedAt)
    }

    @ViewBuilder
    private func dailyCard(for day: Date) -> some View {
        let dayPoints = points(for: day)

        VStack(alignment: .leading, spacing: 8) {
            GeometryReader { proxy in
                let contentWidth = proxy.size.width * 0.5

                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(shortDate(day))
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Text("平均 \(String(format: "%.1f", dayAverage(for: dayPoints)))")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                    .frame(width: contentWidth, alignment: .leading)

                    Chart(dayPoints) { point in
                        let exceedAmount = chartExceedAmount(for: point)
                        BarMark(
                            x: .value("时段", point.moment.displayName),
                            y: .value("血糖", point.value),
                            width: .fixed(20)
                        )
                        .foregroundStyle(exceedAmount == nil ? Color.accentColor : Color.red)
                        .annotation(position: .top, alignment: .center) {
                            Text(String(format: "%.1f", point.value))
                                .font(.caption2)
                                .foregroundStyle(exceedAmount == nil ? Color.secondary : Color.red)
                        }
                    }
                    .frame(width: contentWidth, height: 136)
                    .chartYAxisLabel("mmol/L")
                    .chartXScale(domain: BloodGlucoseMoment.allCases.map(\.displayName))
                    .chartXAxis {
                        AxisMarks(values: BloodGlucoseMoment.allCases.map(\.displayName)) { value in
                            AxisGridLine()
                            AxisTick()
                            AxisValueLabel(centered: true) {
                                if let label = value.as(String.self) {
                                    VStack(spacing: 2) {
                                        Text(label)
                                            .font(.caption2)
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.8)
                                        Text(axisTimeLabel(for: label, in: dayPoints))
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.8)
                                    }
                                    .multilineTextAlignment(.center)
                                }
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .frame(height: 184)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func dayAverage(for points: [DailyMomentPoint]) -> Double {
        guard !points.isEmpty else { return 0 }
        let total = points.reduce(0.0) { $0 + $1.value }
        return total / Double(points.count)
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
