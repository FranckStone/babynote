import SwiftData
import SwiftUI

struct QuickLogView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var recordType: RecordType = .feeding

    @State private var feedingStartedAt = Date()
    @State private var feedingEndedAt = Date().addingTimeInterval(15 * 60)
    @State private var feedingType: FeedingType = .leftBreast
    @State private var feedingAmount = ""
    @State private var feedingNote = ""

    @State private var weightRecordedAt = Date()
    @State private var weightKG = ""
    @State private var weightNote = ""

    @State private var medicationRecordedAt = Date()
    @State private var medicationName = ""
    @State private var medicationDosage = ""
    @State private var medicationNote = ""

    @State private var checkupRecordedAt = Date()
    @State private var checkupLocation = ""
    @State private var checkupSummary = ""
    @State private var checkupAttachment = ""
    @State private var checkupNote = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("记录类型") {
                    Picker("类型", selection: $recordType) {
                        ForEach(RecordType.allCases) { type in
                            Label(type.displayName, systemImage: type.symbol)
                                .tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                switch recordType {
                case .feeding:
                    feedingForm
                case .weight:
                    weightForm
                case .medication:
                    medicationForm
                case .checkup:
                    checkupForm
                }
            }
            .navigationTitle("快速记录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存") {
                        saveRecord()
                    }
                    .fontWeight(.semibold)
                    .disabled(!canSave)
                }
            }
        }
    }

    private var feedingForm: some View {
        Group {
            Section("喂奶信息") {
                DatePicker("开始时间", selection: $feedingStartedAt)
                DatePicker("结束时间", selection: $feedingEndedAt)
                Picker("喂养方式", selection: $feedingType) {
                    ForEach(FeedingType.allCases) { type in
                        Text(type.displayName).tag(type)
                    }
                }
                TextField("奶量（ml，可选）", text: $feedingAmount)
                    .keyboardType(.decimalPad)
                TextField("备注", text: $feedingNote, axis: .vertical)
                    .lineLimit(2...4)
            }
        }
    }

    private var weightForm: some View {
        Group {
            Section("体重信息") {
                DatePicker("记录时间", selection: $weightRecordedAt)
                TextField("体重（kg）", text: $weightKG)
                    .keyboardType(.decimalPad)
                TextField("备注", text: $weightNote, axis: .vertical)
                    .lineLimit(2...4)
            }
        }
    }

    private var medicationForm: some View {
        Group {
            Section("药物信息") {
                DatePicker("记录时间", selection: $medicationRecordedAt)
                TextField("药名", text: $medicationName)
                TextField("剂量", text: $medicationDosage)
                TextField("备注", text: $medicationNote, axis: .vertical)
                    .lineLimit(2...4)
            }
        }
    }

    private var checkupForm: some View {
        Group {
            Section("检查信息") {
                DatePicker("记录时间", selection: $checkupRecordedAt)
                TextField("医院 / 机构", text: $checkupLocation)
                TextField("结果摘要", text: $checkupSummary, axis: .vertical)
                    .lineLimit(2...4)
                TextField("附件路径占位", text: $checkupAttachment)
                TextField("备注", text: $checkupNote, axis: .vertical)
                    .lineLimit(2...4)
            }
        }
    }

    private var canSave: Bool {
        switch recordType {
        case .feeding:
            return feedingEndedAt >= feedingStartedAt
        case .weight:
            return Double(weightKG) != nil
        case .medication:
            return !medicationName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                !medicationDosage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .checkup:
            return !checkupLocation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                !checkupSummary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    private func saveRecord() {
        switch recordType {
        case .feeding:
            let record = FeedingRecord(
                startedAt: feedingStartedAt,
                endedAt: feedingEndedAt,
                feedingType: feedingType,
                amountML: Double(feedingAmount),
                note: feedingNote
            )
            modelContext.insert(record)

        case .weight:
            guard let value = Double(weightKG) else { return }
            modelContext.insert(
                WeightRecord(
                    recordedAt: weightRecordedAt,
                    weightKG: value,
                    note: weightNote
                )
            )

        case .medication:
            modelContext.insert(
                MedicationRecord(
                    recordedAt: medicationRecordedAt,
                    name: medicationName,
                    dosage: medicationDosage,
                    note: medicationNote
                )
            )

        case .checkup:
            modelContext.insert(
                CheckupRecord(
                    recordedAt: checkupRecordedAt,
                    location: checkupLocation,
                    summary: checkupSummary,
                    attachmentPath: checkupAttachment,
                    note: checkupNote
                )
            )
        }

        try? modelContext.save()
        dismiss()
    }
}
