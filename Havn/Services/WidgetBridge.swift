//
//  WidgetBridge.swift
//  Havn
//
//  Created by Zac Seebeck on 8/15/25.
//


import Foundation
import UIKit
import CoreData
import WidgetKit

enum WidgetBridge {
    static func containerURL() -> URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppGroup.id)
    }
    static func stateURL(in container: URL) -> URL { container.appendingPathComponent("widget-state.json") }
    static func thumbURL(in container: URL) -> URL { container.appendingPathComponent("today-thumb.jpg") }

    static func refresh(from ctx: NSManagedObjectContext) {
        guard let container = containerURL() else {
            #if DEBUG
            print("WidgetBridge: App Group container not found. Enable App Groups for both App + Widget and use id:\n\t\(AppGroup.id)")
            #endif
            return
        }
        let stateURL = stateURL(in: container)
        let thumbURL = thumbURL(in: container)

        // Build a private context so we never touch viewContext off-main
        guard let psc = ctx.persistentStoreCoordinator else { return }
        let bg = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        bg.persistentStoreCoordinator = psc
        bg.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())

        var has = false
        var stats = StreakStats(current: 0, best: 0, lastEntryDay: nil)
        var todayImg: UIImage? = nil

        bg.performAndWait {
            has = hasEntry(on: today, ctx: bg)
            stats = Streaks.compute(in: bg)
            todayImg = todayImage(ctx: bg)
        }

        let locked = UserDefaults.standard.bool(forKey: "useBiometricLock")
        let state = WidgetState(hasEntryToday: has, streak: stats.current, bestStreak: stats.best, locked: locked, updatedAt: Date())

        // Write state JSON atomically
        if let data = try? JSONEncoder().encode(state) {
            try? data.write(to: stateURL, options: [.atomic])
        }

        // Write/clear thumbnail atomically
        if has, let img = todayImg, let small = downscale(img, targetW: 480), let jpeg = small.jpegData(compressionQuality: 0.85) {
            try? jpeg.write(to: thumbURL, options: [.atomic])
        } else {
            try? FileManager.default.removeItem(at: thumbURL)
        }

        // Ensure WidgetKit is poked on the main thread to avoid UI publish warnings
        DispatchQueue.main.async {
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    private static func hasEntry(on day: Date, ctx: NSManagedObjectContext) -> Bool {
        let cal = Calendar.current
        let start = cal.startOfDay(for: day)
        let end = cal.date(byAdding: .day, value: 1, to: start)!
        let req: NSFetchRequest<JournalEntry> = JournalEntry.fetchRequest()
        req.fetchLimit = 1
        req.predicate = NSPredicate(format: "day >= %@ AND day < %@", start as NSDate, end as NSDate)
        return ((try? ctx.count(for: req)) ?? 0) > 0
    }

    private static func todayImage(ctx: NSManagedObjectContext) -> UIImage? {
        let cal = Calendar.current
        let start = cal.startOfDay(for: Date())
        let end = cal.date(byAdding: .day, value: 1, to: start)!
        let req: NSFetchRequest<JournalEntry> = JournalEntry.fetchRequest()
        req.fetchLimit = 1
        req.predicate = NSPredicate(format: "day >= %@ AND day < %@", start as NSDate, end as NSDate)
        guard let e = try? ctx.fetch(req).first, let data = e.photoData else { return nil }
        return UIImage(data: data)
    }

    private static func downscale(_ img: UIImage, targetW: CGFloat) -> UIImage? {
        let scale = targetW / max(1, img.size.width)
        let size = CGSize(width: img.size.width * scale, height: img.size.height * scale)
        let r = UIGraphicsImageRenderer(size: size)
        return r.image { _ in img.draw(in: CGRect(origin: .zero, size: size)) }
    }
}
