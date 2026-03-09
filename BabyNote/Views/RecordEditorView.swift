import CoreData
import Foundation
import SwiftUI

struct RecordEditorView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var managedObjectContext

    let item: TimelineItem
    @State private var isShowingDeleteConfirmation = false
    @State private var selectedDetent: PresentationDetent = .large

    var body: some View {
        NavigationStack {
            editorContent
                .adaptiveContentWidth(horizontalSizeClass == .regular ? 760 : .infinity)
                .navigationTitle("编辑记录")
                .navigationBarTitleDisplayMode(.inline)
                .environment(\.locale, Locale(identifier: "zh_CN"))
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("完成") {
                            saveAndDismiss()
                        }
                    }

                    ToolbarItem(placement: .topBarTrailing) {
                        Button("删除", role: .destructive) {
                            isShowingDeleteConfirmation = true
                        }
                    }
                }
                .confirmationDialog("删除这条记录？", isPresented: $isShowingDeleteConfirmation, titleVisibility: .visible) {
                    Button("删除", role: .destructive) {
                        deleteRecord()
                    }
                    Button("取消", role: .cancel) {
                    }
                }
        }
        .presentationDetents(
            horizontalSizeClass == .regular ? [.large] : [.medium, .large],
            selection: $selectedDetent
        )
    }

    @ViewBuilder
    private var editorContent: some View {
        switch item.record {
        case .feeding(let record):
            FeedingRecordEditor(record: record)
        case .weight(let record):
            WeightRecordEditor(record: record)
        case .medication(let record):
            MedicationRecordEditor(record: record)
        case .checkup(let record):
            CheckupRecordEditor(record: record)
        case .fetalMovement(let record):
            FetalMovementRecordEditor(record: record)
        case .bloodGlucose(let record):
            BloodGlucoseRecordEditor(record: record)
        }
    }

    private func saveAndDismiss() {
        try? managedObjectContext.save()
        dismiss()
    }

    private func deleteRecord() {
        switch item.record {
        case .feeding(let record):
            managedObjectContext.delete(record)
        case .weight(let record):
            managedObjectContext.delete(record)
        case .medication(let record):
            managedObjectContext.delete(record)
        case .checkup(let record):
            managedObjectContext.delete(record)
        case .fetalMovement(let record):
            managedObjectContext.delete(record)
        case .bloodGlucose(let record):
            managedObjectContext.delete(record)
        }

        try? managedObjectContext.save()
        dismiss()
    }
}

private struct FeedingRecordEditor: View {
    @ObservedObject var record: FeedingRecord

    var body: some View {
        Form {
            Section("喂奶信息") {
                DatePicker("开始时间", selection: startedAtBinding)
                DatePicker(
                    "结束时间",
                    selection: endedAtBinding,
                    in: record.startedAt...
                )
                Picker("喂养方式", selection: feedingTypeBinding) {
                    ForEach(FeedingType.allCases) { type in
                        Text(type.displayName).tag(type)
                    }
                }
                TextField("奶量（ml，可选）", text: amountTextBinding)
                    .keyboardType(.decimalPad)
                TextField("备注", text: noteBinding, axis: .vertical)
                    .lineLimit(2...4)
            }
        }
    }

    private var startedAtBinding: Binding<Date> {
        Binding(
            get: { record.startedAt },
            set: { record.startedAt = $0 }
        )
    }

    private var endedAtBinding: Binding<Date> {
        Binding(
            get: { record.endedAt ?? record.startedAt },
            set: { record.endedAt = $0 }
        )
    }

    private var feedingTypeBinding: Binding<FeedingType> {
        Binding(
            get: { record.feedingType },
            set: { record.feedingType = $0 }
        )
    }

    private var noteBinding: Binding<String> {
        Binding(
            get: { record.note },
            set: { record.note = $0 }
        )
    }

    private var amountTextBinding: Binding<String> {
        Binding(
            get: {
                guard let amountML = record.amountMLValue else { return "" }
                return String(format: "%.0f", amountML)
            },
            set: { newValue in
                let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                record.amountMLValue = trimmed.isEmpty ? nil : Double(trimmed)
            }
        )
    }
}

private struct WeightRecordEditor: View {
    @ObservedObject var record: WeightRecord

    var body: some View {
        Form {
            Section("体重信息") {
                DatePicker("记录时间", selection: recordedAtBinding)
                TextField("体重（斤）", text: weightTextBinding)
                    .keyboardType(.decimalPad)
                TextField("备注", text: noteBinding, axis: .vertical)
                    .lineLimit(2...4)
            }
        }
    }

