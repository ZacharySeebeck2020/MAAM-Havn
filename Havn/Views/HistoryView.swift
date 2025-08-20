//
//  HistoryView.swift
//  Havn
//
//  Created by Zac Seebeck on 8/9/25.
//


import SwiftUI

// Encapsulates all filtering logic for HistoryView
struct HistoryFilterState {
    enum Segment {
        case all, starred, photos
    }
    var segment: Segment = .all
    var searchText: String = ""
    /// Picker indices where 0 = Any, N = raw value (N-1)
    var moodIndex: Int = 0
    var energyIndex: Int = 0
    var weatherIndex: Int = 0

    @inline(__always)
    private func mappedValue(from index: Int) -> Int? {
        // 0 = Any -> nil (no filter); otherwise shift down by one.
        index == 0 ? nil : (index )
    }

    func matches(_ e: JournalEntry) -> Bool {
        // Segment
        let passSegment: Bool = {
            switch segment {
            case .all:
                return true
            case .starred:
                return e.isStarred
            case .photos:
                return (e.photoData?.isEmpty == false)
            }
        }()

        // Search in text, optional title, and tag names
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let passSearch: Bool = {
            guard !q.isEmpty else { return true }
            let inText  = e.textValue.localizedCaseInsensitiveContains(q)
            let inTags: Bool = {
                if let set = e.tagsRel as? Set<Tag> {
                    return set.contains { ($0.name ?? "").localizedCaseInsensitiveContains(q) }
                }
                return false
            }()
            return inText || inTags
        }()

        // Vitals (off-by-one fixed via mappedValue)
        let moodSelected    = mappedValue(from: moodIndex)
        let energySelected  = mappedValue(from: energyIndex)
        let weatherSelected = mappedValue(from: weatherIndex)

        // These properties are provided by JournalEntry+Safe
        // (Int-backed, defaulting to nil when unset)
        let passMood: Bool = {
            if let sel = moodSelected { return e.moodScore == sel }
            return true
        }()
        let passEnergy: Bool = {
            if let sel = energySelected { return e.energyScore == sel }
            return true
        }()
        let passWeather: Bool = {
            if let sel = weatherSelected { return e.weatherScore == sel }
            return true
        }()

        return passSegment && passSearch && passMood && passEnergy && passWeather
    }
}

struct HistoryView: View {
    @Environment(\.managedObjectContext) private var moc

    // Base fetch (sorted by day desc). We'll filter in-memory for now.
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \JournalEntry.day, ascending: false)],
        animation: .default
    ) private var entries: FetchedResults<JournalEntry>

    // UI state
    enum Filter: String, CaseIterable, Identifiable {
        case all = "All"
        case starred = "Starred"
        case photos = "Photos"
        var id: String { rawValue }
    }
    @State private var filter: Filter = .all
    @State private var searchText: String = ""
    
    @State var moodFilter: Int = 0
    @State var energyFilter: Int = 0
    @State var weatherFilter: Int = 0

    // Derived/composed filter state used for matching
    private var composedFilter: HistoryFilterState {
        var s = HistoryFilterState()
        s.segment = {
            switch filter {
            case .all: return .all
            case .starred: return .starred
            case .photos: return .photos
            }
        }()
        s.searchText = searchText
        s.moodIndex = moodFilter
        s.energyIndex = energyFilter
        s.weatherIndex = weatherFilter
        return s
    }

    var body: some View {
        VStack(spacing: 8) {
            FiltersBar(moodFilter: $moodFilter, energyFilter: $energyFilter, weatherFilter: $weatherFilter, searchFilter: $searchText)
            // Segmented filter
//            Picker("Filter", selection: $filter) {
//                ForEach(Filter.allCases) { f in
//                    Text(f.rawValue).tag(f)
//                }
//            }
//            .pickerStyle(.segmented)
//            .padding(.horizontal)

            // Results list
            List {
                if filteredEntries.isEmpty {
                    EmptyState(
                        title: "No matches",
                        subtitle: "Try fewer words or remove filters.",
                        systemImage: "magnifyingglass"
                    )
                    .padding(.top, 12)
                } else {
                    ForEach(filteredEntries) { e in
                        NavigationLink {
                            EntryEditor(day: e.dayValue)
                                .navigationTitle(e.dayValue.formatted(date: .abbreviated, time: .omitted))
                        } label: {
                            row(for: e)
                        }
                        .listRowBackground(Color("BackgroundColor"))
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button {
                                e.isStarred.toggle()
                                try? moc.save()
                            } label: {
                                Label(e.isStarred ? "Unstar" : "Star",
                                      systemImage: e.isStarred ? "star.slash" : "star")
                            }.tint(.yellow)
                        }
                        .swipeActions(edge: .leading) {
                            Button(role: .destructive) {
                                moc.delete(e)
                                try? moc.save()
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color("BackgroundColor"))
        }
    }

    // MARK: - Filtering

    private var filteredEntries: [JournalEntry] {
        entries.filter { composedFilter.matches($0) }
    }

    private var emptyHint: String {
        switch filter {
        case .all:
            return searchText.isEmpty ? "Add your first entry to see it here."
                                      : "Try a different search."
        case .starred:
            return "No starred entries match your search."
        case .photos:
            return "No photo entries match your search."
        }
    }

    // MARK: - Row

    @ViewBuilder
    private func row(for e: JournalEntry) -> some View {
        HStack(spacing: 12) {
            if let data = e.photoData, let ui = UIImage(data: data) {
                Image(uiImage: ui)
                    .resizable().scaledToFill()
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color("CardSurfaceColor"))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: "photo")
                            .imageScale(.small)
                            .foregroundStyle(Color("TextMutedColor"))
                    )
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(e.dayValue, style: .date).fontWeight(.semibold)
                Text(e.textValue).lineLimit(1)
                    .foregroundStyle(Color("TextMutedColor"))
            }
            Spacer()
            if e.isStarred { Image(systemName: "star.fill") }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(e.dayValue.formatted(date: .complete, time: .omitted)), \(e.isStarred ? "starred" : "")")
    }
}

#Preview("Interactive • Light") {
    HistoryView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}

#Preview("Interactive • Dark") {
    HistoryView()
        .preferredColorScheme(ColorScheme.dark)
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
