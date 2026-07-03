import CoreData
import SwiftUI

private enum QuickLogTimelineRecord: Identifiable {
    case feeding(FeedingRecord, previousStartedAt: Date?)
    case excretion(ExcretionRecord)

    var id: NSManagedObjectID {
        switch self {
        case .feeding(let record, _):
            return record.objectID
        case .excretion(let record):
            return record.objectID
        }
    }

    var recordedAt: Date {
        switch self {
        case .feeding(let record, _):
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

private struct QuickPressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.86 : 1)
    }
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
    @FetchRequest private var feedings: FetchedResults<FeedingRecord>
    @FetchRequest private var weights: FetchedResults<WeightRecord>
    @FetchRequest private var medications: FetchedResults<MedicationRecord>
    @FetchRequest private var bloodGlucoses: FetchedResults<BloodGlucoseRecord>
    @FetchRequest private var excretions: FetchedResults<ExcretionRecord>

    @State private var recordType: RecordType = .feeding

    @State private var feedingStartedAt = Date()
    @State private var feedingEndedAt = Date().addingTimeInterval(15 * 60)
    @State private var feedingAmount = ""
    @State private var feedingNote = ""
    @State private var didApplySuggestedFeedingAmount = false

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
    @State private var quickLogTimelineDayOffset = 0
    @State private var quickLogSaveVersion = 0
    @State private var pendingFeedingRecordAmounts: [NSManagedObjectID: Int] = [:]
    @State private var pendingFeedingRecordAmountSaveVersions: [NSManagedObjectID: Int] = [:]

    private let showsTypePicker: Bool
    private let isFeedingOnlyMode: Bool
    private let feedingAmountShortcuts = [30, 60, 90, 120, 150, 180]
    private let quickLogTimelineDayOffsets = Array(0..<5)

    init(initialRecordType: RecordType = .feeding, showsTypePicker: Bool = true) {
        _recordType = State(initialValue: initialRecordType)
        self.showsTypePicker = showsTypePicker
        self.isFeedingOnlyMode = initialRecordType == .feeding && showsTypePicker

        _feedings = FetchRequest(fetchRequest: Self.batchedFetchRequest(
            FeedingRecord.fetchRequest(),
            sortedBy: NSSortDescriptor(keyPath: \FeedingRecord.startedAt, ascending: false)
        ))
        _weights = FetchRequest(fetchRequest: Self.batchedFetchRequest(
            WeightRecord.fetchRequest(),
            sortedBy: NSSortDescriptor(keyPath: \WeightRecord.recordedAt, ascending: false)
        ))
        _medications = FetchRequest(fetchRequest: Self.batchedFetchRequest(
            MedicationRecord.fetchRequest(),
            sortedBy: NSSortDescriptor(keyPath: \MedicationRecord.recordedAt, ascending: false)
        ))
        _bloodGlucoses = FetchRequest(fetchRequest: Self.batchedFetchRequest(
            BloodGlucoseRecord.fetchRequest(),
            sortedBy: NSSortDescriptor(keyPath: \BloodGlucoseRecord.recordedAt, ascending: false)
        ))
        _excretions = FetchRequest(fetchRequest: Self.batchedFetchRequest(
            ExcretionRecord.fetchRequest(),
            sortedBy: NSSortDescriptor(keyPath: \ExcretionRecord.recordedAt, ascending: false)
        ))
    }

    // 快速记录页只展示最近数据，分批加载避免一次性把全表拉进内存。
    private static func batchedFetchRequest<T: NSManagedObject>(
        _ request: NSFetchRequest<T>,
        sortedBy sortDescriptor: NSSortDescriptor
    ) -> NSFetchRequest<T> {
        request.sortDescriptors = [sortDescriptor]
        request.fetchBatchSize = 30
        return request
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
        .onDisappear {
            commitPendingFeedingRecordAmounts()
            saveManagedObjectContextIfNeeded()
        }
    }

