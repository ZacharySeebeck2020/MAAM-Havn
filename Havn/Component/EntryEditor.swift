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
    
    // MARK: - Persistence helpers for optional attributes
    private func supportsAttr(_ key: String) -> Bool {
        guard let e = entries.first else { return false }
        return e.entity.attributesByName.keys.contains(key)
    }

    private func getInt16(_ key: String, default def: Int16 = 3) -> Int16 {
        guard let e = entries.first, supportsAttr(key), let num = e.value(forKey: key) as? NSNumber else { return def }
        return num.int16Value
    }

    private func setInt16(_ key: String, _ val: Int16) {
        guard let e = entries.first else { return }
        guard supportsAttr(key) else { return }
        e.setValue(NSNumber(value: val), forKey: key)
        markUpdated(e)
        try? moc.save()
    }

    // Legacy getTagsArray removed; relationship only.

    private func setTagsArray(_ arr: [String]) {
        guard let e = entries.first else { return }
        let desiredNames = arr.map(normalizeTag).filter { !$0.isEmpty }
        // Build Tag objects
        var objects = [NSManagedObject]()
        for name in desiredNames {
            if let tag = fetchOrCreateTag(named: name) { objects.append(tag) }
        }
        // Replace the relationship via a mutable set to avoid KVC type pitfalls
        let rel = e.mutableSetValue(forKey: "tagsRel")
        rel.removeAllObjects()
        rel.addObjects(from: objects)
        markUpdated(e)
        try? moc.save()
    }

    // MARK: - Tag helpers (discovery + normalization)
    private func normalizeTag(_ s: String) -> String {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        let squashed = trimmed.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        return squashed
    }

    private func refreshKnownTags(limit: Int = 500) {
        knownTags = fetchAllTagNames(limit: limit)
    }

    // MARK: - Shared Tag model (optional, runtime-detected)
    private func hasTagEntity() -> Bool {
        guard let psc = moc.persistentStoreCoordinator else { return false }
        return psc.managedObjectModel.entitiesByName.keys.contains("Tag")
    }
    private func journalSupportsTagRel() -> Bool {
        guard let e = entries.first else { return false }
        return e.entity.relationshipsByName.keys.contains("tagsRel")
    }
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
    private func fetchAllTagNames(limit: Int = 500) -> [String] {
        guard hasTagEntity() else { return [] }
        let req = NSFetchRequest<NSManagedObject>(entityName: "Tag")
        req.fetchLimit = limit
        req.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true, selector: #selector(NSString.localizedCaseInsensitiveCompare(_:)))]
        let names = (try? moc.fetch(req))?.compactMap { $0.value(forKey: "name") as? String } ?? []
        return names
    }

    private func getRelationalTags() -> [String] {
        guard journalSupportsTagRel(), let e = entries.first else { return [] }
        if let set = e.value(forKey: "tagsRel") as? NSSet {
            let arr = set.compactMap { ($0 as? NSManagedObject)?.value(forKey: "name") as? String }
            return arr.map(normalizeTag)
        }
        return []
    }

    var body: some View {
        let entry = entries.first  // may be nil on first load
        
        return ZStack {
            // Editor background from today's featured photo (if any)
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
                }
            }
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
                    .background(
                        RoundedRectangle(cornerRadius: HavnTheme.Radius.card)
                            .fill(Color("CardSurfaceColor").opacity(0.6))
                    )
                    .clipShape(RoundedRectangle(cornerRadius: HavnTheme.Radius.card, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: HavnTheme.Radius.card, style: .continuous)
                            .stroke(Color("AccentColor").opacity(0.25), lineWidth: 1)
                    )
                }
                .padding(.top, 8)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top) // ensure ZStack fills the screen so the background reaches the bottom
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: photoItem) { _, item in
                Task {
                    guard let data = try? await item?.loadTransferable(type: Data.self) else { return }
                    let e = entries.first ?? createEntry()
                    if let ui = UIImage(data: data), let jpeg = ui.jpegData(compressionQuality: 0.9) {
                        e.photoData = jpeg
                    } else {
                        e.photoData = data
                    }
                    touch(e) // saves and updates updatedAt
                }
            }
            .onChange(of: moodScore) { _, newVal in
                let v = Int16(max(1, min(5, Int(newVal.rounded()))))
                setInt16("moodScore", v)
            }
            .onChange(of: energyScore) { _, newVal in
                let v = Int16(max(1, min(5, Int(newVal.rounded()))))
                setInt16("energyScore", v)
            }
            .onChange(of: weatherScore) { _, newVal in
                let v = Int16(max(1, min(5, Int(newVal.rounded()))))
                setInt16("weatherScore", v)
            }
            .onChange(of: tags) { _, newArr in
                setTagsArray(newArr)
            }
            .onChange(of: tags) { _, _ in
                refreshKnownTags()
            }
            .onAppear {
                // If CloudKit already brought the entry, seed the editor text
                if let e = entries.first { draftText = e.text ?? "" }
                // Seed vitals/tags from existing entry if attributes exist
                moodScore = Double(getInt16("moodScore"))
                energyScore = Double(getInt16("energyScore"))
                weatherScore = Double(getInt16("weatherScore"))
                tags = getRelationalTags()
                refreshKnownTags()
            }
            .toolbar {
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
                            Label("Saving…", systemImage: "arrow.triangle.2.circlepath")
                                .font(.caption2)
                                .labelStyle(.titleAndIcon)
                                .foregroundStyle(Color("TextMutedColor"))
                        }
                    }
                }
                
                // Trailing: Star toggle
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        let e = entry ?? createEntry()
                        e.isStarred.toggle()
                        scheduleSave()
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        Image(systemName: (entry?.isStarred ?? false) ? "star.fill" : "star")
                            .symbolRenderingMode(.hierarchical)
                    }
                    .accessibilityLabel((entry?.isStarred ?? false) ? "Unstar" : "Star")
                }
            }
        }
    }
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

