import SwiftData
import SwiftUI

struct HomeView: View {
    @Query(sort: \FeedingRecord.startedAt, order: .reverse) private var feedings: [FeedingRecord]
    @Query(sort: \WeightRecord.recordedAt, order: .reverse) private var weights: [WeightRecord]
    @Query(sort: \MedicationRecord.recordedAt, order: .reverse) private var medications: [MedicationRecord]
    @Query(sort: \CheckupRecord.recordedAt, order: .reverse) private var checkups: [CheckupRecord]
    @Query(sort: \FetalMovementRecord.recordedAt, order: .reverse) private var fetalMovements: [FetalMovementRecord]
    @State private var isPresentingQuickLog = false
    @State private var isShowingQuickRecordOptions = false
    @State private var selectedRecordType: RecordType = .feeding
    @State private var showsTypePicker = true

    private var timelineItems: [TimelineItem] {
        TimelineItem.build(feedings: feedings, weights: weights, medications: medications, checkups: checkups, fetalMovements: fetalMovements)
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

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    heroCard

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        SummaryCard(
                            title: "今日喂奶",
                            value: "\(todayFeedingCount) 次",
                            subtitle: feedings.first.map { "最近 \(DateDisplay.time($0.startedAt))" } ?? "还没有记录",
                            tint: .pink
                        )

                        SummaryCard(
                            title: "最近体重",
                            value: weights.first.map { String(format: "%.1f kg", $0.weightKG) } ?? "--",
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
                    }

                    recentSection
                }
                .padding(20)
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
            .sheet(isPresented: $isPresentingQuickLog) {
                QuickLogView(initialRecordType: selectedRecordType, showsTypePicker: showsTypePicker)
            }
            .sheet(isPresented: $isShowingQuickRecordOptions) {
                quickRecordOptionsSheet
            }
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

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(RecordType.allCases) { type in
                            Button {
                                isShowingQuickRecordOptions = false
                                presentQuickLog(for: type, showsTypePicker: false)
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
        .presentationDetents([.medium, .large])
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("最近记录")
                .font(.headline)

            if timelineItems.isEmpty {
                ContentUnavailableView("还没有记录", systemImage: "tray", description: Text("先从一次快速记录开始。"))
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

    private func presentQuickLog(for type: RecordType, showsTypePicker: Bool) {
        selectedRecordType = type
        self.showsTypePicker = showsTypePicker
        isPresentingQuickLog = true
    }

    private func quickActionSubtitle(for type: RecordType) -> String {
        switch type {
        case .feeding:
            return feedings.first.map { "最近 \(DateDisplay.time($0.startedAt))" } ?? "记录开始和结束时间"
        case .weight:
            return weights.first.map { "最近 \(String(format: "%.1f kg", $0.weightKG))" } ?? "记录孕期体重变化"
        case .medication:
            return medications.first.map { "最近 \($0.name)" } ?? "记录药名和剂量"
        case .checkup:
            return checkups.first.map { "最近 \($0.location)" } ?? "记录产检和检查结果"
        case .fetalMovement:
            return fetalMovements.first.map { "最近 \(DateDisplay.time($0.recordedAt))" } ?? "记录胎动次数和时长"
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
        }

        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}
