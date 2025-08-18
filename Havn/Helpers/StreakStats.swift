//
//  StreakStats.swift
//  Havn
//
//  Created by Zac Seebeck on 8/15/25.
//


import Foundation
import CoreData

struct StreakStats {
    let current: Int
    let best: Int
    let lastEntryDay: Date?
}

enum Streaks {
    /// Pulls distinct entry days from Core Data and computes (current, best).
    static func compute(in ctx: NSManagedObjectContext) -> StreakStats {
        let cal = Calendar.current

        // 1) Fetch distinct days (we store one entry per day, but be safe)
        let req = NSFetchRequest<NSDictionary>(entityName: "JournalEntry")
        req.resultType = .dictionaryResultType
        req.propertiesToFetch = ["day"]
        req.returnsDistinctResults = true
        req.sortDescriptors = [NSSortDescriptor(key: "day", ascending: true)]

        let raw = (try? ctx.fetch(req)) ?? []
        let uniqueDays = raw.compactMap { $0["day"] as? Date }
            .map { cal.startOfDay(for: $0) }
            .sorted()

        guard !uniqueDays.isEmpty else { return .init(current: 0, best: 0, lastEntryDay: nil) }

        // 2) Best streak (max run of +1 day gaps)
        var best = 1, run = 1
        for i in 1..<uniqueDays.count {
            let prev = uniqueDays[i-1], cur = uniqueDays[i]
            let diff = cal.dateComponents([.day], from: prev, to: cur).day ?? Int.max
            if diff == 1 { run += 1; best = max(best, run) } else { run = 1 }
        }

        // 3) Current streak: run ending on the nearest day ≤ today (today if exists, else yesterday, else 0)
        let today = cal.startOfDay(for: Date())
        let set = Set(uniqueDays)
        let anchor: Date? = {
            if set.contains(today) { return today }
            let y = cal.date(byAdding: .day, value: -1, to: today)!
            return set.contains(y) ? y : nil
        }()

        var current = 0
        if var d = anchor {
            while set.contains(d) {
                current += 1
                d = cal.date(byAdding: .day, value: -1, to: d)!
            }
        }

        return .init(current: current, best: best, lastEntryDay: uniqueDays.last)
    }
}