// MARK: - Chips + Pickers (UI only, no persistence yet)

private enum ChipKind: String, Identifiable {
    case mood, energy, weather, tags
    var id: String { rawValue }
}

private struct PillChip: View {
    let title: String
    let icon: String?
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon { Image(systemName: icon).imageScale(.small) }
                Text(title)
                    .font(.callout.weight(.semibold))
            }
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(Color.accentColor.opacity(0.7))
            )
        }
        .buttonStyle(.plain)
    }
}

private struct MetaChipsRow: View {
    @Binding var photoSelection: PhotosPickerItem?
    @Binding var moodScore: Double
    @Binding var energyScore: Double
    @Binding var weatherScore: Double
    @Binding var tags: [String]
    let knownTags: [String]
    @State private var showPickerFor: ChipKind? = nil

    var body: some View {
        VStack() {
            HStack(spacing: 3) {
                PillChip(
                    title: "Mood: " + emoji(for: moodScore, kind: .mood),
                    icon: nil,
                    isActive: moodScore != 3
                ) { showPickerFor = .mood }

                PillChip(
                    title: "Energy: " + emoji(for: energyScore, kind: .energy),
                    icon: nil,
                    isActive: energyScore != 3
                ) { showPickerFor = .energy }
                PillChip(
                    title: "Weather: " + emoji(for: weatherScore, kind: .weather),
                    icon: nil,
                    isActive: weatherScore != 3
                ) { showPickerFor = .weather }
            }
            HStack(spacing: 8) {
                PillChip(
                    title: tags.isEmpty ? "Tags" : "Tags: " + tags.joined(separator: ", "),
                    icon: "tag.fill",
                    isActive: !tags.isEmpty
                ) { showPickerFor = .tags }
                PhotosPicker(selection: $photoSelection, matching: .images) {
                    HStack(spacing: 6) {
                        Image(systemName: "camera.fill")
                            .imageScale(.small)
                            .foregroundColor(.black)
                        Text("Set Today’s Image")
                            .font(.callout.weight(.semibold))
                            .foregroundColor(.black)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(
                        Capsule()
                            .fill(Color.accentColor.opacity(0.7))
                    )
                    .contentShape(Capsule())
                }
            }
            
        }
        .sheet(item: $showPickerFor) { kind in
            switch kind {
            case .mood:
                VitalsSliderSheet(kind: .mood, value: $moodScore)
                    .presentationDetents([.height(90), .medium])
                    .presentationDragIndicator(.visible)
            case .energy:
                VitalsSliderSheet(kind: .energy, value: $energyScore)
                    .presentationDetents([.height(90), .medium])
                    .presentationDragIndicator(.visible)
            case .weather:
                VitalsSliderSheet(kind: .weather, value: $weatherScore)
                    .presentationDetents([.height(90), .medium])
                    .presentationDragIndicator(.visible)
            case .tags:
                ChipPickerSheet(
                    kind: .tags,
                    mood: .constant(nil),
                    energy: .constant(nil),
                    weather: .constant(nil),
                    tags: $tags,
                    knownTags: knownTags
                )
                .presentationDetents([.height(360), .medium])
                .presentationDragIndicator(.visible)
            }
        }
    }

    private func emojis(for kind: ChipKind) -> [String] {
        switch kind {
        case .mood:    return ["😞","😌","😐","🙂","😄"]
        case .energy:  return ["🥱","😴","🙂","⚡️","🚀"]
        case .weather: return ["🌧️","☁️","🌤️","☀️","🌈"]
        case .tags:    return []
        }
    }

    private func emoji(for value: Double, kind: ChipKind) -> String {
        let idx = max(1, min(5, Int(value.rounded()))) - 1
        let arr = emojis(for: kind)
        guard arr.indices.contains(idx) else { return "" }
        return arr[idx]
    }
}

private struct VitalsSliderSheet: View {
    let kind: ChipKind // expects .mood/.energy/.weather
    @Binding var value: Double

