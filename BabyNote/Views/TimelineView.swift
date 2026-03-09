import CoreData
import SwiftUI

struct TimelineView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.managedObjectContext) private var managedObjectContext
    @FetchRequest(sortDescriptors: [SortDescriptor(\FeedingRecord.startedAt, order: .reverse)]) private var feedings: FetchedResults<FeedingRecord>
    @FetchRequest(sortDescriptors: [SortDescriptor(\WeightRecord.recordedAt, order: .reverse)]) private var weights: FetchedResults<WeightRecord>
    @FetchRequest(sortDescriptors: [SortDescriptor(\MedicationRecord.recordedAt, order: .reverse)]) private var medications: FetchedResults<MedicationRecord>
    @FetchRequest(sortDescriptors: [SortDescriptor(\CheckupRecord.recordedAt, order: .reverse)]) private var checkups: FetchedResults<CheckupRecord>
    @FetchRequest(sortDescriptors: [SortDescriptor(\FetalMovementRecord.recordedAt, order: .reverse)]) private var fetalMovements: FetchedResults<FetalMovementRecord>
    @FetchRequest(sortDescriptors: [SortDescriptor(\BloodGlucoseRecord.recordedAt, order: .reverse)]) private var bloodGlucoses: FetchedResults<BloodGlucoseRecord>
    @State private var selectedType: RecordType?
    @State private var selectedItem: TimelineItem?

    private var filteredItems: [TimelineItem] {
        let items = TimelineItem.build(feedings: Array(feedings), weights: Array(weights), medications: Array(medications), checkups: Array(checkups), fetalMovements: Array(fetalMovements), bloodGlucoses: Array(bloodGlucoses))
        guard let selectedType else { return items }
        return items.filter { $0.type == selectedType }
    }

    var body: some View {
        let items = filteredItems

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

                if items.isEmpty {
                    Section {
                        if #available(iOS 17.0, *) {
                            ContentUnavailableView("还没有时间线记录", systemImage: "calendar")
                        } else {
                            VStack(spacing: 8) {
                                Image(systemName: "calendar")
                                    .font(.title2)
                                    .foregroundStyle(.secondary)
                                Text("还没有时间线记录")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 24)
                        }
                    }
                } else {
                    ForEach(items) { item in
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
            .adaptiveContentWidth(horizontalSizeClass == .regular ? 900 : .infinity)
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
            managedObjectContext.delete(record)
        case .weight(let record):
            managedObjectContext.delete(record)
        case .medication(let record):
            managedObjectContext.delete(record)
        case .checkup(let record):
            managedObjectContext.delete(record)
        case .fetalMovement(let record):
            managedObjectContext.delete(record)
        case .bloodGlucose(let record):
            managedObjectContext.delete(record)
        }

        try? managedObjectContext.save()
    }
}
