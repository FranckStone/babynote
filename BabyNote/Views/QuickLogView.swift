import SwiftData
import SwiftUI

struct QuickLogView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FeedingRecord.startedAt, order: .reverse) private var feedings: [FeedingRecord]
    @Query(sort: \WeightRecord.recordedAt, order: .reverse) private var weights: [WeightRecord]

    @State private var recordType: RecordType = .feeding

    @State private var feedingStartedAt = Date()
    @State private var feedingEndedAt = Date().addingTimeInterval(15 * 60)
    @State private var feedingType: FeedingType = .formula
    @State private var feedingAmount = ""
    @State private var feedingNote = ""
    @State private var didApplySuggestedFeedingAmount = false
    @State private var didApplySuggestedFeedingDuration = false
    @State private var feedingAmountAdjustment: Double = 0
    @State private var feedingDurationAdjustment: Double = 0

    @State private var weightRecordedAt = Date()
    @State private var weightKG = ""
    @State private var weightNote = ""
    @State private var didApplySuggestedWeight = false
    @State private var weightAdjustment: Double = 0

    @State private var medicationRecordedAt = Date()
    @State private var medicationName = ""
    @State private var medicationDosage = ""
    @State private var medicationNote = ""

    @State private var checkupRecordedAt = Date()
    @State private var checkupLocation = ""
    @State private var checkupSummary = ""
    @State private var checkupAttachment = ""
    @State private var checkupNote = ""

    @State private var fetalMovementRecordedAt = Date()
    @State private var fetalMovementDuration = ""
    @State private var fetalMovementCount = ""
    @State private var fetalMovementNote = ""

    private let showsTypePicker: Bool

    init(initialRecordType: RecordType = .feeding, showsTypePicker: Bool = true) {
        _recordType = State(initialValue: initialRecordType)
        self.showsTypePicker = showsTypePicker
    }

    var body: some View {
        NavigationStack {
            Form {
                if showsTypePicker {
                    Section("记录类型") {
                        Picker("类型", selection: $recordType) {
                            ForEach(RecordType.allCases) { type in
                                Label(type.displayName, systemImage: type.symbol)
                                    .tag(type)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
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
                case .fetalMovement:
                    fetalMovementForm
                }
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .environment(\.locale, Locale(identifier: "zh_CN"))
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

    private var navigationTitle: String {
        showsTypePicker ? "快速记录" : "\(recordType.displayName)记录"
    }

    private var latestFormulaAmountML: Int? {
        feedings.compactMap { record in
            guard record.feedingType == .formula else { return nil }
            guard let amountML = record.amountML else { return nil }
            return Int(amountML)
        }.first
    }

    private var latestBreastDurationMinutes: Int? {
        feedings.compactMap { record in
            guard record.feedingType == feedingType else { return nil }
            return record.durationMinutes
        }.first
    }

    private var suggestedFeedingAmountML: Int {
        latestFormulaAmountML ?? 60
    }

    private var suggestedBreastDurationMinutes: Int {
        latestBreastDurationMinutes ?? 15
    }

    private var latestWeightKG: Double? {
        weights.first?.weightKG
    }

    private var suggestedWeightKG: Double {
        latestWeightKG ?? 60.0
    }

    private var isBreastFeeding: Bool {
        feedingType == .leftBreast || feedingType == .rightBreast
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

                if isBreastFeeding {
                    breastDurationPicker
                } else {
                    formulaAmountPicker
                }

                TextField("备注", text: $feedingNote, axis: .vertical)
                    .lineLimit(2...4)
            }
        }
        .onAppear {
            applySuggestedFeedingAmountIfNeeded()
            applySuggestedFeedingDurationIfNeeded()
        }
        .onChange(of: feedingType) {
            feedingAmountAdjustment = 0
            feedingDurationAdjustment = 0
            applySuggestedFeedingAmountIfNeeded(force: true)
            applySuggestedFeedingDurationIfNeeded(force: true)
        }
    }

    private var breastDurationPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("时长快捷选择")
                    .font(.subheadline.weight(.medium))
                Spacer()
                Text(breastDurationSuggestionTitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text("少 \(breastDurationSliderLimit) 分钟")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("参考 \(suggestedBreastDurationMinutes) 分钟")
                    .font(.caption.weight(.semibold))
                Spacer()
                Text("多 \(breastDurationSliderLimit) 分钟")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Slider(value: $feedingDurationAdjustment, in: -Double(breastDurationSliderLimit)...Double(breastDurationSliderLimit), step: 1) {
                Text("时长调整")
            } minimumValueLabel: {
                Image(systemName: "minus")
                    .foregroundStyle(.secondary)
            } maximumValueLabel: {
                Image(systemName: "plus")
                    .foregroundStyle(.secondary)
            }
            .onChange(of: feedingDurationAdjustment) {
                setFeedingDuration(minutes: suggestedBreastDurationMinutes + Int(feedingDurationAdjustment))
            }

            Text(breastDurationSelectionText)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 2)
        }
    }

    private var formulaAmountPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("奶量快捷选择")
                    .font(.subheadline.weight(.medium))
                Spacer()
                Text(feedingSuggestionTitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text("少 \(feedingAmountSliderLimit) ml")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("参考 \(suggestedFeedingAmountML) ml")
                    .font(.caption.weight(.semibold))
                Spacer()
                Text("多 \(feedingAmountSliderLimit) ml")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Slider(value: $feedingAmountAdjustment, in: -Double(feedingAmountSliderLimit)...Double(feedingAmountSliderLimit), step: 5) {
                Text("奶量调整")
            } minimumValueLabel: {
                Image(systemName: "minus")
                    .foregroundStyle(.secondary)
            } maximumValueLabel: {
                Image(systemName: "plus")
                    .foregroundStyle(.secondary)
            }
            .onChange(of: feedingAmountAdjustment) {
                feedingAmount = "\(max(suggestedFeedingAmountML + Int(feedingAmountAdjustment), 0))"
            }

            Text(feedingAmountSelectionText)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 2)

            TextField("奶量（ml，可选）", text: $feedingAmount)
                .keyboardType(.decimalPad)
                .onChange(of: feedingAmount) {
                    syncFeedingAmountAdjustment()
                }
        }
    }

    private var weightForm: some View {
        Group {
            Section("体重信息") {
                DatePicker("记录时间", selection: $weightRecordedAt)
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("体重快捷调整")
                            .font(.subheadline.weight(.medium))
                        Spacer()
                        Text(weightSuggestionTitle)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("少 \(String(format: "%.1f", weightSliderLimitKG)) kg")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("参考 \(String(format: "%.1f", suggestedWeightKG)) kg")
                            .font(.caption.weight(.semibold))
                        Spacer()
                        Text("多 \(String(format: "%.1f", weightSliderLimitKG)) kg")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Slider(value: $weightAdjustment, in: -weightSliderLimitKG...weightSliderLimitKG, step: 0.1) {
                        Text("体重调整")
                    } minimumValueLabel: {
                        Image(systemName: "minus")
                            .foregroundStyle(.secondary)
                    } maximumValueLabel: {
                        Image(systemName: "plus")
                            .foregroundStyle(.secondary)
                    }
                    .onChange(of: weightAdjustment) {
                        weightKG = String(format: "%.1f", max(suggestedWeightKG + weightAdjustment, 0))
                    }

                    Text(weightSelectionText)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 2)
                }

                TextField("体重（kg）", text: $weightKG)
                    .keyboardType(.decimalPad)
                    .onChange(of: weightKG) {
                        syncWeightAdjustment()
                    }
                TextField("备注", text: $weightNote, axis: .vertical)
                    .lineLimit(2...4)
            }
        }
        .onAppear {
            applySuggestedWeightIfNeeded()
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

    private var fetalMovementForm: some View {
        Group {
            Section("胎动信息") {
                DatePicker("记录时间", selection: $fetalMovementRecordedAt)
                TextField("持续时长（分钟，可选）", text: $fetalMovementDuration)
                    .keyboardType(.numberPad)
                TextField("胎动次数（可选）", text: $fetalMovementCount)
                    .keyboardType(.numberPad)
                TextField("备注", text: $fetalMovementNote, axis: .vertical)
                    .lineLimit(2...4)
            }
        }
    }

    private var canSave: Bool {
        switch recordType {
        case .feeding:
            return feedingEndedAt >= feedingStartedAt && (isBreastFeeding || Double(feedingAmount) != nil)
        case .weight:
            return Double(weightKG) != nil
        case .medication:
            return !medicationName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                !medicationDosage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .checkup:
            return !checkupLocation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                !checkupSummary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .fetalMovement:
            return Int(fetalMovementDuration) != nil || Int(fetalMovementCount) != nil || !fetalMovementNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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

        case .fetalMovement:
            modelContext.insert(
                FetalMovementRecord(
                    recordedAt: fetalMovementRecordedAt,
                    durationMinutes: Int(fetalMovementDuration),
                    movementCount: Int(fetalMovementCount),
                    note: fetalMovementNote
                )
            )
        }

        try? modelContext.save()
        dismiss()
    }

    private var feedingSuggestionTitle: String {
        if let latestFormulaAmountML {
            return "上次 \(latestFormulaAmountML) ml"
        }
        return "默认 60 ml"
    }

    private var breastDurationSuggestionTitle: String {
        if let latestBreastDurationMinutes {
            return "上次 \(latestBreastDurationMinutes) 分钟"
        }
        return "默认 15 分钟"
    }

    private var selectedFeedingDurationMinutes: Int {
        max(Int(feedingEndedAt.timeIntervalSince(feedingStartedAt) / 60), 0)
    }

    private var feedingAmountSliderLimit: Int {
        max(20, suggestedFeedingAmountML / 2)
    }

    private var breastDurationSliderLimit: Int {
        max(10, suggestedBreastDurationMinutes)
    }

    private var weightSliderLimitKG: Double {
        5.0
    }

    private var feedingAmountSelectionText: String {
        let currentAmount = max(suggestedFeedingAmountML + Int(feedingAmountAdjustment), 0)
        let delta = currentAmount - suggestedFeedingAmountML
        if delta == 0 {
            return "当前选择：参考 \(currentAmount) ml"
        }
        return "当前选择：\(currentAmount) ml（\(delta > 0 ? "多" : "少") \(abs(delta)) ml）"
    }

    private var breastDurationSelectionText: String {
        let currentDuration = max(suggestedBreastDurationMinutes + Int(feedingDurationAdjustment), 1)
        let delta = currentDuration - suggestedBreastDurationMinutes
        if delta == 0 {
            return "当前选择：参考 \(currentDuration) 分钟"
        }
        return "当前选择：\(currentDuration) 分钟（\(delta > 0 ? "多" : "少") \(abs(delta)) 分钟）"
    }

    private var weightSuggestionTitle: String {
        if let latestWeightKG {
            return "上次 \(String(format: "%.1f", latestWeightKG)) kg"
        }
        return "默认 60.0 kg"
    }

    private var weightSelectionText: String {
        let currentWeight = max(suggestedWeightKG + weightAdjustment, 0)
        let delta = currentWeight - suggestedWeightKG
        if abs(delta) < 0.05 {
            return "当前选择：参考 \(String(format: "%.1f", currentWeight)) kg"
        }
        return "当前选择：\(String(format: "%.1f", currentWeight)) kg（\(delta > 0 ? "多" : "少") \(String(format: "%.1f", abs(delta))) kg）"
    }

    private func applySuggestedFeedingAmountIfNeeded(force: Bool = false) {
        guard feedingType == .formula else {
            feedingAmount = ""
            return
        }
        guard force || !didApplySuggestedFeedingAmount else { return }
        guard force || feedingAmount.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        feedingAmountAdjustment = 0
        feedingAmount = "\(suggestedFeedingAmountML)"
        didApplySuggestedFeedingAmount = true
    }

    private func applySuggestedFeedingDurationIfNeeded(force: Bool = false) {
        guard isBreastFeeding else { return }
        guard force || !didApplySuggestedFeedingDuration else { return }
        if force || selectedFeedingDurationMinutes <= 0 {
            feedingDurationAdjustment = 0
            setFeedingDuration(minutes: suggestedBreastDurationMinutes)
        }
        didApplySuggestedFeedingDuration = true
    }

    private func setFeedingDuration(minutes: Int) {
        feedingEndedAt = feedingStartedAt.addingTimeInterval(TimeInterval(minutes * 60))
    }

    private func syncFeedingAmountAdjustment() {
        guard let amount = Double(feedingAmount) else { return }
        let delta = Int(amount) - suggestedFeedingAmountML
        feedingAmountAdjustment = Double(max(min(delta, feedingAmountSliderLimit), -feedingAmountSliderLimit))
    }

    private func applySuggestedWeightIfNeeded(force: Bool = false) {
        guard force || !didApplySuggestedWeight else { return }
        guard force || weightKG.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        weightAdjustment = 0
        weightKG = String(format: "%.1f", suggestedWeightKG)
        didApplySuggestedWeight = true
    }

    private func syncWeightAdjustment() {
        guard let weight = Double(weightKG) else { return }
        let delta = weight - suggestedWeightKG
        weightAdjustment = max(min(delta, weightSliderLimitKG), -weightSliderLimitKG)
    }
}
