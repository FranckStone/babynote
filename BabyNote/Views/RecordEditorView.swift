import Foundation
import SwiftData
import SwiftUI

struct RecordEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let item: TimelineItem
    @State private var isShowingDeleteConfirmation = false

    var body: some View {
        NavigationStack {
            editorContent
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
        }
    }

    private func saveAndDismiss() {
        try? modelContext.save()
        dismiss()
    }

    private func deleteRecord() {
        switch item.record {
        case .feeding(let record):
            modelContext.delete(record)
        case .weight(let record):
            modelContext.delete(record)
        case .medication(let record):
            modelContext.delete(record)
        case .checkup(let record):
            modelContext.delete(record)
        case .fetalMovement(let record):
            modelContext.delete(record)
        }

        try? modelContext.save()
        dismiss()
    }
}

private struct FeedingRecordEditor: View {
    @Bindable var record: FeedingRecord

    var body: some View {
        Form {
            Section("喂奶信息") {
                DatePicker("开始时间", selection: $record.startedAt)
                DatePicker(
                    "结束时间",
                    selection: Binding(
                        get: { record.endedAt ?? record.startedAt },
                        set: { record.endedAt = $0 }
                    ),
                    in: record.startedAt...
                )
                Picker("喂养方式", selection: Binding(get: { record.feedingType }, set: { record.feedingType = $0 })) {
                    ForEach(FeedingType.allCases) { type in
                        Text(type.displayName).tag(type)
                    }
                }
                TextField("奶量（ml，可选）", text: amountTextBinding)
                .keyboardType(.decimalPad)
                TextField("备注", text: $record.note, axis: .vertical)
                    .lineLimit(2...4)
            }
        }
    }

    private var amountTextBinding: Binding<String> {
        Binding(
            get: {
                guard let amountML = record.amountML else { return "" }
                return String(format: "%.0f", amountML)
            },
            set: { newValue in
                let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                record.amountML = trimmed.isEmpty ? nil : Double(trimmed)
            }
        )
    }
}

private struct WeightRecordEditor: View {
    @Bindable var record: WeightRecord

    var body: some View {
        Form {
            Section("体重信息") {
                DatePicker("记录时间", selection: $record.recordedAt)
                TextField("体重（kg）", value: $record.weightKG, format: .number)
                    .keyboardType(.decimalPad)
                TextField("备注", text: $record.note, axis: .vertical)
                    .lineLimit(2...4)
            }
        }
    }
}

private struct MedicationRecordEditor: View {
    @Bindable var record: MedicationRecord

    var body: some View {
        Form {
            Section("药物信息") {
                DatePicker("记录时间", selection: $record.recordedAt)
                TextField("药名", text: $record.name)
                TextField("剂量", text: $record.dosage)
                TextField("备注", text: $record.note, axis: .vertical)
                    .lineLimit(2...4)
            }
        }
    }
}

private struct CheckupRecordEditor: View {
    @Bindable var record: CheckupRecord

    var body: some View {
        Form {
            Section("检查信息") {
                DatePicker("记录时间", selection: $record.recordedAt)
                TextField("医院 / 机构", text: $record.location)
                TextField("结果摘要", text: $record.summary, axis: .vertical)
                    .lineLimit(2...4)
                TextField("附件路径占位", text: $record.attachmentPath)
                TextField("备注", text: $record.note, axis: .vertical)
                    .lineLimit(2...4)
            }
        }
    }
}

private struct FetalMovementRecordEditor: View {
    @Bindable var record: FetalMovementRecord

    var body: some View {
        Form {
            Section("胎动信息") {
                DatePicker("记录时间", selection: $record.recordedAt)
                TextField("持续时长（分钟，可选）", text: durationTextBinding)
                .keyboardType(.numberPad)
                TextField("胎动次数（可选）", text: countTextBinding)
                .keyboardType(.numberPad)
                TextField("备注", text: $record.note, axis: .vertical)
                    .lineLimit(2...4)
            }
        }
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
