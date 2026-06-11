import CoreData
import Combine
import SwiftUI

private enum QuickLogTimelineRecord: Identifiable {
    case feeding(FeedingRecord)
    case excretion(ExcretionRecord)

    var id: NSManagedObjectID {
        switch self {
        case .feeding(let record):
            return record.objectID
        case .excretion(let record):
            return record.objectID
        }
    }

    var recordedAt: Date {
        switch self {
        case .feeding(let record):
            return record.startedAt
        case .excretion(let record):
            return record.recordedAt
        }
    }
}

private struct QuickLogTimelineDayGroup: Identifiable {
    let day: Date
    let records: [QuickLogTimelineRecord]

    var id: Date { day }
}

private enum QuickLogTimelineFilter: String, CaseIterable, Identifiable {
    case all
    case feeding
    case poop
    case pee

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .all:
            return "全部"
        case .feeding:
            return "奶"
        case .poop:
            return "屎"
        case .pee:
            return "尿"
        }
    }
}

struct QuickLogView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var managedObjectContext
    @EnvironmentObject private var feedingAlarmController: FeedingAlarmController
    @FetchRequest(sortDescriptors: [SortDescriptor(\FeedingRecord.startedAt, order: .reverse)]) private var feedings: FetchedResults<FeedingRecord>
    @FetchRequest(sortDescriptors: [SortDescriptor(\WeightRecord.recordedAt, order: .reverse)]) private var weights: FetchedResults<WeightRecord>
    @FetchRequest(sortDescriptors: [SortDescriptor(\MedicationRecord.recordedAt, order: .reverse)]) private var medications: FetchedResults<MedicationRecord>
    @FetchRequest(sortDescriptors: [SortDescriptor(\BloodGlucoseRecord.recordedAt, order: .reverse)]) private var bloodGlucoses: FetchedResults<BloodGlucoseRecord>
    @FetchRequest(sortDescriptors: [SortDescriptor(\ExcretionRecord.recordedAt, order: .reverse)]) private var excretions: FetchedResults<ExcretionRecord>
    @AppStorage("feedingOverdueAlarmEnabled") private var feedingOverdueAlarmEnabled = false
    @AppStorage("feedingOverdueDelayMinutes") private var feedingOverdueDelayMinutes = 180

    @State private var recordType: RecordType = .feeding

    @State private var feedingStartedAt = Date()
    @State private var feedingFormulaStartedAt = Date().addingTimeInterval(10 * 60)
    @State private var feedingEndedAt = Date().addingTimeInterval(15 * 60)
    @State private var feedingType: FeedingType = .formula
    @State private var feedingAmount = ""
    @State private var feedingNote = ""
    @State private var didApplySuggestedFeedingAmount = false
    @State private var didApplySuggestedFeedingDuration = false
    @State private var feedingDurationAdjustment: Double = 0
    @State private var activeFeedingStartedAt: Date?
    @State private var activeFormulaStartedAt: Date?
    @State private var activeFeedingNow = Date()

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
    @State private var excretionRecordedAt = Date()
    @State private var excretionType: ExcretionType = .poop
    @State private var excretionNote = ""
    @State private var quickLogTimelineFilter: QuickLogTimelineFilter = .all

    private let showsTypePicker: Bool
    private let isFeedingOnlyMode: Bool
    private let feedingSessionTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private let feedingAmountShortcuts = [30, 60, 90]

    init(initialRecordType: RecordType = .feeding, showsTypePicker: Bool = true) {
        _recordType = State(initialValue: initialRecordType)
        self.showsTypePicker = showsTypePicker
        self.isFeedingOnlyMode = initialRecordType == .feeding && showsTypePicker
    }

    var body: some View {
        NavigationStack {
            Group {
                if usesWideQuickLogLayout {
                    wideQuickLogLayout
                } else {
                    quickLogForm
                }
            }
            .onReceive(feedingSessionTimer) { date in
                activeFeedingNow = date
            }
            .onAppear {
                activeFeedingNow = Date()
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .environment(\.locale, Locale(identifier: "zh_CN"))
            .toolbar {
                if !isFeedingOnlyMode {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("取消") {
                            dismiss()
                        }
                    }
                }

                if !isFeedingOnlyMode {
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
        .presentationDetents(horizontalSizeClass == .regular ? [.large] : [.medium, .large])
    }

    private var usesWideQuickLogLayout: Bool {
        isFeedingOnlyMode && (horizontalSizeClass == .regular || verticalSizeClass == .compact)
    }

    private var quickLogForm: some View {
        Form {
            if isFeedingOnlyMode {
                if activeFeedingStartedAt == nil {
                    feedingStartPrompt
                } else {
                    activeFeedingForm
                }
                excretionQuickLogSection
                quickLogTimelineList
            } else {
                if showsTypePicker {
                    Section("记录类型") {
                        recordTypeCardPicker
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
                case .excretion:
                    excretionForm
                }
            }
        }
        .adaptiveContentWidth(horizontalSizeClass == .regular ? 760 : .infinity)
    }

    private var wideQuickLogLayout: some View {
        ScrollView {
            HStack(alignment: .top, spacing: 16) {
                VStack(spacing: 16) {
                    if activeFeedingStartedAt == nil {
                        quickLogCard(title: "喂奶") {
                            feedingStartPromptContent
                        }
                    } else {
                        quickLogCard(title: "正在喂奶") {
                            activeFeedingCompactContent
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .top)

                VStack(spacing: 16) {
                    quickLogCard(title: "屎尿") {
                        excretionQuickLogButtons
                    }

                    quickLogCard(title: "今天记录") {
                        quickLogTimelineRows(showsDeleteButton: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .top)
            }
            .padding(16)
            .adaptiveContentWidth(980)
        }
        .background(Color(.systemGroupedBackground))
    }

    private func quickLogCard<Content: View>(
        title: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title {
                Text(title)
                    .font(.headline)
            }
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var navigationTitle: String {
        if isFeedingOnlyMode {
            return "快速记录"
        }

        return showsTypePicker ? "快速记录" : "\(recordType.displayName)记录"
    }

    private var latestFormulaAmountML: Int? {
        feedings.compactMap { record in
            guard let amountML = record.amountMLValue else { return nil }
            return Int(amountML)
        }.first
    }

    private var latestBreastDurationMinutes: Int? {
        feedings.compactMap { record in
            record.breastDurationMinutes
        }.first
    }

    private var latestFeedingReminderDate: Date? {
        feedings.first.map { $0.endedAt ?? $0.startedAt }
    }

    private var previousFeedingIntervalText: String {
        feedingIntervalText(startDate: feedingStartedAt, emptyText: "还没有更早的喂奶记录")
    }

    private var currentFeedingIntervalText: String {
        feedingIntervalText(startDate: activeFeedingNow, emptyText: "还没有喂奶记录")
    }

    private var nextFeedingAlarmDate: Date? {
        guard feedingOverdueAlarmEnabled, let latestFeedingReminderDate else { return nil }
        if let nextReminderDate = feedingAlarmController.nextReminderDate {
            return nextReminderDate
        }

        return Calendar.current.date(
            byAdding: .minute,
            value: feedingOverdueDelayMinutes,
            to: latestFeedingReminderDate
        )
    }

    private var nextFeedingAlarmCountdownText: String {
        guard let nextFeedingAlarmDate else { return "--" }

        let remainingSeconds = Int(nextFeedingAlarmDate.timeIntervalSince(activeFeedingNow))
        if remainingSeconds <= 0 {
            return "已超时"
        }

        return countdownText(seconds: remainingSeconds)
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

    private var quickLogTimelineDayGroups: [QuickLogTimelineDayGroup] {
        let calendar = Calendar.current
        let records = quickLogTimelineRecords
        let groups = Dictionary(grouping: records) { record in
            calendar.startOfDay(for: record.recordedAt)
        }

        return groups.keys.sorted(by: >).map { day in
            QuickLogTimelineDayGroup(
                day: day,
                records: (groups[day] ?? []).sorted { $0.recordedAt > $1.recordedAt }
            )
        }
    }

    private var quickLogTimelineRecords: [QuickLogTimelineRecord] {
        let calendar = Calendar.current
        let feedingRecords = feedings
            .prefix { calendar.isDateInToday($0.startedAt) }
            .map(QuickLogTimelineRecord.feeding)
        let excretionRecords = excretions
            .prefix { calendar.isDateInToday($0.recordedAt) }
            .map(QuickLogTimelineRecord.excretion)

        return (feedingRecords + excretionRecords)
            .filter { quickLogTimelineRecord($0, matches: quickLogTimelineFilter) }
            .sorted { $0.recordedAt > $1.recordedAt }
    }

    private func quickLogTimelineRecord(
        _ record: QuickLogTimelineRecord,
        matches filter: QuickLogTimelineFilter
    ) -> Bool {
        switch (record, filter) {
        case (_, .all):
            return true
        case (.feeding, .feeding):
            return true
        case (.excretion(let excretion), .poop):
            return excretion.type == .poop
        case (.excretion(let excretion), .pee):
            return excretion.type == .pee
        default:
            return false
        }
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

    private var isMixedFeeding: Bool {
        feedingType == .mixed
    }

    private var hasFeedingAmount: Bool {
        Double(feedingAmount.trimmingCharacters(in: .whitespacesAndNewlines)) != nil
    }

    private var compactRecordTypeColumns: [GridItem] {
        let count = horizontalSizeClass == .regular ? 3 : 2
        return Array(repeating: GridItem(.flexible(), spacing: 10), count: count)
    }

    private var recordTypeCardPicker: some View {
        VStack(spacing: 10) {
            recordTypeCard(for: .feeding, isPrimary: true)

            LazyVGrid(columns: compactRecordTypeColumns, spacing: 10) {
                ForEach(RecordType.allCases.filter { $0 != .feeding }) { type in
                    recordTypeCard(for: type, isPrimary: false)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func recordTypeCard(for type: RecordType, isPrimary: Bool) -> some View {
        let isSelected = recordType == type
        let tint = recordTypeTint(for: type)

        return Button {
            recordType = type
        } label: {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: type.symbol)
                    .font(isPrimary ? .title2.weight(.semibold) : .headline.weight(.semibold))
                    .foregroundStyle(isSelected ? .white : tint)
                    .frame(width: isPrimary ? 42 : 34, height: isPrimary ? 42 : 34)
                    .background(isSelected ? Color.white.opacity(0.18) : tint.opacity(0.14))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(type.displayName)
                        .font(isPrimary ? .headline : .subheadline.weight(.semibold))
                    Text(recordTypeSubtitle(for: type))
                        .font(.caption)
                        .foregroundStyle(isSelected ? .white.opacity(0.86) : .secondary)
                        .lineLimit(2)
                }

                if isPrimary {
                    Spacer()
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "arrow.right.circle")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(isSelected ? .white : tint)
                }
            }
            .frame(maxWidth: .infinity, minHeight: isPrimary ? 82 : 68, alignment: .leading)
            .padding(.horizontal, isPrimary ? 16 : 12)
            .padding(.vertical, isPrimary ? 14 : 10)
            .background(isSelected ? tint : Color(.secondarySystemBackground))
            .foregroundStyle(isSelected ? .white : .primary)
            .overlay(
                RoundedRectangle(cornerRadius: isPrimary ? 18 : 14, style: .continuous)
                    .stroke(isSelected ? tint.opacity(0.35) : tint.opacity(0.22), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: isPrimary ? 18 : 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func recordTypeSubtitle(for type: RecordType) -> String {
        switch type {
        case .feeding:
            return feedings.first.map { "最近 \(DateDisplay.time($0.startedAt))" } ?? "主要记录，快速填写喂养方式和奶量"
        case .weight:
            return weights.first.map { "最近 \(WeightDisplay.jinText(fromKG: $0.weightKG))" } ?? "记录孕期体重"
        case .medication:
            return medications.first.map { "最近 \($0.name)" } ?? "记录药名和剂量"
        case .checkup:
            return "记录产检和检查结果"
        case .fetalMovement:
            return "记录胎动次数和时长"
        case .bloodGlucose:
            return bloodGlucoses.first.map { "最近 \(String(format: "%.1f", $0.valueMMOL)) mmol/L" } ?? "记录餐前餐后血糖"
        case .excretion:
            return excretions.first.map { "最近 \($0.type.displayName)" } ?? "记录拉屎和撒尿"
        }
    }

    private func recordTypeTint(for type: RecordType) -> Color {
        switch type {
        case .feeding:
            return .pink
        case .weight:
            return .orange
        case .medication:
            return .blue
        case .checkup:
            return .green
        case .fetalMovement:
            return .mint
        case .bloodGlucose:
            return .red
        case .excretion:
            return .brown
        }
    }

    private var feedingForm: some View {
        Group {
            Section("喂奶信息") {
                DatePicker("开始时间", selection: $feedingStartedAt)
                feedingIntervalHighlight(previousFeedingIntervalText)
                feedingTypePicker
                if isMixedFeeding {
                    DatePicker(
                        "奶粉开始时间",
                        selection: $feedingFormulaStartedAt,
                        in: feedingStartedAt...
                    )
                }
                DatePicker("结束时间", selection: $feedingEndedAt)
                formulaAmountPicker

                TextField("备注", text: $feedingNote, axis: .vertical)
                    .lineLimit(2...4)
            }
        }
        .onAppear {
            applySuggestedFeedingAmountIfNeeded()
        }
        .onChange(of: feedingType) { _ in
            activeFormulaStartedAt = nil
            feedingDurationAdjustment = 0
            applySuggestedFeedingAmountIfNeeded(force: true)
        }
    }

    private var feedingStartPrompt: some View {
        Section("喂奶") {
            feedingStartPromptContent
                .padding(.vertical, 6)
        }
    }

    private var feedingStartPromptContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "drop.fill")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.pink)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text("点击喂奶卡片开始计时")
                        .font(.headline)
                    Text("开始后只需要等喂奶结束，再填写奶量并保存。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            feedingIntervalHighlight(currentFeedingIntervalText)

            Button {
                startFeedingSession()
            } label: {
                Label("开始喂奶", systemImage: "play.circle.fill")
                    .font(.title3.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 58)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(.pink)

            nextFeedingAlarmStatus
        }
    }

    private func feedingIntervalHighlight(_ value: String) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "clock.fill")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.pink)
                .frame(width: 42, height: 42)
                .background(Color.pink.opacity(0.14))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text("距离上次喂奶")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.78)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.pink.opacity(0.08))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.pink.opacity(0.18), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var feedingTypePicker: some View {
        HStack(spacing: 10) {
            ForEach(FeedingType.allCases) { type in
                feedingTypeButton(type)
            }
        }
    }

    private func feedingTypeButton(_ type: FeedingType) -> some View {
        let isSelected = feedingType == type
        let tint = feedingTypeTint(for: type)

        return Button {
            feedingType = type
        } label: {
            HStack(spacing: 8) {
                Image(systemName: type == .formula ? "waterbottle.fill" : "drop.degreesign.fill")
                    .font(.title3.weight(.semibold))
                Text(type.displayName)
                    .font(.headline.weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(isSelected ? tint : tint.opacity(0.12))
            .foregroundStyle(isSelected ? .white : tint)
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(tint.opacity(isSelected ? 0.38 : 0.22), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func feedingTypeTint(for type: FeedingType) -> Color {
        switch type {
        case .formula:
            return .blue
        case .mixed:
            return .orange
        }
    }

    private var excretionQuickLogSection: some View {
        Section("屎尿") {
            excretionQuickLogButtons
                .padding(.vertical, 4)
        }
    }

    private var excretionQuickLogButtons: some View {
        HStack(spacing: 12) {
            quickExcretionButton(
                title: "屎",
                systemImage: "toilet.fill",
                tint: .brown,
                type: .poop
            )

            quickExcretionButton(
                title: "尿",
                systemImage: "drop.fill",
                tint: .yellow,
                type: .pee
            )
        }
    }

    @ViewBuilder
    private var quickLogTimelineList: some View {
        Section("今天记录") {
            quickLogTimelineFilterPicker

            if quickLogTimelineDayGroups.isEmpty {
                emptyQuickLogTimelineText
            }
        }

        if !quickLogTimelineDayGroups.isEmpty {
            ForEach(quickLogTimelineDayGroups) { group in
                Section(quickLogTimelineDayTitle(for: group)) {
                    ForEach(group.records) { record in
                        quickLogTimelineRow(record, showsDeleteButton: false)
                    }
                }
            }
        }
    }

    private var quickLogTimelineFilterPicker: some View {
        Picker("筛选", selection: $quickLogTimelineFilter) {
            ForEach(QuickLogTimelineFilter.allCases) { filter in
                Text(filter.displayName).tag(filter)
            }
        }
        .pickerStyle(.segmented)
    }

    private func quickLogTimelineRows(showsDeleteButton: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            quickLogTimelineFilterPicker

            if quickLogTimelineDayGroups.isEmpty {
                emptyQuickLogTimelineText
            } else {
                ForEach(quickLogTimelineDayGroups) { group in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(quickLogTimelineDayTitle(for: group))
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.top, 2)

                        ForEach(group.records) { record in
                            quickLogTimelineRow(record, showsDeleteButton: showsDeleteButton)
                        }
                    }
                }
            }
        }
    }

    private var emptyQuickLogTimelineText: some View {
        Text(emptyQuickLogTimelineMessage)
            .font(.footnote)
            .foregroundStyle(.secondary)
    }

    private var emptyQuickLogTimelineMessage: String {
        switch quickLogTimelineFilter {
        case .all:
            return "今天的喂奶、屎或尿记录会出现在这里。"
        case .feeding:
            return "今天还没有喂奶记录。"
        case .poop:
            return "今天还没有屎记录。"
        case .pee:
            return "今天还没有尿记录。"
        }
    }

    private func quickLogTimelineDayTitle(for group: QuickLogTimelineDayGroup) -> String {
        let calendar = Calendar.current
        let feedingCount = group.records.filter { record in
            if case .feeding = record { return true }
            return false
        }.count
        let poopCount = group.records.filter { record in
            if case .excretion(let excretion) = record { return excretion.type == .poop }
            return false
        }.count
        let peeCount = group.records.filter { record in
            if case .excretion(let excretion) = record { return excretion.type == .pee }
            return false
        }.count
        let summary = "奶 \(feedingCount) 次 · 屎 \(poopCount) 次 · 尿 \(peeCount) 次"

        if calendar.isDateInToday(group.day) {
            return "今天 · \(summary)"
        }

        if calendar.isDateInYesterday(group.day) {
            return "昨天 · \(summary)"
        }

        return "\(DateDisplay.shortDate(group.day)) · \(summary)"
    }

    @ViewBuilder
    private func quickLogTimelineRow(_ record: QuickLogTimelineRecord, showsDeleteButton: Bool) -> some View {
        switch record {
        case .feeding(let record):
            feedingQuickLogRow(record)
        case .excretion(let record):
            excretionQuickLogRow(record, showsDeleteButton: showsDeleteButton)
        }
    }

    private func feedingQuickLogRow(_ record: FeedingRecord) -> some View {
        let tint = record.feedingType == .mixed ? Color.orange : Color.blue

        return HStack(spacing: 12) {
            Image(systemName: record.feedingType == .mixed ? "drop.degreesign.fill" : "waterbottle.fill")
                .font(.headline.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 34, height: 34)
                .background(tint.opacity(0.14))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(record.feedingType.displayName)
                        .font(.subheadline.weight(.semibold))

                    Spacer(minLength: 8)

                    Text(feedingQuickLogAmountText(for: record))
                        .font(.headline.weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(tint)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(tint.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(feedingQuickLogTimingDetail(for: record))
                        .lineLimit(2)

                    if let intervalText = feedingQuickLogIntervalText(for: record) {
                        Text("间隔 \(intervalText)")
                    }
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
                .minimumScaleFactor(0.82)
            }
        }
        .padding(.vertical, 4)
    }

    private func feedingQuickLogAmountText(for record: FeedingRecord) -> String {
        guard let amountML = record.amountMLValue else { return "未填奶量" }
        return "\(Int(amountML)) ml"
    }

    private func feedingQuickLogTimingDetail(for record: FeedingRecord) -> String {
        var parts = [DateDisplay.time(record.startedAt)]
        if record.feedingType == .mixed {
            if let breastDurationMinutes = record.breastDurationMinutes {
                parts.append("母乳 \(breastDurationMinutes) 分")
            }
            if let formulaDurationMinutes = record.formulaDurationMinutes {
                parts.append("奶粉 \(formulaDurationMinutes) 分")
            }
        } else if let durationMinutes = record.durationMinutes {
            parts.append("\(durationMinutes) 分")
        }
        return parts.joined(separator: " · ")
    }

    private func feedingQuickLogIntervalText(for record: FeedingRecord) -> String? {
        guard let previousFeedingStartDate = previousFeedingStartDate(before: record.startedAt) else {
            return nil
        }

        let seconds = Int(record.startedAt.timeIntervalSince(previousFeedingStartDate))
        return durationText(seconds: seconds)
    }

    private func excretionQuickLogRow(_ record: ExcretionRecord, showsDeleteButton: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: record.type == .poop ? "toilet.fill" : "drop.fill")
                .font(.headline.weight(.semibold))
                .foregroundStyle(record.type == .poop ? Color.brown : Color.yellow)
                .frame(width: 34, height: 34)
                .background((record.type == .poop ? Color.brown : Color.yellow).opacity(0.14))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(record.type.displayName)
                    .font(.subheadline.weight(.semibold))
                Text(DateDisplay.time(record.recordedAt))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if showsDeleteButton {
                Button(role: .destructive) {
                    deleteExcretionRecord(record)
                } label: {
                    Image(systemName: "trash")
                        .font(.headline)
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(.vertical, 4)
        .swipeActions {
            Button("删除", role: .destructive) {
                deleteExcretionRecord(record)
            }
        }
    }

    private func quickExcretionButton(
        title: String,
        systemImage: String,
        tint: Color,
        type: ExcretionType
    ) -> some View {
        Button {
            saveQuickExcretion(type)
        } label: {
            Label(title, systemImage: systemImage)
                .font(.title3.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(tint.opacity(0.16))
                .foregroundStyle(tint)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var nextFeedingAlarmStatus: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: feedingOverdueAlarmEnabled ? "bell.and.waves.left.and.right.fill" : "bell.slash")
                .font(.headline.weight(.semibold))
                .foregroundStyle(feedingOverdueAlarmEnabled ? Color.pink : Color.secondary)
                .frame(width: 34, height: 34)
                .background((feedingOverdueAlarmEnabled ? Color.pink : Color.secondary).opacity(0.12))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 5) {
                if !feedingOverdueAlarmEnabled {
                    Text("喂奶闹钟未开启")
                        .font(.subheadline.weight(.semibold))
                    Text("可在设置里开启超时闹钟。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else if let nextFeedingAlarmDate {
                    HStack {
                        Text("下次闹钟")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Text(DateDisplay.dateTime(nextFeedingAlarmDate))
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("倒计时")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(nextFeedingAlarmCountdownText)
                            .font(.title3.monospacedDigit().weight(.bold))
                            .foregroundStyle(nextFeedingAlarmCountdownText == "已超时" ? Color.red : Color.primary)
                    }
                } else {
                    Text("还没有喂奶记录")
                        .font(.subheadline.weight(.semibold))
                    Text("保存第一次喂奶后会显示下次闹钟时间。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var activeFeedingForm: some View {
        Group {
            Section("正在喂奶") {
                activeFeedingCompactContent
                    .padding(.vertical, 4)
            }
        }
        .onAppear {
            applySuggestedFeedingAmountIfNeeded()
        }
        .onChange(of: feedingType) { _ in
            feedingDurationAdjustment = 0
            applySuggestedFeedingAmountIfNeeded(force: true)
        }
    }

    private var activeFeedingCompactContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            activeFeedingStatusContent
            feedingTypePicker
            formulaAmountPicker
            activeFeedingActionsContent
        }
    }

    private var activeFeedingStatusContent: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 4) {
                Image(systemName: activeFeedingStatusIconName)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(Color.pink)
                    .clipShape(Circle())

                Text(activeFeedingStageText)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.pink)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(activeFeedingElapsedText)
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .monospacedDigit()
                    Spacer()
                    Text(activeFeedingStartedAt.map { DateDisplay.time($0) } ?? "--:--")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.secondary)
                }

                if isMixedFeeding {
                    HStack(spacing: 8) {
                        compactStageBadge("母乳", value: activeBreastDurationText)
                        compactStageBadge("奶粉", value: activeFormulaDurationText)
                    }

                    Text(activeFormulaStartedAt.map { "奶粉开始 \(DateDisplay.time($0))" } ?? "母乳喂完后点“母乳喂完”，开始奶粉计时。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                        .frame(height: 18, alignment: .leading)
                } else {
                    Text("开始于 \(activeFeedingStartedAt.map { DateDisplay.time($0) } ?? "--:--")")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(height: 18, alignment: .leading)
                }
            }
        }
        .frame(height: 112, alignment: .top)
        .padding(12)
        .background(Color.pink.opacity(0.08))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.pink.opacity(0.18), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var activeFeedingActionsContent: some View {
        HStack(spacing: 10) {
            if isMixedFeeding && activeFormulaStartedAt == nil {
                Button {
                    startFormulaStage()
                } label: {
                    Label("母乳喂完", systemImage: "forward.end.circle.fill")
                        .font(.title3.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 52)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(.pink)
            } else {
                Button {
                    finishActiveFeedingSession()
                } label: {
                    Label("结束并保存", systemImage: "checkmark.circle.fill")
                        .font(.title3.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 52)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(.pink)
                .disabled(!canFinishActiveFeeding)
            }

            Button(role: .destructive) {
                cancelActiveFeedingSession()
            } label: {
                Image(systemName: "xmark")
                    .font(.headline.weight(.semibold))
                    .frame(width: 44, height: 52)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
    }

    private func compactStageBadge(_ title: String, value: String) -> some View {
        HStack(spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.monospacedDigit().weight(.bold))
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
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
        let selectedAmount = currentFeedingAmountML

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("奶量")
                    .font(.subheadline.weight(.medium))
                Spacer()
                Text(feedingSuggestionTitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(columns: feedingAmountShortcutColumns, spacing: 8) {
                ForEach(feedingAmountShortcuts, id: \.self) { amount in
                    feedingAmountShortcutButton(amount, selectedAmount: selectedAmount)
                }
            }

            feedingAmountDisplay
            feedingAmountAdjustButton
        }
    }

    private var feedingAmountShortcutColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)
    }

    private func feedingAmountShortcutButton(_ amount: Int, selectedAmount: Int?) -> some View {
        let isSelected = selectedAmount == amount

        return Button {
            feedingAmount = "\(amount)"
        } label: {
            Text("\(amount)")
                .font(.headline.weight(.bold))
                .frame(maxWidth: .infinity, minHeight: 42)
                .background(isSelected ? Color.pink : Color.pink.opacity(0.12))
                .foregroundStyle(isSelected ? .white : Color.pink)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var feedingAmountDisplay: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text("当前奶量")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)

            Spacer()

            Text(feedingAmountDisplayText)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.78)
            Text("ml")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.pink.opacity(0.08))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.pink.opacity(0.18), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var feedingAmountAdjustButton: some View {
        HStack(spacing: 0) {
            Button {
                adjustFeedingAmount(by: -5)
            } label: {
                Label("减 5", systemImage: "minus")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 40)
            }
            .buttonStyle(.plain)

            Rectangle()
                .fill(Color.pink.opacity(0.18))
                .frame(width: 1, height: 24)

            Button {
                adjustFeedingAmount(by: 5)
            } label: {
                Label("加 5", systemImage: "plus")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 40)
            }
            .buttonStyle(.plain)
        }
        .foregroundStyle(Color.pink)
        .background(Color.pink.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
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

    private var excretionForm: some View {
        Group {
            Section("屎尿信息") {
                DatePicker("记录时间", selection: $excretionRecordedAt)
                Picker("类型", selection: $excretionType) {
                    ForEach(ExcretionType.allCases) { type in
                        Text(type.displayName).tag(type)
                    }
                }
                .pickerStyle(.segmented)
                TextField("备注", text: $excretionNote, axis: .vertical)
                    .lineLimit(2...4)
            }
        }
    }

    private var canSave: Bool {
        switch recordType {
        case .feeding:
            if isMixedFeeding {
                return feedingFormulaStartedAt >= feedingStartedAt &&
                    feedingEndedAt >= feedingFormulaStartedAt &&
                    hasFeedingAmount
            }
            return feedingEndedAt >= feedingStartedAt && hasFeedingAmount
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
        case .excretion:
            return true
        }
    }

    private var canFinishActiveFeeding: Bool {
        guard activeFeedingStartedAt != nil else { return false }
        if isMixedFeeding {
            return activeFormulaStartedAt != nil && hasFeedingAmount
        }
        return hasFeedingAmount
    }

    private var activeFeedingElapsedText: String {
        guard let activeFeedingStartedAt else { return "00:00" }

        let stageStartedAt = activeFormulaStartedAt ?? activeFeedingStartedAt
        let seconds = max(Int(activeFeedingNow.timeIntervalSince(stageStartedAt)), 0)
        return countdownText(seconds: seconds)
    }

    private var activeFeedingStageText: String {
        if isMixedFeeding {
            return activeFormulaStartedAt == nil ? "母乳阶段" : "奶粉阶段"
        }
        return "奶粉计时"
    }

    private var activeFeedingStatusIconName: String {
        if isMixedFeeding, activeFormulaStartedAt == nil {
            return "drop.fill"
        }
        return "timer"
    }

    private var activeBreastDurationText: String {
        guard let activeFeedingStartedAt else { return "等待开始" }
        let endDate = activeFormulaStartedAt ?? activeFeedingNow
        let seconds = max(Int(endDate.timeIntervalSince(activeFeedingStartedAt)), 0)
        return durationText(seconds: seconds)
    }

    private var activeFormulaDurationText: String {
        guard let activeFormulaStartedAt else { return "--" }
        let seconds = max(Int(activeFeedingNow.timeIntervalSince(activeFormulaStartedAt)), 0)
        return durationText(seconds: seconds)
    }

    private func countdownText(seconds: Int) -> String {
        let seconds = max(seconds, 0)
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let remainingSeconds = seconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, remainingSeconds)
        }
        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }

    private func feedingIntervalText(startDate: Date, emptyText: String) -> String {
        guard let previousFeedingStartDate = previousFeedingStartDate(before: startDate) else {
            return emptyText
        }

        let seconds = Int(startDate.timeIntervalSince(previousFeedingStartDate))
        return durationText(seconds: seconds)
    }

    private func previousFeedingStartDate(before startDate: Date) -> Date? {
        feedings
            .map(\.startedAt)
            .first { $0 < startDate }
    }

    private func durationText(seconds: Int) -> String {
        let seconds = max(seconds, 0)
        let days = seconds / 86_400
        let hours = (seconds % 86_400) / 3600
        let minutes = (seconds % 3600) / 60
        let remainingSeconds = seconds % 60

        if days > 0 {
            return "\(days)天\(hours)小时\(minutes)分钟\(remainingSeconds)秒"
        }
        if hours > 0 {
            return "\(hours)小时\(minutes)分钟\(remainingSeconds)秒"
        }
        if minutes > 0 {
            return "\(minutes)分钟\(remainingSeconds)秒"
        }
        return "\(remainingSeconds)秒"
    }

    private func startFeedingSession() {
        guard activeFeedingStartedAt == nil else { return }
        let now = Date()
        feedingStartedAt = now
        feedingFormulaStartedAt = now
        feedingEndedAt = now
        activeFeedingStartedAt = now
        activeFormulaStartedAt = nil
        activeFeedingNow = now
        feedingDurationAdjustment = 0
        applySuggestedFeedingAmountIfNeeded(force: true)
    }

    private func startFormulaStage() {
        guard isMixedFeeding, activeFeedingStartedAt != nil, activeFormulaStartedAt == nil else { return }
        let now = Date()
        activeFormulaStartedAt = now
        feedingFormulaStartedAt = now
        activeFeedingNow = now
        applySuggestedFeedingAmountIfNeeded(force: true)
    }

    private func finishActiveFeedingSession() {
        guard let startedAt = activeFeedingStartedAt, canFinishActiveFeeding else { return }
        let endedAt = Date()

        _ = FeedingRecord(
            context: managedObjectContext,
            startedAt: startedAt,
            endedAt: endedAt,
            formulaStartedAt: isMixedFeeding ? activeFormulaStartedAt : nil,
            feedingType: feedingType,
            amountML: Double(feedingAmount.trimmingCharacters(in: .whitespacesAndNewlines)),
            note: feedingNote
        )

        try? managedObjectContext.save()
        resetActiveFeedingSession()
        dismiss()
    }

    private func cancelActiveFeedingSession() {
        resetActiveFeedingSession()
    }

    private func resetActiveFeedingSession() {
        activeFeedingStartedAt = nil
        activeFormulaStartedAt = nil
        activeFeedingNow = Date()
        feedingStartedAt = Date()
        feedingFormulaStartedAt = Date().addingTimeInterval(10 * 60)
        feedingEndedAt = Date().addingTimeInterval(15 * 60)
        feedingNote = ""
        feedingDurationAdjustment = 0
        didApplySuggestedFeedingAmount = false
        didApplySuggestedFeedingDuration = false
    }

    private func saveQuickExcretion(_ type: ExcretionType) {
        _ = ExcretionRecord(
            context: managedObjectContext,
            recordedAt: Date(),
            type: type,
            note: ""
        )
        try? managedObjectContext.save()
    }

    private func deleteExcretionRecord(_ record: ExcretionRecord) {
        managedObjectContext.delete(record)
        try? managedObjectContext.save()
    }

    private func saveRecord() {
        switch recordType {
        case .feeding:
            _ = FeedingRecord(
                context: managedObjectContext,
                startedAt: feedingStartedAt,
                endedAt: feedingEndedAt,
                formulaStartedAt: isMixedFeeding ? feedingFormulaStartedAt : nil,
                feedingType: feedingType,
                amountML: Double(feedingAmount.trimmingCharacters(in: .whitespacesAndNewlines)),
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

        case .excretion:
            _ = ExcretionRecord(
                context: managedObjectContext,
                recordedAt: excretionRecordedAt,
                type: excretionType,
                note: excretionNote
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

    private var breastDurationSliderLimit: Int {
        max(10, suggestedBreastDurationMinutes)
    }

    private var weightSliderLimitJin: Double {
        let baseLimit = 5.0
        guard let weight = Double(weightKG) else { return baseLimit }
        return max(baseLimit, abs(weight - suggestedWeightJin))
    }

    private var currentFeedingAmountML: Int? {
        guard let amount = Double(feedingAmount.trimmingCharacters(in: .whitespacesAndNewlines)) else { return nil }
        return max(Int(amount.rounded()), 0)
    }

    private var feedingAmountDisplayText: String {
        guard let currentFeedingAmountML else { return "--" }
        return "\(currentFeedingAmountML)"
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
        guard force || !didApplySuggestedFeedingAmount else { return }
        guard force || feedingAmount.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let defaultAmount = feedingAmountShortcuts.contains(suggestedFeedingAmountML) ? suggestedFeedingAmountML : 60
        feedingAmount = "\(defaultAmount)"
        didApplySuggestedFeedingAmount = true
    }

    private func applySuggestedFeedingDurationIfNeeded(force: Bool = false) {
        guard isMixedFeeding else { return }
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
        let current = currentFeedingAmountML ?? 60
        let updated = max(current + delta, 0)
        feedingAmount = "\(updated)"
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
