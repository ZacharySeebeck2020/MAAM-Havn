//
//  OnboardingView.swift
//  Havn
//
//  Created by Zac Seebeck on 8/3/25.
//

import SwiftUI

// MARK: - Onboarding visual components
private struct OnbBackground: View {
    @State private var animate = false
    var body: some View {
        ZStack {
            // Base gradient
            LinearGradient(colors: [Color.callToAction.opacity(0.35), Color.accentColor.opacity(0.35)], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
                .hueRotation(.degrees(animate ? 15 : 0))
                .animation(.linear(duration: 12).repeatForever(autoreverses: true), value: animate)

            // Soft blobs
            Circle()
                .fill(Color.callToAction.opacity(0.25))
                .frame(width: 280, height: 280)
                .blur(radius: 60)
                .offset(x: -120, y: -220)
            Circle()
                .fill(Color.accentColor.opacity(0.22))
                .frame(width: 220, height: 220)
                .blur(radius: 60)
                .offset(x: 150, y: -160)
            Circle()
                .fill(Color.purple.opacity(0.18))
                .frame(width: 320, height: 320)
                .blur(radius: 70)
                .offset(x: 80, y: 260)
        }
        .onAppear { animate = true }
    }
}

struct OnboardingView: View {
    @Environment(\.managedObjectContext) private var moc
    @AppStorage("hasOnboarded")   private var hasOnboarded: Bool = false
    @AppStorage("useBiometricLock") private var useBiometricLock: Bool = false
    @AppStorage("useCloudSync")     private var useCloudSync: Bool = false
    @AppStorage("reminder.enabled") private var reminderEnabled: Bool = false
    @AppStorage("reminder.hour") private var reminderHour: Int = 20
    @AppStorage("reminder.minute") private var reminderMinute: Int = 0
    @State private var page = 0
    @State private var alertMessage: String?
    @State private var wantReminder: Bool = true
    @State private var reminderTime: Date = Self.makeDate(h: 20, m: 0)
    @State private var showDeniedInfo: Bool = false
    
    private let totalPages = 3

    private let haptic = UIImpactFeedbackGenerator(style: .light)
    
    private func goNext() {
        haptic.impactOccurred()
        if page < totalPages - 1 { withAnimation(.snappy) { page += 1 } }
        else { handleGetStarted() }
    }
    
    init() {
        UIPageControl.appearance().isHidden = true
    }

