//
//  StreakPill.swift
//  Havn
//
//  Created by Zac Seebeck on 8/15/25.
//


import SwiftUI
import CoreData

struct StreakPill: View {
    @Environment(\.managedObjectContext) private var moc

    @State private var stats: StreakStats = StreakStats(current: 0, best: 0, lastEntryDay: nil)

    var body: some View {
        pill
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule(style: .continuous)
                    .fill(Color("AccentColor").opacity(0.18))
                    .overlay(Capsule().stroke(Color("AccentColor").opacity(0.35), lineWidth: 1))
            )
            .foregroundStyle(Color("TextMainColor"))
            .onAppear(perform: recalc)
            .onReceive(NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave)) { _ in recalc() }
            .onReceive(NotificationCenter.default.publisher(for: .NSPersistentStoreRemoteChange)) { _ in recalc() }
    }

    @ViewBuilder
    private var pill: some View {
        HStack(spacing: 8) {
            Image(systemName: "flame.fill")
                .imageScale(.small)

            Text("\(stats.current)")
                .font(.headline)
                .monospacedDigit()                    // simpler + compiler-friendly
                .animation(.snappy, value: stats.current)

            Text("day streak")
                .font(.subheadline)
                .opacity(0.9)

            Spacer(minLength: 6)
            if stats.best > 0 {
                BestBadge(best: stats.best)
            }
        }
    }

    private struct BestBadge: View {
        let best: Int
        var body: some View {
            HStack(spacing: 4) {
                Image(systemName: "trophy.fill").imageScale(.small).opacity(0.9)
                Text("Best \(best)")
                    .font(.caption)
                    .opacity(0.9)
            }
        }
    }

    private func recalc() {
        moc.perform {
            let s = Streaks.compute(in: moc)
            DispatchQueue.main.async {
                // soft haptic if you’ve improved
                if s.current > stats.current { UIImpactFeedbackGenerator(style: .soft).impactOccurred() }
                withAnimation(.snappy) { stats = s }
            }
        }
    }
}

#Preview("Streak Pill") {
    StreakPill()
        .padding()
        .background(Color("BackgroundColor"))
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
