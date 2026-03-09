import CoreData
import SwiftUI

struct QuickLogView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var managedObjectContext
    @FetchRequest(sortDescriptors: [SortDescriptor(\FeedingRecord.startedAt, order: .reverse)]) private var feedings: FetchedResults<FeedingRecord>
    @FetchRequest(sortDescriptors: [SortDescriptor(\WeightRecord.recordedAt, order: .reverse)]) private var weights: FetchedResults<WeightRecord>
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
    @State private var bloodGlucoseRecordedAt = Date()
    @State private var bloodGlucoseMoment: BloodGlucoseMoment = .beforeBreakfast
    @State private var bloodGlucoseValue = ""
    @State private var bloodGlucoseNote = ""

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

                TextField("血糖（mmol/L）", text: $bloodGlucoseValue)
                    .keyboardType(.decimalPad)
                TextField("备注", text: $bloodGlucoseNote, axis: .vertical)
                    .lineLimit(2...4)

                if let latestBloodGlucoseMMOL {
                    Text("最近：\(String(format: "%.1f", latestBloodGlucoseMMOL)) mmol/L")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
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
                dosage: medicationDosage,
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

    private func syncWeightAdjustment() {
        guard let weight = Double(weightKG) else { return }
        let delta = weight - suggestedWeightJin
        isSyncingWeightFromText = true
        weightAdjustment = max(min(delta, weightSliderLimitJin), -weightSliderLimitJin)
        DispatchQueue.main.async {
            isSyncingWeightFromText = false
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
