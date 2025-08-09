//
//  HavnApp.swift
//  Havn
//
//  Created by Zac Seebeck on 8/3/25.
//

import SwiftUI

@main
struct HavnApp: App {
    let persistenceController = PersistenceController.shared
    @AppStorage("hasOnboarded") var hasCompletedOnboarding: Bool = false

    var body: some Scene {
        WindowGroup {
            Group {
                if hasCompletedOnboarding {
                    LockGate {
                        RootTabView()
                            .environment(\.managedObjectContext, persistenceController.container.viewContext)
                    }
                } else {
                    OnboardingView()
                }
            }.tint(Color.accentColor)
        }
    }
}
