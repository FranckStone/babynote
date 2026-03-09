import CoreData
import SwiftUI

private struct QuickLogDestination: Identifiable {
    let recordType: RecordType
    let showsTypePicker: Bool

    var id: String {
        "\(recordType.rawValue)-\(showsTypePicker)"
    }
}

struct HomeView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @FetchRequest(sortDescriptors: [SortDescriptor(\FeedingRecord.startedAt, order: .reverse)]) private var feedings: FetchedResults<FeedingRecord>
    @FetchRequest(sortDescriptors: [SortDescriptor(\WeightRecord.recordedAt, order: .reverse)]) private var weights: FetchedResults<WeightRecord>
    @FetchRequest(sortDescriptors: [SortDescriptor(\MedicationRecord.recordedAt, order: .reverse)]) private var medications: FetchedResults<MedicationRecord>
    @FetchRequest(sortDescriptors: [SortDescriptor(\CheckupRecord.recordedAt, order: .reverse)]) private var checkups: FetchedResults<CheckupRecord>
    @FetchRequest(sortDescriptors: [SortDescriptor(\FetalMovementRecord.recordedAt, order: .reverse)]) private var fetalMovements: FetchedResults<FetalMovementRecord>
    @FetchRequest(sortDescriptors: [SortDescriptor(\BloodGlucoseRecord.recordedAt, order: .reverse)]) private var bloodGlucoses: FetchedResults<BloodGlucoseRecord>
    @State private var isShowingQuickRecordOptions = false
    @State private var quickLogDestination: QuickLogDestination?

    private var timelineItems: [TimelineItem] {
        TimelineItem.build(feedings: Array(feedings), weights: Array(weights), medications: Array(medications), checkups: Array(checkups), fetalMovements: Array(fetalMovements), bloodGlucoses: Array(bloodGlucoses))
    }

    private var todayFeedingCount: Int {
        feedings.filter { Calendar.current.isDateInToday($0.startedAt) }.count
    }

    private var todayMedicationCount: Int {
        medications.filter { Calendar.current.isDateInToday($0.recordedAt) }.count
    }

    private var todayFetalMovementCount: Int {
        fetalMovements.filter { Calendar.current.isDateInToday($0.recordedAt) }.count
    }

    private var todayBloodGlucoseCount: Int {
        bloodGlucoses.filter { Calendar.current.isDateInToday($0.recordedAt) }.count
    }

    private var summaryColumns: [GridItem] {
        let count = horizontalSizeClass == .regular ? 1 : 2
        return Array(repeating: GridItem(.flexible(), spacing: 12), count: count)
    }

    private var contentMaxWidth: CGFloat {
        horizontalSizeClass == .regular ? 980 : .infinity
    }

    private var quickRecordColumns: [GridItem] {
        let count = horizontalSizeClass == .regular ? 3 : 2
        return Array(repeating: GridItem(.flexible(), spacing: 12), count: count)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                dashboardContent
                .padding(20)
                .adaptiveContentWidth(contentMaxWidth)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("宝贝笔记")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isShowingQuickRecordOptions = true
                    } label: {
                        Label("快速记录", systemImage: "plus")
                    }
                }
            }
            .sheet(item: $quickLogDestination) { destination in
                QuickLogView(initialRecordType: destination.recordType, showsTypePicker: destination.showsTypePicker)
            }
            .sheet(isPresented: $isShowingQuickRecordOptions, onDismiss: {
                // no-op; selection opens a dedicated route directly
            }) {
                quickRecordOptionsSheet
            }
        }
    }

    @ViewBuilder
    private var dashboardContent: some View {
        if horizontalSizeClass == .regular {
            HStack(alignment: .top, spacing: 20) {
                VStack(alignment: .leading, spacing: 20) {
                    heroCard
                    recentSection
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)

                VStack(alignment: .leading, spacing: 12) {
                    Text("今日概览")
                        .font(.headline)
                    summaryGrid
                }
                .frame(width: 360, alignment: .topLeading)
            }
        } else {
            VStack(alignment: .leading, spacing: 20) {
                heroCard
                summaryGrid
                recentSection
            }
        }
    }

    private var summaryGrid: some View {
        LazyVGrid(columns: summaryColumns, spacing: 12) {
            SummaryCard(
                title: "今日喂奶",
                value: "\(todayFeedingCount) 次",
                subtitle: feedings.first.map { "最近 \(DateDisplay.time($0.startedAt))" } ?? "还没有记录",
                tint: .pink
            )

            SummaryCard(
                title: "最近体重",
                value: weights.first.map { WeightDisplay.jinText(fromKG: $0.weightKG) } ?? "--",
                subtitle: weights.first.map { DateDisplay.shortDate($0.recordedAt) } ?? "还没有记录",
                tint: .orange
            )

            SummaryCard(
                title: "今日用药",
                value: "\(todayMedicationCount) 次",
                subtitle: medications.first?.name ?? "还没有记录",
                tint: .blue
            )

            SummaryCard(
                title: "最近产检",
                value: checkups.first?.location ?? "--",
                subtitle: checkups.first?.summary ?? "还没有记录",
                tint: .green
            )

            SummaryCard(
                title: "今日胎动",
                value: "\(todayFetalMovementCount) 次",
                subtitle: fetalMovements.first.map { DateDisplay.time($0.recordedAt) } ?? "还没有记录",
                tint: .mint
            )

            SummaryCard(
                title: "今日血糖",
                value: "\(todayBloodGlucoseCount) 次",
                subtitle: bloodGlucoses.first.map { "\($0.moment.displayName) \(String(format: "%.1f", $0.valueMMOL))" } ?? "还没有记录",
                tint: .red
            )
        }
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("今天最重要的是少一步操作。")
                .font(.title2.bold())
                .foregroundStyle(.primary)

            Text("喂奶、体重、吃药、检查结果和胎动都能在几秒内记下来，后面再补充细节。")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button {
                isShowingQuickRecordOptions = true
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("现在记录")
                        .fontWeight(.semibold)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.accentColor)
                .foregroundStyle(.white)
                .clipShape(Capsule())
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [Color.pink.opacity(0.18), Color.orange.opacity(0.16)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var quickRecordOptionsSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("选择要记录的内容")
                        .font(.title3.bold())

                    Text("点一下直接进入对应记录页")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    LazyVGrid(columns: quickRecordColumns, spacing: 12) {
                        ForEach(RecordType.allCases) { type in
                            Button {
                                quickLogDestination = QuickLogDestination(recordType: type, showsTypePicker: false)
                                isShowingQuickRecordOptions = false
                            } label: {
                                VStack(alignment: .leading, spacing: 10) {
                                    HStack {
                                        Image(systemName: type.symbol)
                                            .font(.title3.weight(.semibold))
                                        Spacer()
                                        Image(systemName: "arrow.right")
                                            .font(.footnote.weight(.bold))
                                            .foregroundStyle(.secondary)
                                    }

                                    Text(type.displayName)
                                        .font(.headline)

                                    Text(quickActionSubtitle(for: type))
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                                .frame(maxWidth: .infinity, minHeight: 116, alignment: .leading)
                                .padding(16)
                                .background(quickActionBackground(for: type))
                                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(20)
                .adaptiveContentWidth(horizontalSizeClass == .regular ? 860 : .infinity)
            }
            .background(Color(.systemGroupedBackground))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("取消") {
                        isShowingQuickRecordOptions = false
                    }
                }
            }
        }
        .presentationDetents(horizontalSizeClass == .regular ? [.large] : [.medium, .large])
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("最近记录")
                .font(.headline)

            if timelineItems.isEmpty {
                if #available(iOS 17.0, *) {
                    ContentUnavailableView("还没有记录", systemImage: "tray", description: Text("先从一次快速记录开始。"))
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "tray")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                        Text("还没有记录")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("先从一次快速记录开始。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 24)
                }
            } else {
                let recentItems = Array(timelineItems.prefix(4))
                VStack(spacing: 10) {
                    ForEach(recentItems) { item in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: item.type.symbol)
                                .font(.headline)
                                .foregroundStyle(Color.accentColor)
                                .frame(width: 28, height: 28)
                                .background(Color.accentColor.opacity(0.12))
                                .clipShape(Circle())

                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.title)
                                    .font(.headline)
                                Text(item.detail)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                if !item.note.isEmpty {
                                    Text(item.note)
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                            }

                            Spacer()

                            Text(DateDisplay.time(item.recordedAt))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .padding(14)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                }
            }
        }
    }

    private func quickActionSubtitle(for type: RecordType) -> String {
        switch type {
        case .feeding:
            return feedings.first.map { "最近 \(DateDisplay.time($0.startedAt))" } ?? "记录开始和结束时间"
        case .weight:
            return weights.first.map { "最近 \(WeightDisplay.jinText(fromKG: $0.weightKG))" } ?? "记录孕期体重变化"
        case .medication:
            return medications.first.map { "最近 \($0.name)" } ?? "记录药名和剂量"
        case .checkup:
            return checkups.first.map { "最近 \($0.location)" } ?? "记录产检和检查结果"
        case .fetalMovement:
            return fetalMovements.first.map { "最近 \(DateDisplay.time($0.recordedAt))" } ?? "记录胎动次数和时长"
        case .bloodGlucose:
            return bloodGlucoses.first.map { "最近 \($0.moment.displayName) \(String(format: "%.1f", $0.valueMMOL)) mmol/L" } ?? "记录餐前餐后和睡前血糖"
        }
    }

    private func quickActionBackground(for type: RecordType) -> some View {
        let colors: [Color]
        switch type {
        case .feeding:
            colors = [Color.pink.opacity(0.22), Color.orange.opacity(0.18)]
        case .weight:
            colors = [Color.orange.opacity(0.22), Color.yellow.opacity(0.18)]
        case .medication:
            colors = [Color.blue.opacity(0.2), Color.cyan.opacity(0.16)]
        case .checkup:
            colors = [Color.green.opacity(0.22), Color.mint.opacity(0.16)]
        case .fetalMovement:
            colors = [Color.mint.opacity(0.22), Color.teal.opacity(0.16)]
        case .bloodGlucose:
            colors = [Color.red.opacity(0.2), Color.orange.opacity(0.15)]
        }

        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}