    var body: some View {
        ZStack {
            OnbBackground()

            VStack(spacing: 20) {
                // Progress label
                Text("Step \(page+1) of \(totalPages)")
                    .font(HavnTheme.Typeface.footnote)
                    .foregroundStyle(Color.textMuted)

                TabView(selection: $page) {
                    VStack(spacing: 28) {
                        OnbPageView(
                            symbol: "sparkles",
                            title: "Welcome to Havn",
                            subtitle: "Your private space to reflect and grow."
                        )
                    }
                    .tag(0)

                    VStack(spacing: 28) {
                        OnbPageView(
                            symbol: "lock.shield",
                            title: "Privacy by default",
                            subtitle: "Entries live on your device. iCloud sync is optional and encrypted."
                        )
                    }
                    .tag(1)

                    preferencesPage.tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .animation(.snappy, value: page)

                .safeAreaInset(edge: .bottom) {
                    Button(page < totalPages - 1 ? "Next" : "Get Started") { goNext() }
                        .buttonStyle(.borderedProminent)
                        .tint(Color.callToAction)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)
                        .controlSize(.large)
                }
            }
            .padding(.top, 24)
            .safeAreaInset(edge: .top) {
                HStack {
                    Spacer()
                    Button("Skip") { handleGetStarted() }
                        .buttonStyle(.bordered)
                        .tint(Color.callToAction.opacity(0.15))
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
        }
        .foregroundStyle(Color.textMain)
        .alert("Biometrics Unavailable", isPresented: Binding(
            get: { alertMessage != nil },
            set: { if !$0 { alertMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage ?? "")
        }
    }

    // MARK: - Preferences page
    private var preferencesPage: some View {
        VStack(spacing: 32) {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 128, weight: .semibold))
                .padding(.bottom, 0)

            VStack (spacing: 16) {
                Text("Preferences")
                    .font(HavnTheme.Typeface.title)
                    .foregroundStyle(Color.textMain)
                
                Text("Choose how Havn works for you.")
                    .font(HavnTheme.Typeface.caption)
                    .foregroundStyle(Color.textMuted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            VStack(spacing: 12) {
                Toggle("App Lock (Face ID / Touch ID)", isOn: Binding(
                    get: { useBiometricLock },
                    set: { newValue in
                        if newValue {
                            switch BiometricLocker.checkSupport() {
                            case .available:
                                useBiometricLock = true
                            case .unavailable(let reason):
                                useBiometricLock = false
                                alertMessage = reason
                            }
                        } else {
                            useBiometricLock = false
                        }
                    }
                ))
                .tint(Color.accentColor)
                .font(HavnTheme.Typeface.caption)
                .accessibilityHint("Uses your device biometrics to lock Havn")

                Toggle("iCloud Sync (optional)", isOn: $useCloudSync)
                    .accessibilityHint("Requires iCloud; will enable after setup")
                    .tint(Color.accentColor)
                    .font(HavnTheme.Typeface.caption)
                Text("Requires iCloud. Your data remains yours. We don’t collect analytics.")
                    .font(HavnTheme.Typeface.footnote)
                    .foregroundStyle(Color.textMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .multilineTextAlignment(.leading)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.callToAction.opacity(0.10))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.callToAction.opacity(0.30), lineWidth: 1)
            )
            .padding(.horizontal)
            
            VStack(alignment: .leading, spacing: 10) {
                Toggle("Daily Reminder", isOn: $wantReminder)
                    .accessibilityHint("Requires iCloud; will enable after setup")
                    .tint(Color.accentColor)
                    .font(HavnTheme.Typeface.caption)

                if wantReminder {
                    DatePicker("Time", selection: $reminderTime, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.compact)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                Text("We’ll remind you if you haven’t added today’s entry.")
                    .font(HavnTheme.Typeface.footnote)
                    .foregroundStyle(Color("TextMutedColor"))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .multilineTextAlignment(.leading)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.callToAction.opacity(0.10))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.callToAction.opacity(0.30), lineWidth: 1)
            )
            .padding(.horizontal)
        }
//        .padding(.vertical, 64)
        .padding(.horizontal, 32)
        .onAppear {
            wantReminder = reminderEnabled
            reminderTime = Self.makeDate(h: reminderHour, m: reminderMinute)
            ReminderManager.shared.configure()
        }
        .animation(.snappy, value: wantReminder)
    }
    
    private func handleGetStarted() {
        if wantReminder {
            // Update stored time from picker
            let comps = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
            reminderHour = comps.hour ?? reminderHour
            reminderMinute = comps.minute ?? reminderMinute

            requestAuthIfNeeded { granted in
                DispatchQueue.main.async {
                    if granted {
                        reminderEnabled = true
                        ReminderManager.shared.setEnabled(true, hour: reminderHour, minute: reminderMinute, context: moc)
                    } else {
                        reminderEnabled = false
                        showDeniedInfo = true
                    }
                    finish()
                }
            }
        } else {
            reminderEnabled = false
            ReminderManager.shared.setEnabled(false, hour: reminderHour, minute: reminderMinute, context: moc)
            finish()
        }
    }
    
    private func requestAuthIfNeeded(_ completion: @escaping (Bool)->Void) {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { s in
            switch s.authorizationStatus {
            case .authorized, .provisional, .ephemeral: completion(true)
            case .denied: completion(false)
            case .notDetermined:
                center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                    completion(granted)
                }
            @unknown default: completion(false)
            }
        }
    }

    private static func makeDate(h: Int, m: Int) -> Date {
        var dc = DateComponents(); dc.hour = h; dc.minute = m
        return Calendar.current.date(from: dc) ?? Date()
    }
    
    private func finish() { hasOnboarded = true }
}

// MARK: Onboarding Page View
private struct OnbPageView: View {
    let symbol: String
    let title: String
    let subtitle: String

    @State private var appeared = false

    var body: some View {
        VStack(spacing: 64) {
            Image(systemName: symbol)
                .font(.system(size: 128, weight: .semibold))
                .padding(.bottom, 8)
                .foregroundStyle(Color.textMain)
                .scaleEffect(appeared ? 1.0 : 0.9)
                .opacity(appeared ? 1.0 : 0.0)
                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: appeared)
            
            VStack (spacing: 16) {
                Text(title)
                    .font(HavnTheme.Typeface.title)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.textMain)
                    .opacity(appeared ? 1.0 : 0.0)
                    .animation(.easeIn(duration: 0.25).delay(0.05), value: appeared)

                Text(subtitle)
                    .font(HavnTheme.Typeface.caption)
                    .foregroundStyle(Color.textMuted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .opacity(appeared ? 1.0 : 0.0)
                    .animation(.easeIn(duration: 0.25).delay(0.1), value: appeared)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 36)
        .padding(.horizontal, 32)
        .onAppear { appeared = true }
        .onDisappear { appeared = false }
    }
}

#Preview {
    OnboardingView()
}
