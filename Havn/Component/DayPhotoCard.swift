//
//  DayPhotoCard.swift
//  Havn
//
//  Created by Zac Seebeck on 8/10/25.
//

import SwiftUI
import CoreData
import UIKit

/// Rounded photo card for a specific day. Loads the day's JournalEntry and shows its photo (if any).
struct DayPhotoCard: View {
    @Environment(\.managedObjectContext) private var moc

    let day: Date
    var aspect: CGFloat = 4.0/5.0
    var maxLines: Int = 3
    var cornerRadius: CGFloat = 16
    var fillsSpace: Bool = true
    var onTap: (() -> Void)? = nil

    @State private var image: UIImage?
    @State private var snippet: String?


    var body: some View {
        let shape = RoundedRectangle(cornerRadius: HavnTheme.Radius.card, style: .continuous)
        
        let card = shape
            .fill(Color("CardSurfaceColor"))                // base fill (also defines bounds)
            .overlay(                                       // image is confined to the shape
                ZStack (alignment: .bottom) {
                    if let img = image {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFill()
                            .clipped()
                    } else {
                        Image(systemName: "photo")
                            .font(.system(size: 28))
                            .foregroundStyle(Color("TextMutedColor"))
                    }
                }
                .clipped()
            )
            .havnBottomFade()
            .clipped()
            .clipShape(shape)
            .overlay(alignment: .bottomLeading) {
                if let t = snippet?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty {
                    SnippetBubble(text: excerpt(t), maxLines: maxLines)
                        .padding(.horizontal, 10)
                        .padding(.bottom, 10)
                }
            }
            .overlay(alignment: .topLeading) {
                Text(day.formatted(.dateTime.month(.abbreviated).day()))
                    .font(HavnTheme.Typeface.body)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .havnBubbleBackground()
                    .padding(10)
                    
            }
            .overlay(alignment: .topTrailing) {
                Button { onTap?() } label: {
                    Image(systemName: "square.and.pencil")
                        .font(.headline.weight(.semibold))
                        .frame(width: 36, height: 36)
                        .havnBubbleBackground()
                }
                .buttonStyle(.plain)
                .padding(10)
            }
            .contentShape(shape)
            .onTapGesture { onTap?() }
            .onAppear(perform: load)
            .onChange(of: day) { _, _ in load() }
            .havnCardStroke()
        
        Group {
            if fillsSpace {
                card.frame(maxWidth: .infinity, maxHeight: .infinity)   // fill parent
            } else {
                card.aspectRatio(aspect, contentMode: .fit)             // keep ratio
            }
        }
        .onAppear(perform: load)
        .onChange(of: day) { _, _ in load() }
    }
    
    // MARK: - Bubble

    private struct SnippetBubble: View {
        let text: String
        var maxLines: Int

        var body: some View {
            HStack(spacing: 8) {
                Text(text)
                    .font(HavnTheme.Typeface.body)
                    .foregroundStyle(.white)
                    .lineLimit(maxLines)
                    .multilineTextAlignment(.leading)
                Image(systemName: "chevron.right")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.9))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .havnBubbleBackground()
        }
    }

    // MARK: - Data load
    private func load() {
        // ensure context is wired
        guard let psc = moc.persistentStoreCoordinator,
              !psc.persistentStores.isEmpty else { return }

        let cal = Calendar.current
        let start = cal.startOfDay(for: day)
        let end   = cal.date(byAdding: .day, value: 1, to: start)!

        let req: NSFetchRequest<JournalEntry> = JournalEntry.fetchRequest()
        req.fetchLimit = 1
        req.predicate = NSPredicate(format: "day >= %@ AND day < %@", start as NSDate, end as NSDate)

        let key = "day:\(start.timeIntervalSince1970)"
        if let cached = ImagePipeline.shared.image(forKey: key) {
            image = cached
            snippet = try? moc.fetch(req).first?.text
            return
        }

        if let e = try? moc.fetch(req).first {
            snippet = e.text
            if let data = e.photoData,
               let ui   = ImagePipeline.shared.downsampledImage(from: data) {
                ImagePipeline.shared.store(ui, forKey: key)
                image = ui
            } else {
                image = nil
            }
        } else {
            image = nil
            snippet = nil
        }
    }
    
    private func excerpt(_ s: String, limit: Int = 120) -> String {
        let oneLine = s.replacingOccurrences(of: "\n", with: " ")
        return oneLine.count > limit ? String(oneLine.prefix(limit - 1)) + "…" : oneLine
    }
}

// MARK: - Previews

private struct DayPhotoCard_Previews: View {
    @Environment(\.managedObjectContext) private var moc
    @State private var today = Calendar.current.startOfDay(for: Date())
    let shouldExist: Bool

    var body: some View {
        VStack(spacing: 20) {
            DayPhotoCard(day: shouldExist ? today : today.advanced(by: 8640000.0) ) {
            }
        }
        .padding()
        .background(Color("BackgroundColor"))
        .tint(Color("AccentColor"))
    }
}

#Preview("DayPhotoCard • Light") {
    DayPhotoCard_Previews(shouldExist: true)
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .preferredColorScheme(.light)
}

#Preview("DayPhotoCard No Entry • Light") {
    DayPhotoCard_Previews(shouldExist: false)
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .preferredColorScheme(.light)
}

#Preview("DayPhotoCard • Dark") {
    DayPhotoCard_Previews(shouldExist: true)
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .preferredColorScheme(.dark)
}
