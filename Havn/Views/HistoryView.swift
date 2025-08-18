//
//  HistoryView.swift
//  Havn
//
//  Created by Zac Seebeck on 8/9/25.
//

import SwiftUI

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

    var body: some View {
        VStack(spacing: 8) {
            // Segmented filter
            Picker("Filter", selection: $filter) {
                ForEach(Filter.allCases) { f in
                    Text(f.rawValue).tag(f)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

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
        // Native search bar (searches note contents)
        .searchable(text: $searchText, placement: .navigationBarDrawer, prompt: "Search entries")
    }

    // MARK: - Filtering

    private var filteredEntries: [JournalEntry] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return entries.filter { e in
            // Filter
            let passFilter: Bool = {
                switch filter {
                case .all:     return true
                case .starred: return e.isStarred
                case .photos:  return (e.photoData?.isEmpty == false)
                }
            }()
            // Search (contents only)
            let passSearch = q.isEmpty || e.textValue.localizedCaseInsensitiveContains(q)
            return passFilter && passSearch
        }
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
