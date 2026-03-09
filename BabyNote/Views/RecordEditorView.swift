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

    var body: some View {
        Form {
            Section("药物信息") {
                DatePicker("记录时间", selection: recordedAtBinding)
                TextField("药名", text: nameBinding)
                TextField("剂量", text: dosageBinding)
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

    private var nameBinding: Binding<String> {
        Binding(
            get: { record.name },
            set: { record.name = $0 }
        )
    }

    private var dosageBinding: Binding<String> {
        Binding(
            get: { record.dosage },
            set: { record.dosage = $0 }
        )
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

    var body: some View {
        Form {
            Section("血糖信息") {
                DatePicker("记录时间", selection: recordedAtBinding)
                Picker("时段", selection: momentBinding) {
                    ForEach(BloodGlucoseMoment.allCases) { moment in
                        Text(moment.displayName).tag(moment)
                    }
                }
                TextField("血糖（mmol/L）", text: valueTextBinding)
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

    private var valueTextBinding: Binding<String> {
        Binding(
            get: { String(format: "%.1f", record.valueMMOL) },
            set: { newValue in
                guard let value = Double(newValue.trimmingCharacters(in: .whitespacesAndNewlines)) else { return }
                record.valueMMOL = value
            }
        )
    }
}
