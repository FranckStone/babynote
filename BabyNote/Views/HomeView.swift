import SwiftData
import SwiftUI

struct HomeView: View {
    @Query(sort: \FeedingRecord.startedAt, order: .reverse) private var feedings: [FeedingRecord]
    @Query(sort: \WeightRecord.recordedAt, order: .reverse) private var weights: [WeightRecord]
    @Query(sort: \MedicationRecord.recordedAt, order: .reverse) private var medications: [MedicationRecord]
    @Query(sort: \CheckupRecord.recordedAt, order: .reverse) private var checkups: [CheckupRecord]
    @State private var isPresentingQuickLog = false

    private var timelineItems: [TimelineItem] {
        TimelineItem.build(feedings: feedings, weights: weights, medications: medications, checkups: checkups)
    }

    private var todayFeedingCount: Int {
        feedings.filter { Calendar.current.isDateInToday($0.startedAt) }.count
    }

    private var todayMedicationCount: Int {
        medications.filter { Calendar.current.isDateInToday($0.recordedAt) }.count
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
                            subtitle: feedings.first.map { "最近 \($0.startedAt.formatted(date: .omitted, time: .shortened))" } ?? "还没有记录",
                            tint: .pink
                        )

                        SummaryCard(
                            title: "最近体重",
                            value: weights.first.map { String(format: "%.1f kg", $0.weightKG) } ?? "--",
                            subtitle: weights.first.map { $0.recordedAt.formatted(date: .abbreviated, time: .omitted) } ?? "还没有记录",
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
                    }

                    quickActions

                    recentSection
                }
                .padding(20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("BabyNote")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isPresentingQuickLog = true
                    } label: {
                        Label("快速记录", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $isPresentingQuickLog) {
                QuickLogView()
            }
        }
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("今天最重要的是少一步操作。")
                .font(.title2.bold())
                .foregroundStyle(.primary)

            Text("喂奶、体重、吃药、检查结果都能在几秒内记下来，后面再补充细节。")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button {
                isPresentingQuickLog = true
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

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("快捷入口")
                .font(.headline)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(RecordType.allCases) { type in
                        Button {
                            isPresentingQuickLog = true
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                Image(systemName: type.symbol)
                                    .font(.title2)
                                Text(type.displayName)
                                    .font(.headline)
                            }
                            .frame(width: 120, height: 84, alignment: .leading)
                            .padding(16)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
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

                            Text(item.recordedAt.formatted(date: .omitted, time: .shortened))
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
}
