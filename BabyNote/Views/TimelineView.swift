import SwiftData
import SwiftUI

struct TimelineView: View {
    @Query(sort: \FeedingRecord.startedAt, order: .reverse) private var feedings: [FeedingRecord]
    @Query(sort: \WeightRecord.recordedAt, order: .reverse) private var weights: [WeightRecord]
    @Query(sort: \MedicationRecord.recordedAt, order: .reverse) private var medications: [MedicationRecord]
    @Query(sort: \CheckupRecord.recordedAt, order: .reverse) private var checkups: [CheckupRecord]
    @State private var selectedType: RecordType?

    private var filteredItems: [TimelineItem] {
        let items = TimelineItem.build(feedings: feedings, weights: weights, medications: medications, checkups: checkups)
        guard let selectedType else { return items }
        return items.filter { $0.type == selectedType }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            filterChip(title: "全部", type: nil)
                            ForEach(RecordType.allCases) { type in
                                filterChip(title: type.displayName, type: type)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .listRowBackground(Color.clear)

                if filteredItems.isEmpty {
                    Section {
                        ContentUnavailableView("还没有时间线记录", systemImage: "calendar")
                    }
                } else {
                    ForEach(filteredItems) { item in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Label(item.title, systemImage: item.type.symbol)
                                    .font(.headline)
                                Spacer()
                                Text(item.recordedAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }

                            Text(item.detail)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            if !item.note.isEmpty {
                                Text(item.note)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("时间线")
        }
    }

    private func filterChip(title: String, type: RecordType?) -> some View {
        let isSelected = selectedType == type

        return Button {
            selectedType = type
        } label: {
            Text(title)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(isSelected ? Color.accentColor : Color(.secondarySystemBackground))
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
