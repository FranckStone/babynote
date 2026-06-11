import CoreData
import SwiftUI

struct TimelineView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.managedObjectContext) private var managedObjectContext
    @FetchRequest(sortDescriptors: [SortDescriptor(\FeedingRecord.startedAt, order: .reverse)]) private var feedings: FetchedResults<FeedingRecord>
    @FetchRequest(sortDescriptors: [SortDescriptor(\WeightRecord.recordedAt, order: .reverse)]) private var weights: FetchedResults<WeightRecord>
    @FetchRequest(sortDescriptors: [SortDescriptor(\MedicationRecord.recordedAt, order: .reverse)]) private var medications: FetchedResults<MedicationRecord>
    @FetchRequest(sortDescriptors: [SortDescriptor(\CheckupRecord.recordedAt, order: .reverse)]) private var checkups: FetchedResults<CheckupRecord>
    @FetchRequest(sortDescriptors: [SortDescriptor(\FetalMovementRecord.recordedAt, order: .reverse)]) private var fetalMovements: FetchedResults<FetalMovementRecord>
    @FetchRequest(sortDescriptors: [SortDescriptor(\BloodGlucoseRecord.recordedAt, order: .reverse)]) private var bloodGlucoses: FetchedResults<BloodGlucoseRecord>
    @FetchRequest(sortDescriptors: [SortDescriptor(\ExcretionRecord.recordedAt, order: .reverse)]) private var excretions: FetchedResults<ExcretionRecord>
    @State private var selectedType: RecordType?
    @State private var selectedItem: TimelineItem?

    private var allTimelineItems: [TimelineItem] {
        let items = TimelineItem.build(feedings: Array(feedings), weights: Array(weights), medications: Array(medications), checkups: Array(checkups), fetalMovements: Array(fetalMovements), bloodGlucoses: Array(bloodGlucoses), excretions: Array(excretions))
        return items
    }

    private var filteredItems: [TimelineItem] {
        let items = allTimelineItems
        guard let selectedType else { return items }
        return items.filter { $0.type == selectedType }
    }

    private var usesWideTimelineLayout: Bool {
        horizontalSizeClass == .regular || verticalSizeClass == .compact
    }

    var body: some View {
        let items = filteredItems

        NavigationStack {
            Group {
                if usesWideTimelineLayout {
                    wideTimelineLayout(items: items)
                } else {
                    compactTimelineList(items: items)
                }
            }
            .navigationTitle("时间线")
            .sheet(item: $selectedItem) { item in
                RecordEditorView(item: item)
            }
        }
    }

    private func compactTimelineList(items: [TimelineItem]) -> some View {
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
                    emptyTimelineView
                }
            } else {
                ForEach(items) { item in
                    timelineRow(item, showsDeleteButton: false)
                        .swipeActions {
                            Button("删除", role: .destructive) {
                                delete(item)
                            }
                        }
                }
            }
        }
        .adaptiveContentWidth(horizontalSizeClass == .regular ? 900 : .infinity)
    }

    private func wideTimelineLayout(items: [TimelineItem]) -> some View {
        HStack(alignment: .top, spacing: 16) {
            filterSidebar
                .frame(width: 190)

            ScrollView {
                LazyVStack(spacing: 10) {
                    if items.isEmpty {
                        emptyTimelineView
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 28)
                    } else {
                        ForEach(items) { item in
                            timelineRow(item, showsDeleteButton: true)
                                .padding(.horizontal, 2)
                        }
                    }
                }
                .padding(14)
            }
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .padding(16)
        .adaptiveContentWidth(1100)
        .background(Color(.systemGroupedBackground))
    }

    private var filterSidebar: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("类型")
                .font(.headline)
                .padding(.bottom, 4)

            sidebarFilterButton(title: "全部", type: nil, count: allTimelineItems.count)

            ForEach(RecordType.allCases) { type in
                sidebarFilterButton(
                    title: type.displayName,
                    type: type,
                    count: allTimelineItems.filter { $0.type == type }.count
                )
            }
        }
        .padding(14)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func sidebarFilterButton(title: String, type: RecordType?, count: Int) -> some View {
        let isSelected = selectedType == type

        return Button {
            selectedType = type
        } label: {
            HStack(spacing: 10) {
                if let type {
                    Image(systemName: type.symbol)
                        .frame(width: 22)
                } else {
                    Image(systemName: "tray.full.fill")
                        .frame(width: 22)
                }

                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)

                Spacer()

                Text("\(count)")
                    .font(.caption.monospacedDigit().weight(.medium))
                    .foregroundStyle(isSelected ? .white.opacity(0.85) : .secondary)
            }
            .padding(.horizontal, 10)
            .frame(height: 42)
            .background(isSelected ? Color.accentColor : Color.clear)
            .foregroundStyle(isSelected ? .white : .primary)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var emptyTimelineView: some View {
        Group {
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
    }

    private func timelineRow(_ item: TimelineItem, showsDeleteButton: Bool) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: item.type.symbol)
                .font(.headline.weight(.semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 36, height: 36)
                .background(Color.accentColor.opacity(0.12))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(item.title)
                        .font(.headline)
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
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 8)

            if showsDeleteButton {
                Button(role: .destructive) {
                    delete(item)
                } label: {
                    Image(systemName: "trash")
                        .font(.headline)
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, showsDeleteButton ? 10 : 0)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(showsDeleteButton ? Color(.tertiarySystemBackground) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture {
            selectedItem = item
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
        case .excretion(let record):
            managedObjectContext.delete(record)
        }

        try? managedObjectContext.save()
    }
}