    private var recordedAtBinding: Binding<Date> {
        Binding(
            get: { record.recordedAt },
            set: { record.recordedAt = $0 }
        )
    }

    private var noteBinding: Binding<String> {
        Binding(
            get: { record.note },
            set: { record.note = $0 }
        )
    }

    private var weightTextBinding: Binding<String> {
        Binding(
            get: { String(format: "%.1f", WeightDisplay.kgToJin(record.weightKG)) },
            set: { newValue in
                let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                guard let jin = Double(trimmed) else { return }
                record.weightKG = WeightDisplay.jinToKG(jin)
            }
        )
    }
}

private struct MedicationRecordEditor: View {
    @ObservedObject var record: MedicationRecord
    @State private var baselineDoseAmount: Double = 1
    @State private var dosageAmount = ""
    @State private var dosageUnit = "片"
    @State private var dosageAdjustment: Double = 0
    @State private var isSyncingDosageFromText = false

    var body: some View {
        Form {
            Section("药物信息") {
                DatePicker("记录时间", selection: recordedAtBinding)
                VStack(alignment: .leading, spacing: 10) {
                    Text("常用快捷添加")
                        .font(.subheadline.weight(.medium))

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        ForEach(MedicationPreset.pregnancyCommon) { preset in
                            Button {
                                record.name = preset.name
                                baselineDoseAmount = preset.dosageValue
                                dosageUnit = preset.dosageUnit
                                dosageAmount = String(format: "%.1f", preset.dosageValue)
                                syncDosageAdjustment()
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(preset.name)
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(.primary)
                                    Text(preset.detail)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(12)
                                .background(record.name == preset.name ? Color.accentColor.opacity(0.16) : Color(.secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Text("快捷项仅用于记录常见补充剂，具体是否使用和剂量请以医嘱为准。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                TextField("药名", text: nameBinding)
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("剂量快捷调整")
                            .font(.subheadline.weight(.medium))
                        Spacer()
                        Text("当前 \(MedicationDose(amount: currentDoseAmount, unit: dosageUnit).displayText)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("少 \(String(format: "%.1f", dosageSliderLimit)) \(dosageUnit)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("参考 \(String(format: "%.1f", baselineDoseAmount)) \(dosageUnit)")
                            .font(.caption.weight(.semibold))
                        Spacer()
                        Text("多 \(String(format: "%.1f", dosageSliderLimit)) \(dosageUnit)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Slider(value: $dosageAdjustment, in: -dosageSliderLimit...dosageSliderLimit, step: 0.5) {
                        Text("剂量调整")
                    } minimumValueLabel: {
                        Image(systemName: "minus")
                            .foregroundStyle(.secondary)
                    } maximumValueLabel: {
                        Image(systemName: "plus")
                            .foregroundStyle(.secondary)
                    }
                    .onChange(of: dosageAdjustment) { _ in
                        guard !isSyncingDosageFromText else { return }
                        let updated = max(baselineDoseAmount + dosageAdjustment, 0)
                        dosageAmount = String(format: "%.1f", updated)
                        record.dosage = MedicationDose(amount: updated, unit: dosageUnit).displayText
                    }

                    Text(dosageSelectionText)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 2)

                    HStack(spacing: 12) {
                        Button {
                            adjustDosage(by: -0.5)
                        } label: {
                            Label("减", systemImage: "minus.circle.fill")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color(.secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.plain)

                        Button {
                            adjustDosage(by: 0.5)
                        } label: {
                            Label("加", systemImage: "plus.circle.fill")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color(.secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }

                HStack(spacing: 12) {
                    TextField("剂量", text: $dosageAmount)
                        .keyboardType(.decimalPad)
                        .onChange(of: dosageAmount) { _ in
                            syncDosageAdjustment()
                        }

                    Picker("单位", selection: $dosageUnit) {
                        ForEach(medicationDoseUnits, id: \.self) { unit in
                            Text(unit).tag(unit)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: dosageUnit) { _ in
                        if let amount = Double(dosageAmount.trimmingCharacters(in: .whitespacesAndNewlines)) {
                            record.dosage = MedicationDose(amount: amount, unit: dosageUnit).displayText
                        }
                    }
                }
                TextField("备注", text: noteBinding, axis: .vertical)
                    .lineLimit(2...4)
            }
        }
        .onAppear {
            let parsedDose = MedicationDose.parse(record.dosage) ?? MedicationDose(amount: 1, unit: "片")
            baselineDoseAmount = parsedDose.amount
            dosageUnit = parsedDose.unit
            dosageAmount = String(format: "%.1f", parsedDose.amount)
            syncDosageAdjustment()
        }
    }

    private var recordedAtBinding: Binding<Date> {
        Binding(
            get: { record.recordedAt },
            set: { record.recordedAt = $0 }
        )
    }

    private var nameBinding: Binding<String> {
        Binding(
            get: { record.name },
            set: { record.name = $0 }
        )
    }

    private var medicationDoseUnits: [String] {
        ["片", "粒", "袋", "ml", "mg", "mcg", "IU", "次"]
    }

    private var currentDoseAmount: Double {
        Double(dosageAmount.trimmingCharacters(in: .whitespacesAndNewlines)) ?? baselineDoseAmount
    }

    private var dosageSliderLimit: Double {
        max(max(1.0, abs(currentDoseAmount - baselineDoseAmount)), baselineDoseAmount)
    }

    private var dosageSelectionText: String {
        let delta = currentDoseAmount - baselineDoseAmount
        if abs(delta) < 0.05 {
            return "当前选择：参考 \(String(format: "%.1f", currentDoseAmount)) \(dosageUnit)"
        }
        return "当前选择：\(String(format: "%.1f", currentDoseAmount)) \(dosageUnit)（\(delta > 0 ? "多" : "少") \(String(format: "%.1f", abs(delta))) \(dosageUnit)）"
    }

    private func syncDosageAdjustment() {
        guard let amount = Double(dosageAmount.trimmingCharacters(in: .whitespacesAndNewlines)) else { return }
        record.dosage = MedicationDose(amount: amount, unit: dosageUnit).displayText
        isSyncingDosageFromText = true
        dosageAdjustment = max(min(amount - baselineDoseAmount, dosageSliderLimit), -dosageSliderLimit)
        DispatchQueue.main.async {
            isSyncingDosageFromText = false
        }
    }

    private func adjustDosage(by delta: Double) {
        let updated = max(currentDoseAmount + delta, 0)
        dosageAmount = String(format: "%.1f", updated)
        syncDosageAdjustment()
    }

    private var noteBinding: Binding<String> {
        Binding(
            get: { record.note },
            set: { record.note = $0 }
        )
    }
}

private struct CheckupRecordEditor: View {
    @ObservedObject var record: CheckupRecord

    var body: some View {
        Form {
            Section("检查信息") {
                DatePicker("记录时间", selection: recordedAtBinding)
                TextField("医院 / 机构", text: locationBinding)
                TextField("结果摘要", text: summaryBinding, axis: .vertical)
                    .lineLimit(2...4)
                TextField("附件路径占位", text: attachmentPathBinding)
                TextField("备注", text: noteBinding, axis: .vertical)
                    .lineLimit(2...4)
            }
        }
    }

    private var recordedAtBinding: Binding<Date> {
        Binding(
            get: { record.recordedAt },
            set: { record.recordedAt = $0 }
        )
    }

    private var locationBinding: Binding<String> {
        Binding(
            get: { record.location },
            set: { record.location = $0 }
        )
    }

    private var summaryBinding: Binding<String> {
        Binding(
            get: { record.summary },
            set: { record.summary = $0 }
        )
    }

    private var attachmentPathBinding: Binding<String> {
        Binding(
            get: { record.attachmentPath },
            set: { record.attachmentPath = $0 }
        )
    }

    private var noteBinding: Binding<String> {
        Binding(
            get: { record.note },
            set: { record.note = $0 }
        )
    }
}

private struct FetalMovementRecordEditor: View {
    @ObservedObject var record: FetalMovementRecord

    var body: some View {
        Form {
            Section("胎动信息") {
                DatePicker("记录时间", selection: recordedAtBinding)
                TextField("持续时长（分钟，可选）", text: durationTextBinding)
                    .keyboardType(.numberPad)
                TextField("胎动次数（可选）", text: countTextBinding)
                    .keyboardType(.numberPad)
                TextField("备注", text: noteBinding, axis: .vertical)
                    .lineLimit(2...4)
            }
        }
    }

    private var recordedAtBinding: Binding<Date> {
        Binding(
            get: { record.recordedAt },
            set: { record.recordedAt = $0 }
        )
    }

    private var noteBinding: Binding<String> {
        Binding(
            get: { record.note },
            set: { record.note = $0 }
        )
    }

    private var durationTextBinding: Binding<String> {
        Binding(
            get: { record.durationMinutes.map(String.init) ?? "" },
            set: { newValue in
                let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                record.durationMinutes = trimmed.isEmpty ? nil : Int(trimmed)
            }
        )
    }

    private var countTextBinding: Binding<String> {
        Binding(
            get: { record.movementCount.map(String.init) ?? "" },
            set: { newValue in
                let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                record.movementCount = trimmed.isEmpty ? nil : Int(trimmed)
            }
        )
    }
}

private struct BloodGlucoseRecordEditor: View {
    @ObservedObject var record: BloodGlucoseRecord
    @State private var baselineValue: Double = 0
    @State private var valueText = ""
    @State private var adjustment: Double = 0
    @State private var isSyncingFromText = false

    var body: some View {
        Form {
            Section("血糖信息") {
                DatePicker("记录时间", selection: recordedAtBinding)
                Picker("时段", selection: momentBinding) {
                    ForEach(BloodGlucoseMoment.allCases) { moment in
                        Text(moment.displayName).tag(moment)
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("血糖快捷调整")
                            .font(.subheadline.weight(.medium))
                        Spacer()
                        Text("当前 \(String(format: "%.1f", record.valueMMOL)) mmol/L")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("少 \(String(format: "%.1f", sliderLimit))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("参考 \(String(format: "%.1f", baselineValue))")
                            .font(.caption.weight(.semibold))
                        Spacer()
                        Text("多 \(String(format: "%.1f", sliderLimit))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Slider(value: $adjustment, in: -sliderLimit...sliderLimit, step: 0.1) {
                        Text("血糖调整")
                    } minimumValueLabel: {
                        Image(systemName: "minus")
                            .foregroundStyle(.secondary)
                    } maximumValueLabel: {
                        Image(systemName: "plus")
                            .foregroundStyle(.secondary)
                    }
                    .onChange(of: adjustment) { _ in
                        guard !isSyncingFromText else { return }
                        let updated = max(baselineValue + adjustment, 0)
                        valueText = String(format: "%.1f", updated)
                        record.valueMMOL = updated
                    }

                    Text(selectionText)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 2)

                    HStack(spacing: 12) {
                        Button {
                            adjustValue(by: -0.1)
                        } label: {
                            Label("减", systemImage: "minus.circle.fill")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color(.secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.plain)

                        Button {
                            adjustValue(by: 0.1)
                        } label: {
                            Label("加", systemImage: "plus.circle.fill")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color(.secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }

                TextField("血糖（mmol/L）", text: $valueText)
                    .keyboardType(.decimalPad)
                    .onChange(of: valueText) { _ in
                        syncAdjustmentFromText()
                    }
                TextField("备注", text: noteBinding, axis: .vertical)
                    .lineLimit(2...4)
            }
        }
        .onAppear {
            baselineValue = record.valueMMOL
            valueText = String(format: "%.1f", record.valueMMOL)
            syncAdjustmentFromText()
        }
    }

    private var recordedAtBinding: Binding<Date> {
        Binding(
            get: { record.recordedAt },
            set: { record.recordedAt = $0 }
        )
    }

    private var momentBinding: Binding<BloodGlucoseMoment> {
        Binding(
            get: { record.moment },
            set: { record.moment = $0 }
        )
    }

    private var noteBinding: Binding<String> {
        Binding(
            get: { record.note },
            set: { record.note = $0 }
        )
    }

    private var sliderLimit: Double {
        let baseLimit = 2.0
        guard let value = Double(valueText.trimmingCharacters(in: .whitespacesAndNewlines)) else { return baseLimit }
        return max(baseLimit, abs(value - baselineValue))
    }

    private var selectionText: String {
        let currentValue = max(baselineValue + adjustment, 0)
        let delta = currentValue - baselineValue
        if abs(delta) < 0.05 {
            return "当前选择：参考 \(String(format: "%.1f", currentValue)) mmol/L"
        }
        return "当前选择：\(String(format: "%.1f", currentValue)) mmol/L（\(delta > 0 ? "多" : "少") \(String(format: "%.1f", abs(delta))) mmol/L）"
    }

    private func syncAdjustmentFromText() {
        guard let value = Double(valueText.trimmingCharacters(in: .whitespacesAndNewlines)) else { return }
        record.valueMMOL = value
        isSyncingFromText = true
        adjustment = max(min(value - baselineValue, sliderLimit), -sliderLimit)
        DispatchQueue.main.async {
            isSyncingFromText = false
        }
    }

    private func adjustValue(by delta: Double) {
        let current = Double(valueText.trimmingCharacters(in: .whitespacesAndNewlines)) ?? record.valueMMOL
        let updated = max(current + delta, 0)
        valueText = String(format: "%.1f", updated)
        record.valueMMOL = updated
        syncAdjustmentFromText()
    }
}