    private var usesWideQuickLogLayout: Bool {
        isFeedingOnlyMode && (horizontalSizeClass == .regular || verticalSizeClass == .compact)
    }

    private var quickLogForm: some View {
        Form {
            if isFeedingOnlyMode {
                quickFeedingSection
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
        HStack(alignment: .top, spacing: 16) {
            // 左列单独滚动：iPhone 横屏放不下时可以滑，放得下时不滚不弹。
            nonBouncingScrollView {
                quickLogCard(title: "喂奶") {
                    quickFeedingContent
                }
            }
            .frame(maxWidth: .infinity)

            VStack(spacing: 16) {
                quickLogCard(title: "屎尿") {
                    excretionQuickLogButtons
                }

                quickLogCard(title: quickLogTimelineSectionTitle) {
                    quickLogTimelineRows(showsDeleteButton: true)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(16)
        .adaptiveContentWidth(980)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(.systemGroupedBackground))
    }

    @ViewBuilder
    private func nonBouncingScrollView<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        let scrollView = ScrollView(.vertical, showsIndicators: false) {
            content()
        }

        if #available(iOS 16.4, *) {
            scrollView.scrollBounceBehavior(.basedOnSize)
        } else {
            scrollView
        }
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
        for record in feedings {
            if let amountML = displayedFeedingRecordAmount(for: record) {
                return Int(amountML)
            }
        }

        return nil
    }

    private var previousFeedingIntervalText: String {
        feedingIntervalText(startDate: feedingStartedAt, emptyText: "还没有更早的喂奶记录")
    }

    private var suggestedFeedingAmountML: Int {
        latestFormulaAmountML ?? 60
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
        let records = quickLogTimelineRecords
        guard !records.isEmpty else { return [] }

        return [
            QuickLogTimelineDayGroup(
                day: selectedQuickLogTimelineDay,
                records: records
            )
        ]
    }

    private var quickLogTimelineRecords: [QuickLogTimelineRecord] {
        let calendar = Calendar.current
        let selectedDayStart = selectedQuickLogTimelineDay
        let selectedDayEnd = calendar.date(
            byAdding: .day,
            value: 1,
            to: selectedDayStart
        ) ?? selectedDayStart.addingTimeInterval(86_400)

        var records: [QuickLogTimelineRecord] = []

        // feedings 按开始时间倒序，扫到窗口之前即可停；上一次喂奶就是倒序里的下一条。
        var feedingIndex = feedings.startIndex
        while feedingIndex < feedings.endIndex {
            let record = feedings[feedingIndex]
            let startedAt = record.startedAt
            if startedAt < selectedDayStart {
                break
            }
            if startedAt < selectedDayEnd {
                let nextIndex = feedings.index(after: feedingIndex)
                let previousStartedAt = nextIndex < feedings.endIndex ? feedings[nextIndex].startedAt : nil
                records.append(.feeding(record, previousStartedAt: previousStartedAt))
            }
            feedingIndex = feedings.index(after: feedingIndex)
        }

        for record in excretions {
            let recordedAt = record.recordedAt
            if recordedAt < selectedDayStart {
                break
            }
            if recordedAt < selectedDayEnd {
                records.append(.excretion(record))
            }
        }

        return records
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

        if !trimmedName.isEmpty {
            for record in medications where record.name == trimmedName {
                if let dose = MedicationDose.parse(record.dosage) {
                    return dose
                }
            }
        }

        for record in medications {
            if let dose = MedicationDose.parse(record.dosage) {
                return dose
            }
        }

        return nil
    }

    private var suggestedMedicationDose: MedicationDose {
        latestMedicationDose ?? MedicationDose(amount: 1, unit: medicationDosageUnit)
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
                DatePicker("结束时间", selection: $feedingEndedAt)
                formulaAmountPicker

                TextField("备注", text: $feedingNote, axis: .vertical)
                    .lineLimit(2...4)
            }
        }
        .onAppear {
            applySuggestedFeedingAmountIfNeeded()
        }
    }

