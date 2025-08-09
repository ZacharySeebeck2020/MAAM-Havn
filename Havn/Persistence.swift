//
//  Persistence.swift
//  Havn
//
//  Created by Zac Seebeck on 8/3/25.
//

import CoreData
import UIKit

final class PersistenceController {
    // MARK: - Singletons
    static let shared = PersistenceController()

    static let preview: PersistenceController = {
        let pc = PersistenceController(inMemory: true)
        let ctx = pc.container.viewContext
        PreviewData.insertSampleEntries(in: ctx, includePhotos: true)
        try? ctx.save()
        return pc
    }()

    // MARK: - Core
    let container: NSPersistentCloudKitContainer
    private var remoteChangeObserver: NSObjectProtocol?

    // Private so we keep a single shared instance in the app; previews can still call it.
    private init(inMemory: Bool = false) {
        container = NSPersistentCloudKitContainer(name: "Havn") // <- your .xcdatamodeld name

        // Configure store BEFORE loadPersistentStores
        let desc: NSPersistentStoreDescription
        if inMemory {
            desc = NSPersistentStoreDescription()
            desc.url = URL(fileURLWithPath: "/dev/null")
        } else {
            desc = container.persistentStoreDescriptions.first ?? NSPersistentStoreDescription()
            // Point to your CloudKit container (match entitlements exactly)
            let opts = NSPersistentCloudKitContainerOptions(containerIdentifier: "iCloud.work.seebeck.havn")
            desc.cloudKitContainerOptions = opts
        }

        // Helpful options
        desc.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        desc.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        desc.setOption(true as NSNumber, forKey: NSMigratePersistentStoresAutomaticallyOption)
        desc.setOption(true as NSNumber, forKey: NSInferMappingModelAutomaticallyOption)
        container.persistentStoreDescriptions = [desc]

        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

        // Observe CloudKit imports to run de-duplication
        remoteChangeObserver = NotificationCenter.default.addObserver(
            forName: .NSPersistentStoreRemoteChange,
            object: container.persistentStoreCoordinator,
            queue: .main
        ) { [weak self] _ in
            self?.dedupePerDay()
        }

        #if DEBUG
        // Initialize CloudKit schema once in Debug (skip for inMemory)
        if !inMemory {
            do { try container.initializeCloudKitSchema(options: []) }
            catch { print("Schema init:", error) }
        }
        #endif
    }

    deinit {
        if let o = remoteChangeObserver {
            NotificationCenter.default.removeObserver(o)
        }
    }

    // MARK: - “Sync Now” nudge
    @MainActor
    func requestSyncNow() async {
        let viewContext = container.viewContext
        if viewContext.hasChanges { try? viewContext.save() }

        let bg = container.newBackgroundContext()
        await bg.perform {
            let req = NSFetchRequest<NSFetchRequestResult>(entityName: "JournalEntry")
            req.fetchLimit = 1
            if
                let obj = try? bg.fetch(req).first as? NSManagedObject,
                obj.entity.attributesByName["updatedAt"] != nil
            {
                obj.setValue(Date(), forKey: "updatedAt")
                try? bg.save()
            }
        }
    }

    // MARK: - De-duplication (keep latest per day)
    func dedupePerDay() {
        let bg = container.newBackgroundContext()
        bg.perform {
            let req: NSFetchRequest<JournalEntry> = JournalEntry.fetchRequest()
            req.sortDescriptors = [
                NSSortDescriptor(key: "day", ascending: true),
                NSSortDescriptor(key: "updatedAt", ascending: false)
            ]
            do {
                let all = try bg.fetch(req)
                var lastDay: Date?
                var keeper: JournalEntry?
                let cal = Calendar.current

                for e in all {
                    let d = cal.startOfDay(for: e.day ?? .distantPast)
                    if let ld = lastDay, d == ld, let k = keeper {
                        if (k.text ?? "").isEmpty, let t = e.text, !t.isEmpty { k.text = t }
                        if (k.photoData?.isEmpty ?? true), let p = e.photoData, !p.isEmpty { k.photoData = p }
                        k.isStarred = k.isStarred || e.isStarred
                        if let eu = e.updatedAt, let ku = k.updatedAt, eu > ku { k.updatedAt = eu }
                        bg.delete(e)
                    } else {
                        lastDay = d
                        keeper = e
                    }
                }
                try bg.save()
            } catch {
                print("Dedupe error:", error)
            }
        }
    }
}

enum PreviewData {
    static func insertSampleEntries(in ctx: NSManagedObjectContext, includePhotos: Bool) {
        let cal = Calendar.current
        let today = Calendar.current.startOfDay(for: Date())
        let notes = [
            "First entry — feeling hopeful.",
            "Walked 2 miles and wrote for 10 minutes.",
            "Small win today. Proud of it.",
            "Quiet day. Kept it simple.",
            "Reflected on goals. Baby steps."
        ]

        for i in 0..<12 {
            let e = JournalEntry(context: ctx)
            e.id = UUID()
            e.day = cal.date(byAdding: .day, value: -i, to: today)
            e.text = notes[i % notes.count]
            e.createdAt = Date()
            e.updatedAt = Date()
            e.isStarred = (i % 5 == 0)

            #if canImport(UIKit)
                if includePhotos, i % 3 == 0, let img = placeholderImage(index: i) {
                    // Prefer JPEG so CloudKit stores an efficient CKAsset
                    if let jpeg = img.jpegData(compressionQuality: 0.9) {
                        e.photoData = jpeg
                    } else if let png = img.pngData() {
                        e.photoData = png
                    }
                    e.updatedAt = Date()
                }
            #endif
        }
    }

    #if canImport(UIKit)
    private static func placeholderImage(index: Int) -> UIImage? {
        let size = CGSize(width: 1200, height: 800)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            UIColor.systemGray5.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            let str = "Havn \(index + 1)"
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 120, weight: .semibold),
                .foregroundColor: UIColor.systemGray
            ]
            let s = NSString(string: str)
            let sz = s.size(withAttributes: attrs)
            s.draw(at: CGPoint(x: (size.width - sz.width)/2, y: (size.height - sz.height)/2),
                   withAttributes: attrs)
        }
    }
    #endif
}


