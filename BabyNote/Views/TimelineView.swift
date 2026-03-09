import SwiftData
import SwiftUI

struct TimelineView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FeedingRecord.startedAt, order: .reverse) private var feedings: [FeedingRecord]
    @Query(sort: \WeightRecord.recordedAt, order: .reverse) private var weights: [WeightRecord]
    @Query(sort: \MedicationRecord.recordedAt, order: .reverse) private var medications: [MedicationRecord]
    @Query(sort: \CheckupRecord.recordedAt, order: .reverse) private var checkups: [CheckupRecord]
    @Query(sort: \FetalMovementRecord.recordedAt, order: .reverse) private var fetalMovements: [FetalMovementRecord]
    @State private var selectedType: RecordType?
    @State private var selectedItem: TimelineItem?

    private var filteredItems: [TimelineItem] {
        let items = TimelineItem.build(feedings: feedings, weights: weights, medications: medications, checkups: checkups, fetalMovements: fetalMovements)
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
                        Button {
                            selectedItem = item
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Label(item.title, systemImage: item.type.symbol)
                                        .font(.headline)
                                    Spacer()
                                    Text(DateDisplay.dateTime(item.recordedAt))
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
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                        .swipeActions {
                            Button("删除", role: .destructive) {
                                delete(item)
                            }
                        }
                    }
                }
            }
            .navigationTitle("时间线")
            .sheet(item: $selectedItem) { item in
                RecordEditorView(item: item)
            }
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

    private func delete(_ item: TimelineItem) {
        switch item.record {
        case .feeding(let record):
            modelContext.delete(record)
        case .weight(let record):
            modelContext.delete(record)
        case .medication(let record):
            modelContext.delete(record)
        case .checkup(let record):
            modelContext.delete(record)
        case .fetalMovement(let record):
            modelContext.delete(record)
        }

        try? modelContext.save()
    }
}
