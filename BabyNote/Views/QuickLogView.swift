import CoreData
import SwiftUI

struct QuickLogView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var managedObjectContext
    @FetchRequest(sortDescriptors: [SortDescriptor(\FeedingRecord.startedAt, order: .reverse)]) private var feedings: FetchedResults<FeedingRecord>
    @FetchRequest(sortDescriptors: [SortDescriptor(\WeightRecord.recordedAt, order: .reverse)]) private var weights: FetchedResults<WeightRecord>
    @FetchRequest(sortDescriptors: [SortDescriptor(\MedicationRecord.recordedAt, order: .reverse)]) private var medications: FetchedResults<MedicationRecord>
    @FetchRequest(sortDescriptors: [SortDescriptor(\BloodGlucoseRecord.recordedAt, order: .reverse)]) private var bloodGlucoses: FetchedResults<BloodGlucoseRecord>

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
    @State private var isSyncingWeightFromText = false

    @State private var medicationRecordedAt = Date()
    @State private var medicationName = ""
    @State private var medicationDosageAmount = ""
    @State private var medicationDosageUnit = "片"
    @State private var medicationNote = ""
    @State private var didApplySuggestedMedicationDose = false
    @State private var medicationDosageAdjustment: Double = 0
    @State private var isSyncingMedicationDoseFromText = false

    @State private var checkupRecordedAt = Date()
    @State private var checkupLocation = ""
    @State private var checkupSummary = ""
    @State private var checkupAttachment = ""
    @State private var checkupNote = ""

    @State private var fetalMovementRecordedAt = Date()
    @State private var fetalMovementDuration = ""
    @State private var fetalMovementCount = ""
    @State private var fetalMovementNote = ""
    @State private var bloodGlucoseRecordedAt = Date()
    @State private var bloodGlucoseMoment: BloodGlucoseMoment = .beforeBreakfast
    @State private var bloodGlucoseValue = ""
    @State private var bloodGlucoseNote = ""
    @State private var didApplySuggestedBloodGlucose = false
    @State private var bloodGlucoseAdjustment: Double = 0
    @State private var isSyncingBloodGlucoseFromText = false

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
                case .bloodGlucose:
                    bloodGlucoseForm
                }
            }
            .adaptiveContentWidth(horizontalSizeClass == .regular ? 760 : .infinity)
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
        .presentationDetents(horizontalSizeClass == .regular ? [.large] : [.medium, .large])
    }

    private var navigationTitle: String {
        showsTypePicker ? "快速记录" : "\(recordType.displayName)记录"
    }

    private var latestFormulaAmountML: Int? {
        feedings.compactMap { record in
            guard record.feedingType == .formula else { return nil }
            guard let amountML = record.amountMLValue else { return nil }
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

    private var suggestedWeightJin: Double {
        WeightDisplay.kgToJin(latestWeightKG ?? 60.0)
    }

    private var latestBloodGlucoseMMOL: Double? {
        bloodGlucoses.first?.valueMMOL
    }

    private var suggestedBloodGlucoseMMOL: Double {
        latestBloodGlucoseMMOL ?? 5.5
    }

    private var latestMedicationDose: MedicationDose? {
        let trimmedName = medicationName.trimmingCharacters(in: .whitespacesAndNewlines)
        let preferred = medications.compactMap { record -> MedicationDose? in
            if !trimmedName.isEmpty && record.name != trimmedName {
                return nil
            }
            return MedicationDose.parse(record.dosage)
        }

        return preferred.first ?? medications.compactMap { MedicationDose.parse($0.dosage) }.first
    }

    private var suggestedMedicationDose: MedicationDose {
        latestMedicationDose ?? MedicationDose(amount: 1, unit: medicationDosageUnit)
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
        .onChange(of: feedingType) { _ in
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
            .onChange(of: feedingDurationAdjustment) { _ in
                setFeedingDuration(minutes: suggestedBreastDurationMinutes + Int(feedingDurationAdjustment))
            }

            Text(breastDurationSelectionText)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 2)

            microAdjustButtons(
                minusAction: { adjustBreastDuration(by: -1) },
                plusAction: { adjustBreastDuration(by: 1) }
            )
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
            .onChange(of: feedingAmountAdjustment) { _ in
                feedingAmount = "\(max(suggestedFeedingAmountML + Int(feedingAmountAdjustment), 0))"
            }

            Text(feedingAmountSelectionText)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 2)

            microAdjustButtons(
                minusAction: { adjustFeedingAmount(by: -5) },
                plusAction: { adjustFeedingAmount(by: 5) }
            )

            TextField("奶量（ml，可选）", text: $feedingAmount)
                .keyboardType(.decimalPad)
                .onChange(of: feedingAmount) { _ in
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
                        Text("少 \(String(format: "%.1f", weightSliderLimitJin)) 斤")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("参考 \(String(format: "%.1f", suggestedWeightJin)) 斤")
                            .font(.caption.weight(.semibold))
                        Spacer()
                        Text("多 \(String(format: "%.1f", weightSliderLimitJin)) 斤")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

            Slider(value: $weightAdjustment, in: -weightSliderLimitJin...weightSliderLimitJin, step: 0.1) {
                Text("体重调整")
            } minimumValueLabel: {
                Image(systemName: "minus")
                    .foregroundStyle(.secondary)
                    } maximumValueLabel: {
                        Image(systemName: "plus")
                            .foregroundStyle(.secondary)
                    }
                    .onChange(of: weightAdjustment) { _ in
                        guard !isSyncingWeightFromText else { return }
                        weightKG = String(format: "%.1f", max(suggestedWeightJin + weightAdjustment, 0))
                    }

                    Text(weightSelectionText)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 2)

                    microAdjustButtons(
                        minusAction: { adjustWeight(by: -0.1) },
                        plusAction: { adjustWeight(by: 0.1) }
                    )
                }

                TextField("体重（斤）", text: $weightKG)
                    .keyboardType(.decimalPad)
                    .onChange(of: weightKG) { _ in
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
                VStack(alignment: .leading, spacing: 10) {
                    Text("常用快捷添加")
                        .font(.subheadline.weight(.medium))

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        ForEach(MedicationPreset.pregnancyCommon) { preset in
                            Button {
                                applyMedicationPreset(preset)
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
                                .background(medicationName == preset.name ? Color.accentColor.opacity(0.16) : Color(.secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Text("快捷项仅用于记录常见补充剂，具体是否使用和剂量请以医嘱为准。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                TextField("药名", text: $medicationName)
                    .onChange(of: medicationName) { _ in
                        if medicationDosageAmount.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            applySuggestedMedicationDoseIfNeeded(force: true)
                        }
                    }

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("剂量快捷调整")
                            .font(.subheadline.weight(.medium))
                        Spacer()
                        Text(medicationDoseSuggestionTitle)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("少 \(String(format: "%.1f", medicationDosageSliderLimit)) \(medicationDosageUnit)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("参考 \(String(format: "%.1f", suggestedMedicationDose.amount)) \(suggestedMedicationDose.unit)")
                            .font(.caption.weight(.semibold))
                        Spacer()
                        Text("多 \(String(format: "%.1f", medicationDosageSliderLimit)) \(medicationDosageUnit)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Slider(value: $medicationDosageAdjustment, in: -medicationDosageSliderLimit...medicationDosageSliderLimit, step: 0.5) {
                        Text("剂量调整")
                    } minimumValueLabel: {
                        Image(systemName: "minus")
                            .foregroundStyle(.secondary)
                    } maximumValueLabel: {
                        Image(systemName: "plus")
                            .foregroundStyle(.secondary)
                    }
                    .onChange(of: medicationDosageAdjustment) { _ in
                        guard !isSyncingMedicationDoseFromText else { return }
                        medicationDosageAmount = String(format: "%.1f", max(suggestedMedicationDose.amount + medicationDosageAdjustment, 0))
                    }

                    Text(medicationDosageSelectionText)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 2)

                    microAdjustButtons(
                        minusAction: { adjustMedicationDosage(by: -0.5) },
                        plusAction: { adjustMedicationDosage(by: 0.5) }
                    )
                }

                HStack(spacing: 12) {
                    TextField("剂量", text: $medicationDosageAmount)
                        .keyboardType(.decimalPad)
                        .onChange(of: medicationDosageAmount) { _ in
                            syncMedicationDosageAdjustment()
                        }

                    Picker("单位", selection: $medicationDosageUnit) {
                        ForEach(medicationDoseUnits, id: \.self) { unit in
                            Text(unit).tag(unit)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: medicationDosageUnit) { _ in
                        if medicationDosageAmount.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            applySuggestedMedicationDoseIfNeeded(force: true)
                        } else {
                            syncMedicationDosageAdjustment()
                        }
                    }
                }
                TextField("备注", text: $medicationNote, axis: .vertical)
                    .lineLimit(2...4)
            }
        }
        .onAppear {
            applySuggestedMedicationDoseIfNeeded()
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

    private var bloodGlucoseForm: some View {
        Group {
            Section("血糖信息") {
                DatePicker("记录时间", selection: $bloodGlucoseRecordedAt)

                VStack(alignment: .leading, spacing: 10) {
                    Text("快捷时段")
                        .font(.subheadline.weight(.medium))

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        ForEach(BloodGlucoseMoment.allCases) { moment in
                            Button {
                                bloodGlucoseMoment = moment
                            } label: {
                                Text(moment.displayName)
                                    .font(.subheadline.weight(.medium))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(bloodGlucoseMoment == moment ? Color.accentColor : Color(.secondarySystemBackground))
                                    .foregroundStyle(bloodGlucoseMoment == moment ? .white : .primary)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("血糖快捷调整")
                            .font(.subheadline.weight(.medium))
                        Spacer()
                        Text(bloodGlucoseSuggestionTitle)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("少 \(String(format: "%.1f", bloodGlucoseSliderLimit))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("参考 \(String(format: "%.1f", suggestedBloodGlucoseMMOL))")
                            .font(.caption.weight(.semibold))
                        Spacer()
                        Text("多 \(String(format: "%.1f", bloodGlucoseSliderLimit))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Slider(value: $bloodGlucoseAdjustment, in: -bloodGlucoseSliderLimit...bloodGlucoseSliderLimit, step: 0.1) {
                        Text("血糖调整")
                    } minimumValueLabel: {
                        Image(systemName: "minus")
                            .foregroundStyle(.secondary)
                    } maximumValueLabel: {
                        Image(systemName: "plus")
                            .foregroundStyle(.secondary)
                    }
                    .onChange(of: bloodGlucoseAdjustment) { _ in
                        guard !isSyncingBloodGlucoseFromText else { return }
                        bloodGlucoseValue = String(format: "%.1f", max(suggestedBloodGlucoseMMOL + bloodGlucoseAdjustment, 0))
                    }

                    Text(bloodGlucoseSelectionText)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 2)

                    microAdjustButtons(
                        minusAction: { adjustBloodGlucose(by: -0.1) },
                        plusAction: { adjustBloodGlucose(by: 0.1) }
                    )
                }

                TextField("血糖（mmol/L）", text: $bloodGlucoseValue)
                    .keyboardType(.decimalPad)
                    .onChange(of: bloodGlucoseValue) { _ in
                        syncBloodGlucoseAdjustment()
                    }
                TextField("备注", text: $bloodGlucoseNote, axis: .vertical)
                    .lineLimit(2...4)

                if let latestBloodGlucoseMMOL {
                    Text("最近：\(String(format: "%.1f", latestBloodGlucoseMMOL)) mmol/L")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .onAppear {
            applySuggestedBloodGlucoseIfNeeded()
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
                Double(medicationDosageAmount.trimmingCharacters(in: .whitespacesAndNewlines)) != nil
        case .checkup:
            return !checkupLocation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                !checkupSummary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .fetalMovement:
            return Int(fetalMovementDuration) != nil || Int(fetalMovementCount) != nil || !fetalMovementNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .bloodGlucose:
            return Double(bloodGlucoseValue.trimmingCharacters(in: .whitespacesAndNewlines)) != nil
        }
    }

    private func saveRecord() {
        switch recordType {
        case .feeding:
            _ = FeedingRecord(
                context: managedObjectContext,
                startedAt: feedingStartedAt,
                endedAt: feedingEndedAt,
                feedingType: feedingType,
                amountML: Double(feedingAmount),
                note: feedingNote
            )

        case .weight:
            guard let value = Double(weightKG) else { return }
            _ = WeightRecord(
                context: managedObjectContext,
                recordedAt: weightRecordedAt,
                weightKG: WeightDisplay.jinToKG(value),
                note: weightNote
            )

        case .medication:
            _ = MedicationRecord(
                context: managedObjectContext,
                recordedAt: medicationRecordedAt,
                name: medicationName,
                dosage: medicationDoseText,
                note: medicationNote
            )

        case .checkup:
            _ = CheckupRecord(
                context: managedObjectContext,
                recordedAt: checkupRecordedAt,
                location: checkupLocation,
                summary: checkupSummary,
                attachmentPath: checkupAttachment,
                note: checkupNote
            )

        case .fetalMovement:
            _ = FetalMovementRecord(
                context: managedObjectContext,
                recordedAt: fetalMovementRecordedAt,
                durationMinutes: Int(fetalMovementDuration),
                movementCount: Int(fetalMovementCount),
                note: fetalMovementNote
            )

        case .bloodGlucose:
            guard let value = Double(bloodGlucoseValue.trimmingCharacters(in: .whitespacesAndNewlines)) else { return }
            _ = BloodGlucoseRecord(
                context: managedObjectContext,
                recordedAt: bloodGlucoseRecordedAt,
                moment: bloodGlucoseMoment,
                valueMMOL: value,
                note: bloodGlucoseNote
            )
        }

        try? managedObjectContext.save()
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
        let baseLimit = max(20, suggestedFeedingAmountML / 2)
        guard let amount = Double(feedingAmount) else { return baseLimit }
        return max(baseLimit, abs(Int(amount) - suggestedFeedingAmountML))
    }

    private var breastDurationSliderLimit: Int {
        max(10, suggestedBreastDurationMinutes)
    }

    private var weightSliderLimitJin: Double {
        let baseLimit = 5.0
        guard let weight = Double(weightKG) else { return baseLimit }
        return max(baseLimit, abs(weight - suggestedWeightJin))
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
            return "上次 \(WeightDisplay.jinText(fromKG: latestWeightKG))"
        }
        return "默认 120.0 斤"
    }

    private var weightSelectionText: String {
        let currentWeight = max(suggestedWeightJin + weightAdjustment, 0)
        let delta = currentWeight - suggestedWeightJin
        if abs(delta) < 0.05 {
            return "当前选择：参考 \(String(format: "%.1f", currentWeight)) 斤"
        }
        return "当前选择：\(String(format: "%.1f", currentWeight)) 斤（\(delta > 0 ? "多" : "少") \(String(format: "%.1f", abs(delta))) 斤）"
    }

    private var medicationDoseUnits: [String] {
        ["片", "粒", "袋", "ml", "mg", "mcg", "IU", "次"]
    }

    private var medicationDoseText: String {
        guard let amount = Double(medicationDosageAmount.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return ""
        }
        return MedicationDose(amount: amount, unit: medicationDosageUnit).displayText
    }

    private var medicationDoseSuggestionTitle: String {
        if let latestMedicationDose {
            return "上次 \(latestMedicationDose.displayText)"
        }
        return "默认 \(suggestedMedicationDose.displayText)"
    }

    private var medicationDosageSliderLimit: Double {
        let baseLimit = max(1.0, suggestedMedicationDose.amount)
        guard let amount = Double(medicationDosageAmount.trimmingCharacters(in: .whitespacesAndNewlines)) else { return baseLimit }
        return max(baseLimit, abs(amount - suggestedMedicationDose.amount))
    }

    private var medicationDosageSelectionText: String {
        let currentAmount = max(suggestedMedicationDose.amount + medicationDosageAdjustment, 0)
        let delta = currentAmount - suggestedMedicationDose.amount
        if abs(delta) < 0.05 {
            return "当前选择：参考 \(String(format: "%.1f", currentAmount)) \(medicationDosageUnit)"
        }
        return "当前选择：\(String(format: "%.1f", currentAmount)) \(medicationDosageUnit)（\(delta > 0 ? "多" : "少") \(String(format: "%.1f", abs(delta))) \(medicationDosageUnit)）"
    }

    private var bloodGlucoseSuggestionTitle: String {
        if let latestBloodGlucoseMMOL {
            return "上次 \(String(format: "%.1f", latestBloodGlucoseMMOL)) mmol/L"
        }
        return "默认 5.5 mmol/L"
    }

    private var bloodGlucoseSliderLimit: Double {
        let baseLimit = 2.0
        guard let value = Double(bloodGlucoseValue.trimmingCharacters(in: .whitespacesAndNewlines)) else { return baseLimit }
        return max(baseLimit, abs(value - suggestedBloodGlucoseMMOL))
    }

    private var bloodGlucoseSelectionText: String {
        let currentValue = max(suggestedBloodGlucoseMMOL + bloodGlucoseAdjustment, 0)
        let delta = currentValue - suggestedBloodGlucoseMMOL
        if abs(delta) < 0.05 {
            return "当前选择：参考 \(String(format: "%.1f", currentValue)) mmol/L"
        }
        return "当前选择：\(String(format: "%.1f", currentValue)) mmol/L（\(delta > 0 ? "多" : "少") \(String(format: "%.1f", abs(delta))) mmol/L）"
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
        weightKG = String(format: "%.1f", suggestedWeightJin)
        didApplySuggestedWeight = true
    }

    private func applySuggestedMedicationDoseIfNeeded(force: Bool = false) {
        guard force || !didApplySuggestedMedicationDose else { return }
        guard force || medicationDosageAmount.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        medicationDosageUnit = suggestedMedicationDose.unit
        medicationDosageAdjustment = 0
        medicationDosageAmount = String(format: "%.1f", suggestedMedicationDose.amount)
        didApplySuggestedMedicationDose = true
    }

    private func syncWeightAdjustment() {
        guard let weight = Double(weightKG) else { return }
        let delta = weight - suggestedWeightJin
        isSyncingWeightFromText = true
        weightAdjustment = max(min(delta, weightSliderLimitJin), -weightSliderLimitJin)
        DispatchQueue.main.async {
            isSyncingWeightFromText = false
        }
    }

    private func syncMedicationDosageAdjustment() {
        guard let amount = Double(medicationDosageAmount.trimmingCharacters(in: .whitespacesAndNewlines)) else { return }
        let delta = amount - suggestedMedicationDose.amount
        isSyncingMedicationDoseFromText = true
        medicationDosageAdjustment = max(min(delta, medicationDosageSliderLimit), -medicationDosageSliderLimit)
        DispatchQueue.main.async {
            isSyncingMedicationDoseFromText = false
        }
    }

    private func applySuggestedBloodGlucoseIfNeeded(force: Bool = false) {
        guard force || !didApplySuggestedBloodGlucose else { return }
        guard force || bloodGlucoseValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        bloodGlucoseAdjustment = 0
        bloodGlucoseValue = String(format: "%.1f", suggestedBloodGlucoseMMOL)
        didApplySuggestedBloodGlucose = true
    }

    private func syncBloodGlucoseAdjustment() {
        guard let value = Double(bloodGlucoseValue.trimmingCharacters(in: .whitespacesAndNewlines)) else { return }
        let delta = value - suggestedBloodGlucoseMMOL
        isSyncingBloodGlucoseFromText = true
        bloodGlucoseAdjustment = max(min(delta, bloodGlucoseSliderLimit), -bloodGlucoseSliderLimit)
        DispatchQueue.main.async {
            isSyncingBloodGlucoseFromText = false
        }
    }

    private func adjustFeedingAmount(by delta: Int) {
        let current = Int(feedingAmount) ?? suggestedFeedingAmountML
        let updated = max(current + delta, 0)
        feedingAmount = "\(updated)"
        syncFeedingAmountAdjustment()
    }

    private func adjustBreastDuration(by delta: Int) {
        let updated = max(selectedFeedingDurationMinutes + delta, 1)
        setFeedingDuration(minutes: updated)
        feedingDurationAdjustment = Double(updated - suggestedBreastDurationMinutes)
    }

    private func adjustWeight(by delta: Double) {
        let current = Double(weightKG) ?? suggestedWeightJin
        let updated = max(current + delta, 0)
        weightKG = String(format: "%.1f", updated)
        syncWeightAdjustment()
    }

    private func adjustMedicationDosage(by delta: Double) {
        let current = Double(medicationDosageAmount.trimmingCharacters(in: .whitespacesAndNewlines)) ?? suggestedMedicationDose.amount
        let updated = max(current + delta, 0)
        medicationDosageAmount = String(format: "%.1f", updated)
        syncMedicationDosageAdjustment()
    }

    private func adjustBloodGlucose(by delta: Double) {
        let current = Double(bloodGlucoseValue.trimmingCharacters(in: .whitespacesAndNewlines)) ?? suggestedBloodGlucoseMMOL
        let updated = max(current + delta, 0)
        bloodGlucoseValue = String(format: "%.1f", updated)
        syncBloodGlucoseAdjustment()
    }

    private func applyMedicationPreset(_ preset: MedicationPreset) {
        medicationName = preset.name
        medicationDosageUnit = preset.dosageUnit
        didApplySuggestedMedicationDose = false
        medicationDosageAmount = ""
        applySuggestedMedicationDoseIfNeeded(force: true)
        if medicationDosageAmount.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            medicationDosageAmount = String(format: "%.1f", preset.dosageValue)
            syncMedicationDosageAdjustment()
        }
    }

    private func microAdjustButtons(minusAction: @escaping () -> Void, plusAction: @escaping () -> Void) -> some View {
        HStack(spacing: 12) {
            Button(action: minusAction) {
                Label("减", systemImage: "minus.circle.fill")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)

            Button(action: plusAction) {
                Label("加", systemImage: "plus.circle.fill")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }
}
