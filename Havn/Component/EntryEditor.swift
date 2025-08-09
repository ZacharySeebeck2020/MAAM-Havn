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
                                    .font(.callout)
                                    .foregroundStyle(Color("TextMutedColor"))
                            )
                    }
                }
                .frame(height: 180)
                .clipShape(RoundedRectangle(cornerRadius: 16))
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
                get: { entry?.text ?? draftText },
                set: { new in
                    if let e = entry {
                        e.text = new; touch(e)
                    } else {
                        draftText = new
                        if !new.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            let e = createEntry()
                            e.text = new; touch(e)
                        }
                    }
                }
            ))
            .frame(minHeight: 220)
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 16).fill(Color("CardSurfaceColor")))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color("AccentColor").opacity(0.25), lineWidth: 1))

            HStack {
                Button((entry?.isStarred ?? false) ? "Starred ★" : "Star ☆") {
                    let e = entry ?? createEntry()
                    e.isStarred.toggle(); touch(e)
                }
                Spacer()
                Button("Done") { try? moc.save() }
                    .buttonStyle(.borderedProminent)
                    .tint(Color("AccentColor"))
            }
        }
        .padding(.horizontal)
        .onAppear {
            // If CloudKit already brought the entry, seed the editor text
            if let e = entries.first { draftText = e.text ?? "" }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to:nil, from:nil, for:nil) }
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