    private var title: String {
        switch kind {
        case .mood: return "Set Mood"
        case .energy: return "Set Energy"
        case .weather: return "Set Weather"
        case .tags: return "" // not used here
        }
    }

    private var emojis: [String] {
        switch kind {
        case .mood:    return ["😞","😌","😐","🙂","😄"]
        case .energy:  return ["🥱","😴","🙂","⚡️","🚀"]
        case .weather: return ["🌧️","☁️","🌤️","☀️","🌈"]
        case .tags:    return []
        }
    }

    var body: some View {
        GeometryReader { g in
            VStack(spacing: 8) {
                // Emoji scale spans slider width, slightly above it
                HStack(spacing: 0) {
                    let count = max(1, emojis.count)
                    ForEach(Array(emojis.enumerated()), id: \.offset) { idx, e in
                        let selected = (idx == Int(value.rounded()) - 1)
                        Text(e)
                            .font(selected ? .title2 : .title3)
                            .opacity(selected ? 1.0 : 0.65)
                            .frame(width: g.size.width / CGFloat(count), alignment: .center)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    value = Double(idx + 1)
                                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                                }
                            }
                            .accessibilityLabel("\(title) level \(idx + 1)")
                    }
                }
                .offset(y: -2)

                Slider(value: $value, in: 1...5, step: 1)
                    .tint(Color.accentColor)
                    .padding(.horizontal, 20)
            }
            .padding(.top, 20)
            .frame(maxHeight: .infinity, alignment: .center) // center vertically within sheet height
        }
        .frame(minHeight: 90) // supports the small detent height
    }
}

private struct ChipPickerSheet: View {
    let kind: ChipKind
    @Binding var mood: String?
    @Binding var energy: String?
    @Binding var weather: String?
    @Binding var tags: [String]
    var knownTags: [String]? = nil

