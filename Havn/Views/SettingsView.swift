//
//  SettingsView.swift
//  Havn
//
//  Created by Zac Seebeck on 8/9/25.
//

import SwiftUI
import StoreKit

private extension Bundle {
    var appVersion: String { infoDictionary?["CFBundleShortVersionString"] as? String ?? "?" }
    var buildNumber: String { infoDictionary?["CFBundleVersion"] as? String ?? "?" }
}

struct SettingsView: View {
    @AppStorage("useBiometricLock") private var useBiometricLock = false
    @AppStorage("useCloudSync")     private var useCloudSync = false
    @AppStorage("hasOnboarded")   private var hasOnboarded = false
    @Environment(\.openURL) private var openURL
    @Environment(\.requestReview) private var requestReview
    @State private var syncing = false
    @State private var syncStatus: String?

    private func makeMailto() -> URL {
        var comps = URLComponents()
        comps.scheme = "mailto"
        comps.path = "zac@seebeck.tech"
        let body =
        """
        \n\n—\nFeedback:\n\n(Please describe the issue or suggestion.)\n\nApp: Havn \(Bundle.main.appVersion) (\(Bundle.main.buildNumber))\niOS: \(UIDevice.current.systemVersion)
        """
        comps.queryItems = [
            .init(name: "subject", value: "Havn Feedback"),
            .init(name: "body", value: body)
        ]
        return comps.url!
    }
    
    var body: some View {
        Form {
            Section("Privacy") {
                Toggle("App Lock (Face ID / Touch ID)", isOn: $useBiometricLock)
                    .font(HavnTheme.Typeface.caption)
                Toggle("iCloud Sync (optional)", isOn: $useCloudSync)
                    .font(HavnTheme.Typeface.caption)
                Text("Your entries are stored on-device by default. iCloud sync is optional and encrypted.")
                    .font(HavnTheme.Typeface.footnote)
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
                            .font(HavnTheme.Typeface.caption)
                    }
                }
                .disabled(syncing || !useCloudSync)
                if let status = syncStatus {
                    Text(status).font(.footnote).foregroundStyle(Color("TextMutedColor"))
                }
            }
            
            Section("Support") {
                Button {
                    openURL(makeMailto())
                } label: {
                    Label("Send Feedback", systemImage: "paperplane.fill")
                        .font(HavnTheme.Typeface.caption)
                }

                Button {
                    requestReview()   // iOS 16+ Environment action
                } label: {
                    Label("Rate Havn", systemImage: "star.bubble.fill")
                        .font(HavnTheme.Typeface.caption)
                }

                Link(destination: URL(string: "https://havn.seebeck.tech/havn-privacy")!) {
                    Label("Privacy Policy", systemImage: "lock.shield.fill")
                        .font(HavnTheme.Typeface.caption)
                }
            }

            Section("Onboarding") {
                Button {
                    Task {
                        hasOnboarded = false
                    }
                } label: {
                    HStack {
                        Text("Recomplete Onboarding")
                            .font(HavnTheme.Typeface.caption)
                    }
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
