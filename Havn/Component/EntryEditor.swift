//
//  EntryEditor.swift
//  Havn
//
//  Created by Zac Seebeck on 8/9/25.
//

import SwiftUI
import PhotosUI
import CoreData

struct EntryEditor: View {
    @Environment(\.managedObjectContext) private var moc
    let day: Date

    @FetchRequest private var entries: FetchedResults<JournalEntry>
    @State private var draftText: String = ""
    @State private var photoItem: PhotosPickerItem?
    @State private var isSaving = false
    @State private var saveTask: Task<Void, Never>? = nil

    @MainActor
    private func scheduleSave(debounce: Double = 0.75) {
        saveTask?.cancel()
        let snapshot = draftText  // capture latest text
        saveTask = Task { @MainActor in
            isSaving = true
            try? await Task.sleep(nanoseconds: UInt64(debounce * 1_000_000_000))
            if Task.isCancelled { isSaving = false; return }
            saveNowIfNeeded(text: snapshot)
            isSaving = false
        }
    }

    init(day: Date) {
        let start = Day.start(day), end = Day.next(day)
        _entries = FetchRequest<JournalEntry>(
            sortDescriptors: [],
            predicate: NSPredicate(format: "day >= %@ AND day < %@", start as NSDate, end as NSDate),
            animation: .default
        )
        self.day = start
    }

    var body: some View {
        let entry = entries.first  // may be nil on first load

        VStack(spacing: 12) {
            // Photo
            PhotosPicker(selection: $photoItem, matching: .images) {
                ZStack {
                    if let data = entry?.photoData, let ui = UIImage(data: data) {
                        Image(uiImage: ui).resizable().scaledToFill()
                    } else {
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(style: StrokeStyle(lineWidth: 1, dash: [4]))
                            .overlay(
                                Text("Add a photo")
                                    .font(HavnTheme.Typeface.title)
                                    .foregroundStyle(Color("TextMutedColor"))
                            )
                    }
                }
                .frame(height: 180)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .havnCardStroke()
            }
            .onChange(of: photoItem) { _, item in
                Task {
                    guard let data = try? await item?.loadTransferable(type: Data.self) else { return }
                    let e = entry ?? createEntry()

                    // Re-encode to JPEG for consistency/size, else store original
                    if let ui = UIImage(data: data), let jpeg = ui.jpegData(compressionQuality: 0.9) {
                        e.photoData = jpeg
                    } else {
                        e.photoData = data
                    }
                    touch(e)
                }
            }

            // Text
            TextEditor(text: Binding(
                get: { draftText },
                set: { new in
                    draftText = new
                    scheduleSave(debounce: 0.75)    // debounce typing saves
                }
            ))
            .frame(minHeight: 220)
            .padding(12)
            
            .background(RoundedRectangle(cornerRadius: HavnTheme.Radius.card).fill(Color("CardSurfaceColor")))
            .overlay(RoundedRectangle(cornerRadius: HavnTheme.Radius.card).stroke(Color("AccentColor").opacity(0.25), lineWidth: 1))

        }
        .padding(.horizontal)
        .onAppear {
            // If CloudKit already brought the entry, seed the editor text
            if let e = entries.first { draftText = e.text ?? "" }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                
                }
        }
        .onDisappear {
            saveTask?.cancel()
            saveNowIfNeeded(text: draftText)
        }
        .toolbar {
            // Title: date + tiny saving state
            ToolbarItem(placement: .principal) {
                VStack(spacing: 2) {
                    Text(day.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day().year()))
                        .font(.headline)
                    if isSaving {
                        Text("Saving…").font(.caption2).foregroundStyle(Color("TextMutedColor"))
                    }
                }
            }

            // Trailing: Star toggle
            ToolbarItem(placement: .navigationBarTrailing) {
                let starred = entry?.isStarred ?? false
                Button {
                    let e = entry ?? createEntry()
                    e.isStarred.toggle()
                    scheduleSave()
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    Image(systemName: starred ? "star.fill" : "star")
                        .symbolRenderingMode(.hierarchical)
                }
                .accessibilityLabel((entry?.isStarred ?? false) ? "Unstar" : "Star")
            }
        }
    }

    // Helpers
    private func createEntry() -> JournalEntry {
        let e = JournalEntry(context: moc)
        e.id = UUID()
        e.day = day
        e.createdAt = Date()
        e.updatedAt = Date()
        return e
    }

    @MainActor
    private func fetchEntry() -> JournalEntry? {
        let cal = Calendar.current
        let start = cal.startOfDay(for: day)
        let end   = cal.date(byAdding: .day, value: 1, to: start)!
        let req: NSFetchRequest<JournalEntry> = JournalEntry.fetchRequest()
        req.fetchLimit = 1
        req.predicate = NSPredicate(format: "day >= %@ AND day < %@", start as NSDate, end as NSDate)
        return try? moc.fetch(req).first
    }

    @MainActor
    private func saveNowIfNeeded(text: String) {
        // If there is an entry, update it; otherwise create one only if text is non-empty
        if let e = fetchEntry() {
            e.text = text
            markUpdated(e)
            try? moc.save()
        } else if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let e = createEntry()
            e.text = text
            markUpdated(e)
            try? moc.save()
        }
    }

    private func markUpdated(_ e: JournalEntry) {
        e.updatedAt = Date()
    }
    private func touch(_ e: JournalEntry) { e.updatedAt = Date(); try? moc.save() }
}
// Save/load image privately
enum ImageStore {
    static func save(_ ui: UIImage) throws -> String {
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(UUID().uuidString + ".jpg")
        guard let data = ui.jpegData(compressionQuality: 0.9) else { throw NSError(domain: "image", code: 0) }
        try data.write(to: url, options: .atomic)
        return url.path
    }
}


private struct EntryEditorPreviewHarness: View {
    @State var selectedDay = Day.start(Date())
    var body: some View {
        EntryEditor(day: selectedDay)
            .padding()
            .tint(Color("AccentColor"))
            .background(Color("BackgroundColor"))
    }
}

#Preview("Interactive • Light") { EntryEditorPreviewHarness() }
#Preview("Interactive • Dark")  {
    EntryEditorPreviewHarness()
        .preferredColorScheme(.dark)
}
#Preview("Editor • NavStack") {
    NavigationStack {
        EntryEditor(day: Calendar.current.startOfDay(for: .now))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar) // optional, if it looks hidden
    }
    .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}

private struct EditorPreviewSheetHost: View {
    @State private var showing = true
    var body: some View {
        Color.clear
            .sheet(isPresented: $showing) {
                NavigationStack {
                    EntryEditor(day: Calendar.current.startOfDay(for: .now))
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbarRole(.editor) // optional: makes Close/Done-style placements feel right
                }
                .tint(Color("AccentColor"))
            }
    }
}

#Preview("Editor • Sheet") {
    EditorPreviewSheetHost()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
