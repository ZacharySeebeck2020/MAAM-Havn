//
//  TagManagementView.swift
//  Havn
//
//  Created by Zac Seebeck on 8/18/25.
//


import SwiftUI
import CoreData

struct TagManagementView: View {
    @Environment(\.managedObjectContext) private var ctx
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Tag.name, ascending: true)],
        animation: .snappy
    ) private var tags: FetchedResults<Tag>

    @State private var query = ""

    private func usageCount(_ tag: Tag) -> Int {
        (tag.journalRel as? Set<JournalEntry>)?.count ?? 0
    }

    private var filtered: [Tag] {
        guard !query.isEmpty else { return Array(tags) }
        return tags.filter { ($0.name ?? "").localizedCaseInsensitiveContains(query) }
    }
    private var unused: [Tag] { filtered.filter { usageCount($0) == 0 } }
    private var used:   [Tag] { filtered.filter { usageCount($0)  > 0 } }

    var body: some View {
        List {
            if !unused.isEmpty {
                Section("Unused") {
                    ForEach(unused) { tag in
                        TagRow(name: tag.name ?? "—", count: 0)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    ctx.delete(tag)
                                    try? ctx.save()
                                } label: { Label("Delete", systemImage: "trash") }
                            }
                    }
                }
            }

            Section("Used") {
                ForEach(used) { tag in
                    let count = usageCount(tag)
                    TagRow(name: tag.name ?? "—", count: count)
                        // Optional: actions for future (rename/merge)
                        .contextMenu {
                            Button("Rename") { rename(tag) }
                            Button("Remove from all", role: .destructive) { removeFromAll(tag) }
                        }
                }
            }
        }
        .toolbar {
            Button("Delete Unused") {
                unused.forEach { ctx.delete($0) }
                try? ctx.save()
            }.disabled(unused.isEmpty)
        }
        .navigationTitle("Manage Tags")
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .automatic), prompt: "Search tags")
    }

    private func rename(_ tag: Tag) {
        // minimal inline rename via alert text field (iOS 17+)—stub:
        // present your own rename sheet; after change: try? ctx.save()
    }
    private func removeFromAll(_ tag: Tag) {
        if let set = tag.journalRel as? Set<JournalEntry> {
            for e in set { e.removeFromTagsRel(tag) }
            tag.journalRel = NSSet()
        }
        try? ctx.save()
    }
}

private struct TagRow: View {
    let name: String
    let count: Int
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(name).font(.body)
            Text(count == 1 ? "Used on 1 entry" : "Used on \(count) entries")
                .font(.footnote).foregroundStyle(.secondary)
        }
    }
}

#Preview("TagManagementView • Light") {
    TagManagementView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
#Preview("TagManagementView • Dark")  {
    TagManagementView().preferredColorScheme(.dark)
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
