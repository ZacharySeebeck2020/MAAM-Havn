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
    @FocusState private var textFocused: Bool
    private let maxSuggestedWidth: CGFloat = 700

    // Vitals (UI state lifted up for persistence)
    @State private var moodScore: Double = 3
    @State private var energyScore: Double = 3
    @State private var weatherScore: Double = 3
    @State private var tags: [String] = []
    // Known tags aggregated across entries (for suggestions)
    @State private var knownTags: [String] = []
    
    @MainActor
    private func scheduleSave(debounce: Double = 0.75) {
        saveTask?.cancel()
        let snapshot = draftText // capture latest
        saveTask = Task {
            await MainActor.run { isSaving = true }
            try? await Task.sleep(nanoseconds: UInt64(debounce * 1_000_000_000))
            if Task.isCancelled { await MainActor.run { isSaving = false }; return }
            await MainActor.run {
                saveNowIfNeeded(text: snapshot)
                isSaving = false
            }
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
    
    @MainActor
    private func markUpdated(_ e: JournalEntry) {
        e.updatedAt = Date()
    }
    @MainActor private func touch(_ e: JournalEntry) { e.updatedAt = Date(); try? moc.save() }
    
    // MARK: - Persistence helpers for optional attributes
    private func supportsAttr(_ key: String) -> Bool {
        guard let e = entries.first else { return false }
        return e.entity.attributesByName.keys.contains(key)
    }

    private func getInt16(_ key: String, default def: Int16 = 3) -> Int16 {
        guard let e = entries.first, supportsAttr(key), let num = e.value(forKey: key) as? NSNumber else { return def }
        return num.int16Value
    }

    @MainActor
    private func setInt16(_ key: String, _ val: Int16) {
        moc.perform {
            guard let e = entries.first else { return }
            guard supportsAttr(key) else { return }
            e.setValue(NSNumber(value: val), forKey: key)
            markUpdated(e)
            try? moc.save()
        }
    }

    // Legacy getTagsArray removed; relationship only.

    @MainActor
    private func setTagsArray(_ arr: [String]) {
        moc.perform {
            guard let e = entries.first else { return }
            let desiredNames = arr.map(normalizeTag).filter { !$0.isEmpty }
            var objects = [NSManagedObject]()
            for name in desiredNames {
                if let tag = fetchOrCreateTag(named: name) { objects.append(tag) }
            }
            let rel = e.mutableSetValue(forKey: "tagsRel")
            rel.removeAllObjects()
            rel.addObjects(from: objects)
            markUpdated(e)
            try? moc.save()
        }
    }

    // MARK: - Tag helpers (discovery + normalization)
    private func normalizeTag(_ s: String) -> String {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        let squashed = trimmed.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        return squashed
    }

    @MainActor
    private func refreshKnownTags(limit: Int = 500) {
        knownTags = fetchAllTagNames(limit: limit)
    }

    // MARK: - Shared Tag model (optional, runtime-detected)
    @MainActor
    private func hasTagEntity() -> Bool {
        guard let psc = moc.persistentStoreCoordinator else { return false }
        return psc.managedObjectModel.entitiesByName.keys.contains("Tag")
    }
    @MainActor
    private func journalSupportsTagRel() -> Bool {
        guard let e = entries.first else { return false }
        return e.entity.relationshipsByName.keys.contains("tagsRel")
    }
    @MainActor
    private func fetchOrCreateTag(named raw: String) -> NSManagedObject? {
        guard hasTagEntity() else { return nil }
        let name = normalizeTag(raw)
        // Try fetch existing by case-insensitive name
        let req = NSFetchRequest<NSManagedObject>(entityName: "Tag")
        req.fetchLimit = 1
        req.predicate = NSPredicate(format: "name =[c] %@", name)
        if let found = try? moc.fetch(req).first { return found }
        // Create new Tag using entity description
        guard let entity = NSEntityDescription.entity(forEntityName: "Tag", in: moc) else { return nil }
        let tag = NSManagedObject(entity: entity, insertInto: moc)
        tag.setValue(name, forKey: "name")
        return tag
    }
    @MainActor
    private func fetchAllTagNames(limit: Int = 500) -> [String] {
        guard hasTagEntity() else { return [] }
        let req = NSFetchRequest<NSManagedObject>(entityName: "Tag")
        req.fetchLimit = limit
        req.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true, selector: #selector(NSString.localizedCaseInsensitiveCompare(_:)))]
        let names = (try? moc.fetch(req))?.compactMap { $0.value(forKey: "name") as? String } ?? []
        return names
    }

    @MainActor
    private func getRelationalTags() -> [String] {
        guard journalSupportsTagRel(), let e = entries.first else { return [] }
        if let set = e.value(forKey: "tagsRel") as? NSSet {
            let arr = set.compactMap { ($0 as? NSManagedObject)?.value(forKey: "name") as? String }
            return arr.map(normalizeTag)
        }
        return []
    }

    @ViewBuilder
    private var backgroundLayer: some View {
        GeometryReader { geo in
            if let data = entries.first?.photoData, let bg = UIImage(data: data) {
                Image(uiImage: bg)
                    .resizable()
                    .scaledToFill()
                    .frame(
                        width: geo.size.width + geo.safeAreaInsets.leading + geo.safeAreaInsets.trailing,
                        height: geo.size.height + geo.safeAreaInsets.top + geo.safeAreaInsets.bottom
                    )
                    .clipped()
                    .overlay(
                        LinearGradient(
                            colors: [Color.black.opacity(0.35), Color.black.opacity(0.15), Color.clear],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .transaction { $0.animation = nil }
            }
        }
    }

    @ViewBuilder
    private func editorLayer(entry: JournalEntry?) -> some View {
        VStack(spacing: 12) {
            // Chips pinned (non-scrolling)
            MetaChipsRow(photoSelection: $photoItem,
                         moodScore: $moodScore,
                         energyScore: $energyScore,
                         weatherScore: $weatherScore,
                         tags: $tags,
                         knownTags: knownTags)
                .padding(.top, 8)
            
            // Editor content fills remaining height; TextEditor scrolls internally
            VStack(spacing: 16) {
                // Text card
                ZStack(alignment: .topLeading) {
                    if draftText.isEmpty {
                        Text("Write about today…")
                            .foregroundStyle(Color("TextMutedColor"))
                            .padding(.horizontal, 18)
                            .padding(.top, 16)
                    }

                    TextEditor(text: Binding(
                        get: { draftText },
                        set: { new in
                            draftText = new
                            scheduleSave(debounce: 0.75)
                        }
                    ))
                    .focused($textFocused)
                    .scrollContentBackground(.hidden)
                    .padding(12)
                }
                .frame(maxWidth: .infinity)
                .frame(minHeight: 220)
                .frame(maxHeight: .infinity, alignment: .top) // fill to bottom, then shrink with keyboard
                .background(.ultraThinMaterial) // match BottomTagsBar material
                .clipShape(RoundedRectangle(cornerRadius: HavnTheme.Radius.card, style: .continuous))
            }
            .padding(.top, 8)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top) // ensure ZStack fills the screen so the background reaches the bottom
        .scrollDismissesKeyboard(.interactively)
    }

    // MARK: - Lightweight Helper Builders
    @ToolbarContentBuilder
    private func editorToolbar() -> some ToolbarContent {
        ToolbarItemGroup(placement: .keyboard) {
            HStack(spacing: 12) {
                Text("\(draftText.count) chars")
                    .font(.caption)
                    .foregroundStyle(Color("TextMutedColor"))
                Spacer()
                Button("Done") { textFocused = false }
                    .font(.body.weight(.semibold))
            }
        }
        ToolbarItem(placement: .principal) {
            VStack(spacing: 2) {
                Text(toolbarTitle)
                    .font(.headline)
                if isSaving {
                    Label("Saving…", systemImage: "arrow.triangle.2.circlepath")
                        .font(.caption2)
                        .labelStyle(.titleAndIcon)
                        .foregroundStyle(Color("TextMutedColor"))
                }
            }
        }
        ToolbarItem(placement: .navigationBarTrailing) {
            Button {
                let e = entries.first ?? createEntry()
                e.isStarred.toggle()
                scheduleSave()
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } label: {
                Image(systemName: (entries.first?.isStarred ?? false) ? "star.fill" : "star")
                    .symbolRenderingMode(.hierarchical)
            }
            .accessibilityLabel((entries.first?.isStarred ?? false) ? "Unstar" : "Star")
        }
    }

    private var toolbarTitle: String {
        day.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day().year())
    }

    @MainActor
    private func handleMoodChange(_ newVal: Double) { setInt16("moodScore", Int16(max(1, min(5, Int(newVal.rounded()))))) }
    @MainActor
    private func handleEnergyChange(_ newVal: Double) { setInt16("energyScore", Int16(max(1, min(5, Int(newVal.rounded()))))) }
    @MainActor
    private func handleWeatherChange(_ newVal: Double) { setInt16("weatherScore", Int16(max(1, min(5, Int(newVal.rounded()))))) }

    private func handleTagsChange(_ newArr: [String]) {
        Task { await MainActor.run { setTagsArray(newArr) } }
    }

    private func seedOnAppear() {
        if let e = entries.first { draftText = e.text ?? "" }
        moodScore = Double(getInt16("moodScore"))
        energyScore = Double(getInt16("energyScore"))
        weatherScore = Double(getInt16("weatherScore"))
        tags = getRelationalTags()
        refreshKnownTags()
    }

    private func finalizeOnDisappear() {
        saveTask?.cancel()
        saveNowIfNeeded(text: draftText)
    }

    private func handlePhotoChange(_ item: PhotosPickerItem?) async {
        guard let data = try? await item?.loadTransferable(type: Data.self) else { return }
        await MainActor.run {
            let e = entries.first ?? createEntry()
            if let ui = UIImage(data: data), let jpeg = ui.jpegData(compressionQuality: 0.9) {
                e.photoData = jpeg
            } else {
                e.photoData = data
            }
            touch(e)
        }
    }

    @ViewBuilder
    private var rootStack: some View {
        ZStack {
            AnyView(backgroundLayer)
            AnyView(editorLayer(entry: entries.first))
        }
    }

    var body: some View {
        rootStack
            .safeAreaInset(edge: .bottom) {
                if !tags.isEmpty {
                    BottomTagsBar(tags: $tags)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .onChange(of: photoItem) { _, item in
                Task { await handlePhotoChange(item) }
            }
            .onChange(of: moodScore) { _, v in handleMoodChange(v) }
            .onChange(of: energyScore) { _, v in handleEnergyChange(v) }
            .onChange(of: weatherScore) { _, v in handleWeatherChange(v) }
            .onChange(of: tags) { _, arr in handleTagsChange(arr) }
            .onChange(of: tags) { _, _ in refreshKnownTags() }
            .onAppear { seedOnAppear() }
            .onDisappear { finalizeOnDisappear() }
            .toolbar { editorToolbar() }
    }
}

struct Pressable: ButtonStyle {
    var scale: CGFloat = 0.96
    var hapticStyle: UIImpactFeedbackGenerator.FeedbackStyle = .soft

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, pressed in
                if pressed { UIImpactFeedbackGenerator(style: hapticStyle).impactOccurred() }
            }
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

#Preview("Interactive • Light") {
    EntryEditorPreviewHarness()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
#Preview("Interactive • Dark")  {
    EntryEditorPreviewHarness()
        .preferredColorScheme(.dark)
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
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
