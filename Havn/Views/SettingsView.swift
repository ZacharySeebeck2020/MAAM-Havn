//
//  SettingsView.swift
//  Havn
//
//  Created by Zac Seebeck on 8/9/25.
//

import SwiftUI
import StoreKit
import UserNotifications
import WidgetKit
import CoreData

private extension Bundle {
    var appVersion: String { infoDictionary?["CFBundleShortVersionString"] as? String ?? "?" }
    var buildNumber: String { infoDictionary?["CFBundleVersion"] as? String ?? "?" }
}

struct SettingsView: View {
    @Environment(\.managedObjectContext) private var moc
    @AppStorage("useBiometricLock") private var useBiometricLock = false
    @AppStorage("useCloudSync")     private var useCloudSync = false
    @AppStorage("hasOnboarded")   private var hasOnboarded = false
    
    @AppStorage("reminder.enabled") private var enabledNotifications = false
    @AppStorage("reminder.hour") private var reminderHour: Int = 8
    @AppStorage("reminder.minute") private var reminderMinute: Int = 0
    
    @State private var permissionDenied = false
    @State private var showingDeniedAlert = false
    
    @Environment(\.openURL) private var openURL
    @Environment(\.requestReview) private var requestReview
    @State private var syncing = false
    @State private var syncStatus: String?
    @State private var permissionDenied: Bool = false;
  
    private var timeBinding: Binding<Date> {
        Binding<Date>(
            get: { Self.timeFrom(hour: reminderHour, minute: reminderMinute) },
            set: { newDate in
                let comps = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                reminderHour = comps.hour ?? 0
                reminderMinute = comps.minute ?? 0
                if enabledNotifications {
                    ReminderManager.shared.setEnabled(true, hour: reminderHour, minute: reminderMinute, context: moc)
                }
                
            }
        )
    }
    
    private static func timeFrom(hour: Int, minute: Int) -> Date {
        var comps = DateComponents()
        comps.hour = hour; comps.minute = minute
        return Calendar.current.date(from: comps) ?? Date()
    }

    private func makeMailto() -> URL {
        var comps = URLComponents()
        comps.scheme = "mailto"
        comps.path = "zac@seebeck.work"
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
            
            Section {
                Toggle("Enable Daily Notification", isOn: Binding (
                    get: {
                        enabledNotifications
                    },
                    set: { on in
                        if on {
                            requestAuthIfNeeded { granted in
                                DispatchQueue.main.async {
                                    if granted {
                                        enabledNotifications = true
                                        ReminderManager.shared.setEnabled(true, hour: reminderHour, minute: reminderMinute, context: moc)
                                    } else {
                                        enabledNotifications = false
                                        showingDeniedAlert = true
                                    }
                                }
                            }
                        } else {
                            enabledNotifications = false; ReminderManager.shared.setEnabled(false, hour: reminderHour, minute: reminderMinute, context: moc)
                        }
                    }))
                    .font(HavnTheme.Typeface.caption)
                DatePicker("Time", selection: timeBinding, displayedComponents: .hourAndMinute)
                    .font(HavnTheme.Typeface.caption)
                    .disabled(!enabledNotifications)
            } header: {
                Text("Daily Notification Settings")
            } footer: {
                if enabledNotifications {
                    Text("Next reminder will be scheduled automatically. Changes take effect immediately")
                } else if permissionDenied {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                        Text("Notifications are disabled in Settings.")
                        Spacer(minLength: 8)
                        Button("Open Settings") { openSystemSettings() }
                    }
                    .font(HavnTheme.Typeface.footnote)
                }
            }
            .onAppear {
                ReminderManager.shared.configure()
                self.refereshPermissionState()
            }
            .alert("Notifications Disabled", isPresented: $showingDeniedAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Open Settings") { openSystemSettings() }
            } message: {
                Text("To enable reminders, allow notifications for Havn in Settings.")
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

            #if DEBUG
            Section("Debug Options") {
                Button {
                    Task {
                        runWidgetDiagnostics(context: moc)
                    }
                } label: {
                    HStack {
                        Text("Run Widget Diag.")
                            .font(HavnTheme.Typeface.caption)
                    }
                }
            }

            #endif
            
        }
        .tint(Color("AccentColor"))
        .scrollContentBackground(.hidden)
        .background(Color("BackgroundColor"))
    }
    
    #if DEBUG
    // MARK: Debug Code
    func runWidgetDiagnostics(context: NSManagedObjectContext) {
        // 1) Write current state/files
        WidgetBridge.refresh(from: context)

        // 2) Print App Group + state
        let groupID = AppGroup.id
        if let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupID) {
            let s = container.appendingPathComponent("widget-state.json")
            let t = container.appendingPathComponent("today-thumb.jpg")
            print("Container:", container.path,
                  "state exists:", FileManager.default.fileExists(atPath: s.path),
                  "thumb exists:", FileManager.default.fileExists(atPath: t.path))
            if let data = try? Data(contentsOf: s),
               let state = try? JSONDecoder().decode(WidgetState.self, from: data) {
                print("STATE:", state)
            }
        } else {
            print("❗️No App Group container for:", groupID)
        }

        // 3) Force the timeline
        WidgetCenter.shared.getCurrentConfigurations { result in
            print("Configs:", result)
            WidgetCenter.shared.reloadTimelines(ofKind: "HavnWidgets")
        }
    }
    #endif
    // MARK: - Notification Permissions
    private func requestAuthIfNeeded(completion: @escaping (Bool)->Void) {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { s in
            switch s.authorizationStatus {
            case .authorized, .provisional, .ephemeral: completion(true)
            case .denied: completion(false)
            case .notDetermined:
                center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                    completion(granted)
                }
            @unknown default:
                completion(false)
            }
        }
    }
    
    private func refereshPermissionState() {
        UNUserNotificationCenter.current().getNotificationSettings { s in
            DispatchQueue.main.async {
                self.permissionDenied = s.authorizationStatus == .denied
            }
        }
    }
    
    private func openSystemSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

#Preview("Interactive • Light") {
    SettingsView()
}

#Preview("Interactive • Dark") {
    SettingsView()
        .preferredColorScheme(ColorScheme.dark)
}