    @State private var newTagText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title).font(.headline).padding(.horizontal).padding(.vertical)

            switch kind {
            case .mood:
                SelectGrid(options: ["Calm","Happy","Focused","Grateful","Anxious","Low"], selection: Binding(
                    get: { mood ?? "" }, set: { mood = $0.isEmpty ? nil : $0 }
                ))
            case .energy:
                SelectGrid(options: ["Low","Steady","High"], selection: Binding(
                    get: { energy ?? "" }, set: { energy = $0.isEmpty ? nil : $0 }
                ))
            case .weather:
                SelectGrid(options: ["Clear","Cloudy","Rain","Snow"], selection: Binding(
                    get: { weather ?? "" }, set: { weather = $0.isEmpty ? nil : $0 }
                ))
            case .tags:
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "tag").imageScale(.small)
                        TextField("Search or add a tag…", text: $newTagText)
                            .textFieldStyle(.roundedBorder)
                            .submitLabel(.done)
                            .onSubmit {
                                let t = newTagText.trimmingCharacters(in: .whitespacesAndNewlines)
                                guard !t.isEmpty else { return }
                                let norm = t
                                if !tags.contains(where: { $0.caseInsensitiveCompare(norm) == .orderedSame }) {
                                    tags.append(norm)
                                }
                                newTagText = ""
                            }
                        Button("Add") {
                            let t = newTagText.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !t.isEmpty else { return }
                            let norm = t
                            if !tags.contains(where: { $0.caseInsensitiveCompare(norm) == .orderedSame }) {
                                tags.append(norm)
                            }
                            newTagText = ""
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(.horizontal)

                    // Suggestions (from knownTags)
                    if let known = knownTags {
                        let filtered = known.filter { q in
                            newTagText.isEmpty || q.localizedCaseInsensitiveContains(newTagText)
                        }.filter { k in
                            !tags.contains(where: { $0.caseInsensitiveCompare(k) == .orderedSame })
                        }
                        if !filtered.isEmpty {
                            Text("Suggestions").font(.caption).padding(.horizontal)
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 8)], alignment: .leading, spacing: 8) {
                                ForEach(filtered, id: \.self) { k in
                                    Button {
                                        tags.append(k)
                                    } label: {
                                        HStack(spacing: 6) {
                                            Text(k).font(.callout.weight(.semibold))
                                            Image(systemName: "plus.circle.fill").imageScale(.small)
                                        }
                                        .padding(.horizontal, 10).padding(.vertical, 6)
                                        .background(Capsule().fill(Color.accentColor.opacity(0.14)))
                                        .overlay(Capsule().stroke(Color.accentColor.opacity(0.3), lineWidth: 1))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }

                    // Selected tags
                    FlowTags(tags: tags, onRemove: { tag in
                        tags.removeAll { $0.caseInsensitiveCompare(tag) == .orderedSame }
                    })
                }
            }

            Spacer(minLength: 0)
        }
    }

    private var title: String {
        switch kind {
        case .mood: "Set Mood"
        case .energy: "Set Energy"
        case .weather: "Set Weather"
        case .tags: "Manage Tags"
        }
    }
}

private struct SelectGrid: View {
    let options: [String]
    @Binding var selection: String

    let columns = [GridItem(.adaptive(minimum: 96), spacing: 8, alignment: .leading)]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            ForEach(options, id: \.self) { opt in
                let active = selection == opt
                PillChip(title: opt, icon: nil, isActive: active) {
                    selection = (active ? "" : opt)
                }
            }
        }
        .padding(.horizontal)
    }
}

private struct FlowTags: View {
    let tags: [String]
    let onRemove: (String) -> Void

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 80), spacing: 8)], alignment: .leading, spacing: 8) {
            ForEach(tags, id: \.self) { tag in
                HStack(spacing: 6) {
                    Text(tag).font(.callout.weight(.semibold))
                    Button(role: .destructive) {
                        onRemove(tag)
                    } label: {
                        Image(systemName: "xmark.circle.fill").imageScale(.small)
                    }
                }
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(Capsule().fill(Color.accentColor.opacity(0.14)))
                .overlay(Capsule().stroke(Color.accentColor.opacity(0.3), lineWidth: 1))
            }
        }
        .padding(.horizontal)
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
