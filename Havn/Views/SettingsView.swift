//
//  SettingsView.swift
//  Havn
//
//  Created by Zac Seebeck on 8/9/25.
//

import SwiftUI

struct SettingsView: View {
    @AppStorage("useBiometricLock") private var useBiometricLock = false
    @AppStorage("useCloudSync")     private var useCloudSync = false
    @State private var syncing = false
    @State private var syncStatus: String?

    var body: some View {
        Form {
            Section("Privacy") {
                Toggle("App Lock (Face ID / Touch ID)", isOn: $useBiometricLock)
                Toggle("iCloud Sync (optional)", isOn: $useCloudSync)
                Text("Your entries are stored on-device by default. iCloud sync is optional and encrypted.")
                    .font(.footnote)
                    .foregroundStyle(Color("TextMutedColor"))
            }
            
            Section("iCloud Syncing") {
                Button {
                    Task {
                        syncing = true
                        await PersistenceController.shared.requestSyncNow()
                        syncing = false
                        syncStatus = "Sync requested"
                    }
                } label: {
                    HStack {
                        if syncing { ProgressView().padding(.trailing, 6) }
                        Text("Sync Now")
                    }
                }
                .disabled(syncing || !useCloudSync)
                if let status = syncStatus {
                    Text(status).font(.footnote).foregroundStyle(Color("TextMutedColor"))
                }
            }
        }
        .tint(Color("AccentColor"))
        .scrollContentBackground(.hidden)
        .background(Color("BackgroundColor"))
    }
}

#Preview("Interactive • Light") {
    SettingsView()
}

#Preview("Interactive • Dark") {
    SettingsView()
        .preferredColorScheme(ColorScheme.dark)
}