    private var quickFeedingSection: some View {
        Section("喂奶") {
            quickFeedingContent
                .padding(.vertical, 6)
        }
    }

    private var quickFeedingContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            liveFeedingStatus
            formulaAmountPicker
            quickFeedingButton

        }
        .onAppear {
            applySuggestedFeedingAmountIfNeeded()
        }
    }

    private var liveFeedingStatus: some View {
        SwiftUI.TimelineView(.periodic(from: Date(), by: 1)) { timeline in
            VStack(alignment: .leading, spacing: 12) {
                feedingIntervalHighlight(
                    feedingIntervalText(startDate: timeline.date, emptyText: "还没有喂奶记录")
                )
                recentThreeHourFeedingAmountStatus(now: timeline.date)
            }
        }
    }

    private func feedingIntervalHighlight(_ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("距离上次喂奶")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.primary)
                .lineLimit(2)
                .minimumScaleFactor(0.5)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.pink.opacity(0.08))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.pink.opacity(0.18), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
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
        let dayGroups = quickLogTimelineDayGroups

        Section(quickLogTimelineSectionTitle) {
            quickLogTimelineDayPicker
            quickLogTimelineFilterPicker

            if dayGroups.isEmpty {
                emptyQuickLogTimelineText
            }
        }

        if !dayGroups.isEmpty {
            ForEach(dayGroups) { group in
                Section(quickLogTimelineDayTitle(for: group)) {
                    ForEach(group.records) { record in
                        quickLogTimelineRow(record, showsDeleteButton: false)
                    }
                }
            }
        }
    }

    private var quickLogTimelineDayPicker: some View {
        Picker("日期", selection: $quickLogTimelineDayOffset) {
            ForEach(quickLogTimelineDayOffsets, id: \.self) { offset in
                Text(quickLogTimelineDayLabel(for: offset)).tag(offset)
            }
        }
        .pickerStyle(.segmented)
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
        let dayGroups = quickLogTimelineDayGroups

        return VStack(alignment: .leading, spacing: 10) {
            quickLogTimelineDayPicker
            quickLogTimelineFilterPicker

            if dayGroups.isEmpty {
                emptyQuickLogTimelineText
            } else {
                ScrollView(.vertical, showsIndicators: true) {
                    quickLogTimelineGroupedRows(dayGroups, showsDeleteButton: showsDeleteButton)
                        .padding(.trailing, 4)
                }
            }
        }
    }

    private func quickLogTimelineGroupedRows(
        _ dayGroups: [QuickLogTimelineDayGroup],
        showsDeleteButton: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(dayGroups) { group in
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

    private var emptyQuickLogTimelineText: some View {
        Text(emptyQuickLogTimelineMessage)
            .font(.footnote)
            .foregroundStyle(.secondary)
    }

    private var emptyQuickLogTimelineMessage: String {
        let dayLabel = quickLogTimelineDayLabel(for: quickLogTimelineDayOffset)

        switch quickLogTimelineFilter {
        case .all:
            return "\(dayLabel)的喂奶、屎或尿记录会出现在这里。"
        case .feeding:
            return "\(dayLabel)还没有喂奶记录。"
        case .poop:
            return "\(dayLabel)还没有屎记录。"
        case .pee:
            return "\(dayLabel)还没有尿记录。"
        }
    }

    private var quickLogTimelineSectionTitle: String {
        "\(quickLogTimelineDayLabel(for: quickLogTimelineDayOffset))记录"
    }

    private var selectedQuickLogTimelineDay: Date {
        quickLogTimelineDay(for: quickLogTimelineDayOffset)
    }

    private func quickLogTimelineDay(for offset: Int) -> Date {
        let calendar = Calendar.current
        let date = calendar.date(byAdding: .day, value: -offset, to: Date()) ?? Date()
        return calendar.startOfDay(for: date)
    }

    private func quickLogTimelineDayLabel(for offset: Int) -> String {
        switch offset {
        case 0:
            return "今天"
        case 1:
            return "昨天"
        case 2:
            return "前天"
        case 3:
            return "大前天"
        default:
            return DateDisplay.shortDate(quickLogTimelineDay(for: offset))
        }
    }

    private func quickLogTimelineDayTitle(for group: QuickLogTimelineDayGroup) -> String {
        let feedingCount = group.records.filter { record in
            if case .feeding = record { return true }
            return false
        }.count
        let feedingTotalAmountML = group.records.reduce(0.0) { total, record in
            guard case .feeding(let feeding, _) = record,
                  let amountML = displayedFeedingRecordAmount(for: feeding)
            else { return total }
            return total + amountML
        }
        let poopCount = group.records.filter { record in
            if case .excretion(let excretion) = record { return excretion.type == .poop }
            return false
        }.count
        let peeCount = group.records.filter { record in
            if case .excretion(let excretion) = record { return excretion.type == .pee }
            return false
        }.count
        let feedingTotalText = formatFeedingAmount(feedingTotalAmountML)
        let summary = "奶 \(feedingCount) 次 · 共 \(feedingTotalText) · 屎 \(poopCount) 次 · 尿 \(peeCount) 次"
        return "\(quickLogTimelineDayLabel(for: quickLogTimelineDayOffset)) · \(summary)"
    }

    @ViewBuilder
    private func quickLogTimelineRow(_ record: QuickLogTimelineRecord, showsDeleteButton: Bool) -> some View {
        switch record {
        case .feeding(let record, let previousStartedAt):
            feedingQuickLogRow(record, previousStartedAt: previousStartedAt, showsDeleteButton: showsDeleteButton)
        case .excretion(let record):
            excretionQuickLogRow(record, showsDeleteButton: showsDeleteButton)
        }
    }

    private func feedingQuickLogRow(_ record: FeedingRecord, previousStartedAt: Date?, showsDeleteButton: Bool) -> some View {
        let tint = Color.blue

        return HStack(alignment: .center, spacing: 12) {
            Image(systemName: "waterbottle.fill")
                .font(.headline.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 34, height: 34)
                .background(tint.opacity(0.14))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text("喂奶")
                    .font(.subheadline.weight(.semibold))

                VStack(alignment: .leading, spacing: 2) {
                    Text(feedingQuickLogTimingDetail(for: record))
                        .lineLimit(2)

                    if let previousStartedAt {
                        Text("间隔 \(durationText(seconds: Int(record.startedAt.timeIntervalSince(previousStartedAt))))")
                    }
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
                .minimumScaleFactor(0.82)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            feedingQuickLogAmountEditor(for: record, tint: tint)
                .fixedSize(horizontal: true, vertical: false)

            if showsDeleteButton {
                Button(role: .destructive) {
                    deleteFeedingRecord(record)
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
                deleteFeedingRecord(record)
            }
        }
    }

    private func feedingQuickLogAmountEditor(for record: FeedingRecord, tint: Color) -> some View {
        HStack(spacing: 6) {
            Button {
                adjustFeedingRecordAmount(record, by: -10)
            } label: {
                Image(systemName: "minus")
                    .font(.caption.weight(.bold))
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("减少奶量")

            Text(feedingQuickLogAmountText(for: record))
                .font(.headline.weight(.bold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .frame(minWidth: 64)

            Button {
                adjustFeedingRecordAmount(record, by: 10)
            } label: {
                Image(systemName: "plus")
                    .font(.caption.weight(.bold))
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("增加奶量")
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(tint.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func feedingQuickLogAmountText(for record: FeedingRecord) -> String {
        guard let amountML = displayedFeedingRecordAmount(for: record) else { return "未填奶量" }
        return formatFeedingAmount(amountML)
    }

    private func feedingQuickLogTimingDetail(for record: FeedingRecord) -> String {
        var parts = [DateDisplay.time(record.startedAt)]
        if let durationMinutes = record.durationMinutes {
            parts.append("\(durationMinutes) 分")
        }
        return parts.joined(separator: " · ")
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
        .buttonStyle(QuickPressButtonStyle())
    }

    private var quickFeedingButton: some View {
        Button {
            saveQuickFeeding()
        } label: {
            Label("喂奶", systemImage: "plus.circle.fill")
                .font(.title3.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(Color.pink.opacity(0.16))
                .foregroundStyle(Color.pink)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(QuickPressButtonStyle())
        .disabled(!hasFeedingAmount)
        .opacity(hasFeedingAmount ? 1 : 0.45)
    }

    private func recentThreeHourFeedingAmountStatus(now: Date) -> some View {
        let summary = recentThreeHourFeedingSummary(now: now)

        return HStack(alignment: .center, spacing: 12) {
            Image(systemName: "waterbottle.fill")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.pink)
                .frame(width: 34, height: 34)
                .background(Color.pink.opacity(0.12))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 5) {
                Text("3小时内喂奶量")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                HStack(alignment: .firstTextBaseline) {
                    Text(formatFeedingAmount(summary.totalAmountML))
                        .font(.title3.monospacedDigit().weight(.bold))
                    Spacer()
                    Text(summary.count > 0 ? "共 \(summary.count) 次" : "暂无记录")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
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
        .buttonStyle(QuickPressButtonStyle())
    }

    private var feedingAmountDisplay: some View {
        VStack(spacing: 4) {
            Text("当前奶量")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(feedingAmountDisplayText)
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                Text("ml")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .transaction { transaction in
                transaction.animation = nil
            }
        }
        .frame(maxWidth: .infinity, minHeight: 72, alignment: .center)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
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
            .buttonStyle(.borderless)

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
            .buttonStyle(.borderless)
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

    private func feedingIntervalText(startDate: Date, emptyText: String) -> String {
        guard let previousFeedingStartDate = previousFeedingStartDate(before: startDate) else {
            return emptyText
        }

        let seconds = Int(startDate.timeIntervalSince(previousFeedingStartDate))
        return durationText(seconds: seconds)
    }

    private func previousFeedingStartDate(before startDate: Date) -> Date? {
        feedings.first { record in
            record.startedAt < startDate
        }?.startedAt
    }

    private func recentThreeHourFeedingSummary(now: Date) -> (count: Int, totalAmountML: Double) {
        let windowStart = now.addingTimeInterval(-3 * 60 * 60)
        let windowEnd = now.addingTimeInterval(1)
        var count = 0
        var totalAmountML = 0.0

        for record in feedings {
            if record.startedAt < windowStart {
                break
            }
            guard record.startedAt <= windowEnd else { continue }
            count += 1
            totalAmountML += displayedFeedingRecordAmount(for: record) ?? 0
        }

        return (count, totalAmountML)
    }

    private func displayedFeedingRecordAmount(for record: FeedingRecord) -> Double? {
        if let pendingAmount = pendingFeedingRecordAmounts[record.objectID] {
            return Double(pendingAmount)
        }

        return record.amountMLValue
    }

    private func formatFeedingAmount(_ amountML: Double) -> String {
        if amountML.rounded() == amountML {
            return "\(Int(amountML)) ml"
        }

        return "\(String(format: "%.1f", amountML)) ml"
    }

    private func durationText(seconds: Int) -> String {
        let seconds = max(seconds, 0)
        let days = seconds / 86_400
        let hours = (seconds % 86_400) / 3600
        let minutes = (seconds % 3600) / 60
        let remainingSeconds = seconds % 60

        if days > 0 {
            return "\(days)天\(hours)小时\(minutes)分\(remainingSeconds)秒"
        }
        if hours > 0 {
            return "\(hours)小时\(minutes)分\(remainingSeconds)秒"
        }
        if minutes > 0 {
            return "\(minutes)分\(remainingSeconds)秒"
        }
        return "\(remainingSeconds)秒"
    }

    private func saveQuickExcretion(_ type: ExcretionType) {
        _ = ExcretionRecord(
            context: managedObjectContext,
            recordedAt: Date(),
            type: type,
            note: ""
        )
        managedObjectContext.processPendingChanges()
        scheduleManagedObjectContextSave()
    }

    private func saveQuickFeeding() {
        let now = Date()
        _ = FeedingRecord(
            context: managedObjectContext,
            startedAt: now,
            feedingType: .formula,
            amountML: Double(feedingAmount.trimmingCharacters(in: .whitespacesAndNewlines)),
            note: ""
        )
        managedObjectContext.processPendingChanges()
        scheduleManagedObjectContextSave()
    }

    private func deleteExcretionRecord(_ record: ExcretionRecord) {
        managedObjectContext.delete(record)
        managedObjectContext.processPendingChanges()
        scheduleManagedObjectContextSave()
    }

    private func deleteFeedingRecord(_ record: FeedingRecord) {
        managedObjectContext.delete(record)
        managedObjectContext.processPendingChanges()
        scheduleManagedObjectContextSave()
    }

    private func adjustFeedingRecordAmount(_ record: FeedingRecord, by delta: Int) {
        let objectID = record.objectID
        let currentAmount = pendingFeedingRecordAmounts[objectID] ?? Int((record.amountMLValue ?? 0).rounded())
        let updatedAmount = max(currentAmount + delta, 0)
        let saveVersion = (pendingFeedingRecordAmountSaveVersions[objectID] ?? 0) + 1

        pendingFeedingRecordAmounts[objectID] = updatedAmount
        pendingFeedingRecordAmountSaveVersions[objectID] = saveVersion

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            guard pendingFeedingRecordAmountSaveVersions[objectID] == saveVersion else { return }
            savePendingFeedingRecordAmount(record)
        }
    }

    private func savePendingFeedingRecordAmount(_ record: FeedingRecord) {
        let objectID = record.objectID
        guard let pendingAmount = pendingFeedingRecordAmounts[objectID] else { return }

        if record.isDeleted {
            pendingFeedingRecordAmounts[objectID] = nil
            pendingFeedingRecordAmountSaveVersions[objectID] = nil
            return
        }

        record.amountMLValue = Double(pendingAmount)
        saveManagedObjectContextIfNeeded()
        pendingFeedingRecordAmounts[objectID] = nil
        pendingFeedingRecordAmountSaveVersions[objectID] = nil
    }

    private func commitPendingFeedingRecordAmounts() {
        guard !pendingFeedingRecordAmounts.isEmpty else { return }

        for (objectID, amount) in pendingFeedingRecordAmounts {
            guard let object = try? managedObjectContext.existingObject(with: objectID),
                  let record = object as? FeedingRecord,
                  !record.isDeleted
            else { continue }

            record.amountMLValue = Double(amount)
        }

        saveManagedObjectContextIfNeeded()
        pendingFeedingRecordAmounts.removeAll()
        pendingFeedingRecordAmountSaveVersions.removeAll()
    }

    private func scheduleManagedObjectContextSave(after delay: TimeInterval = 0.25) {
        quickLogSaveVersion += 1
        let saveVersion = quickLogSaveVersion

        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            guard quickLogSaveVersion == saveVersion else { return }
            saveManagedObjectContextIfNeeded()
        }
    }

    private func saveManagedObjectContextIfNeeded() {
        guard managedObjectContext.hasChanges else { return }
        try? managedObjectContext.save()
    }

    private func saveRecord() {
        switch recordType {
        case .feeding:
            _ = FeedingRecord(
                context: managedObjectContext,
                startedAt: feedingStartedAt,
                endedAt: feedingEndedAt,
                feedingType: .formula,
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
