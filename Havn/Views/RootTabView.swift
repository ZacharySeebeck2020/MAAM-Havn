//
//  RootTabView.swift
//  Havn
//
//  Created by Zac Seebeck on 8/9/25.
//

import SwiftUI

struct RootTabView: View {
    enum Tab: Hashable { case journal, history, settings }
    @State private var tab: Tab = .journal

    var body: some View {
        TabView(selection: $tab) {
            NavigationStack {
                JournalView()
            }
            .tabItem { Label("Journal", systemImage: "book.closed") }
            .tag(Tab.journal)

            NavigationStack {
                HistoryView()
            }
            .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }
            .tag(Tab.history)

            NavigationStack {
                SettingsView()
            }
            .tabItem { Label("Settings", systemImage: "gearshape") }
            .tag(Tab.settings)
        }
        .tint(Color("AccentColor"))
        .background(Color("BackgroundColor").ignoresSafeArea())
    }
}

#Preview("Root • Light") {
    RootTabView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
#Preview("Root • Dark")  {
    RootTabView().preferredColorScheme(.dark)
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
