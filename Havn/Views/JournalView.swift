//
//  JournalView.swift
//  Havn
//
//  Created by Zac Seebeck on 8/9/25.
//

import SwiftUI
import CoreData


struct JournalView: View {
    @State private var selected = Calendar.current.startOfDay(for: Date())
    @State private var expanded = false
    @Environment(\.managedObjectContext) private var moc
    @Environment(\.scenePhase) private var scenePhase

    // swipe state
    @State private var dragX: CGFloat = 0
    @State private var nextDay: Date? = nil
    @State private var isLeftSwipe = false
    let gap: CGFloat = 16

    // editor presentation
    @State private var showEditor = false
    @State private var editingDay: Date? = nil
    
    // Forces DayPhotoCard to rebuild after editor saves
    @State private var cardRefreshNonce = UUID()
    
    private func hasEntry(on day: Date) -> Bool {
        let cal = Calendar.current
        let start = cal.startOfDay(for: day)
        let end = cal.date(byAdding: .day, value: 1, to: start)!
        let req: NSFetchRequest<JournalEntry> = JournalEntry.fetchRequest()
        req.predicate = NSPredicate(format: "day >= %@ AND day < %@", start as NSDate, end as NSDate)
        req.fetchLimit = 1
        return (try? moc.count(for: req)) ?? 0 > 0
    }

    private func refreshWidgetAsync() {
        let ctx = moc
        ctx.perform {
            WidgetBridge.refresh(from: ctx)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            WeekMonthExpandable(selectedDay: $selected, isExpanded: expanded)
            GeometryReader { proxy in
                let width = proxy.size.width

                ZStack {
                    // Incoming card
                    if let incoming = nextDay {
                        DayPhotoCard(day: incoming, fillsSpace: true, onTap: {
                            editingDay = incoming
                            showEditor = true
                        })
                        .offset(x: isLeftSwipe ? (width + gap + dragX) : (-width - gap + dragX))
                        .transition(.identity)
                        .id("incoming-\(incoming.timeIntervalSinceReferenceDate)-\(cardRefreshNonce.uuidString)")
                        .zIndex(1)
                    }

                    // Current card
                    DayPhotoCard(day: selected, fillsSpace: true, onTap: {
                        editingDay = selected
                        showEditor = true
                    })
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Entry for \(selected.formatted(.dateTime.month().day().year()))")
                    .accessibilityHint("Double-tap to edit")
                    .accessibilityAddTraits(.isButton)
                    .id("current-\(selected.timeIntervalSinceReferenceDate)-\(cardRefreshNonce.uuidString)")
                    .offset(x: dragX)
                    .zIndex(0)
                    
                    DayEntryOverlay(
                        day: selected,
                        onAdd: {
                            editingDay = selected; showEditor = true
                            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                        }
                    )
                    .transition(.opacity)
                    .id(selected)
                }
                .frame(width: width, height: proxy.size.height)
                .contentShape(Rectangle())
                .gesture(expanded ? nil : swipeGesture(width: width))
            }
            .padding(.horizontal, 16)
            .padding(.bottom,6)
            .padding(.top, 16)
            StreakPill()
                .padding(.horizontal, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color("BackgroundColor").ignoresSafeArea(edges: .bottom))
        .toolbar(.hidden, for: .navigationBar)
        .fullScreenCover(isPresented: $showEditor) {
            NavigationStack {
                EntryEditor(day: editingDay ?? selected)
                    .navigationTitle((editingDay ?? selected)
                        .formatted(date: .abbreviated, time: .omitted))
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") { showEditor = false }
                        }
                    }
            }
            .tint(Color("AccentColor"))
        }
        .onChange(of: showEditor) { oldValue, newValue in
            if newValue == false { // editor just closed
                // force DayPhotoCard to rebuild using a fresh ID
                cardRefreshNonce = UUID()
                refreshWidgetAsync()
            }
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .active {
                refreshWidgetAsync()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSPersistentStoreRemoteChange).receive(on: RunLoop.main)) { _ in
            refreshWidgetAsync()
        }
        .onAppear() {
            refreshWidgetAsync()
        }
    }

    // MARK: - Gesture

    private func swipeGesture(width: CGFloat) -> some Gesture {
        let cal = Calendar.current
        func isToday(_ d: Date) -> Bool { cal.isDate(d, inSameDayAs: cal.startOfDay(for: Date())) }
        
        return DragGesture(minimumDistance: 15)
            .onChanged { v in
                dragX = v.translation.width
                
                if dragX < 0, isToday(selected) {
                    dragX = max(CGFloat(-80), dragX / 6)   // resist and cap
                    nextDay = nil
                    isLeftSwipe = true
                    return
                }

                
                if dragX < 0 { isLeftSwipe = true;  nextDay = clampedStep(+1) }  // next
                else if dragX > 0 { isLeftSwipe = false; nextDay = clampedStep(-1) } // prev
                else { nextDay = nil }
            }
            .onEnded { v in
                let t = v.translation.width
                let vPred = v.predictedEndTranslation.width
                let shouldSwitch = abs(t) > 60 || abs(vPred) > 120

                guard shouldSwitch, let incoming = nextDay else {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) { dragX = 0 }
                    nextDay = nil
                    return
                }

                let off = isLeftSwipe ? -(width + gap) : (width + gap)
                withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) { dragX = off }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
                    selected = incoming
                    dragX = 0
                    nextDay = nil
                }
                Haptics.light()
            }
    }

    // MARK: - Helpers

    private func clampedStep(_ delta: Int) -> Date {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let stepped = cal.date(byAdding: .day, value: delta, to: selected) ?? selected
        return min(today, cal.startOfDay(for: stepped))
    }
}
private enum SwipeDir { case left, right, none }

private struct DayEntryOverlay: View {
    let day: Date
    let onAdd: () -> Void

    @FetchRequest private var entries: FetchedResults<JournalEntry>

    init(day: Date, onAdd: @escaping () -> Void) {
        self.day = day
        self.onAdd = onAdd
        let cal = Calendar.current
        let start = cal.startOfDay(for: day)
        let end = cal.date(byAdding: .day, value: 1, to: start)!
        let predicate = NSPredicate(format: "day >= %@ AND day < %@", start as NSDate, end as NSDate)
        _entries = FetchRequest(sortDescriptors: [], predicate: predicate)
    }

    var body: some View {
        Group {
            if entries.isEmpty {
                VStack {
                    Spacer()
                    Button(action: onAdd) {
                        HStack(spacing: 8) {
                            Image(systemName: "plus.circle.fill")
                            Text("Add today’s entry")
                                .font(HavnTheme.Typeface.callout)
                                .fontWeight(.semibold)
                        }
                        .padding(.horizontal, 14).padding(.vertical, 12)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(.ultraThinMaterial)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.white.opacity(0.15), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
        }
    }
}

#Preview("Interactive • Light") {
    JournalView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}

#Preview("Interactive • Dark") {
    JournalView()
        .preferredColorScheme(.dark)
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
