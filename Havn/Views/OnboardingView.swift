//
//  OnboardingView.swift
//  Havn
//
//  Created by Zac Seebeck on 8/3/25.
//

import SwiftUI

struct OnboardingView: View {
    @AppStorage("hasOnboarded")   private var hasOnboarded = false
    @AppStorage("useBiometricLock") private var useBiometricLock = false
    @AppStorage("useCloudSync")     private var useCloudSync = false

    @State private var page = 0
    @State private var alertMessage: String?

    private let totalPages = 3

    var body: some View {
        ZStack {
            Color.background.ignoresSafeArea()

            VStack(spacing: 20) {
                TabView(selection: $page) {
                    OnbPageView(
                        symbol: "sparkles",
                        title: "Welcome to Havn",
                        subtitle: "Your private space for growth."
                    )
                    .tag(0)

                    OnbPageView(
                        symbol: "lock.shield",
                        title: "Privacy by default",
                        subtitle: "Entries live on your device. iCloud sync is optional and encrypted."
                    )
                    .tag(1)

                    preferencesPage.tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .always))

                // Buttons
                HStack(spacing: 32) {
                    if page < totalPages - 1 {
                        Button("Skip") { finish() }
                            .buttonStyle(.borderless)
                            .foregroundStyle(Color.textMuted)
                            .accessibilityLabel("Skip onboarding")
                    }

                    Spacer()

                    Button(page < totalPages - 1 ? "Next" : "Get Started") {
                        if page < totalPages - 1 { page += 1 } else { finish() }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .foregroundStyle(Color.textMain)
                }
                .padding(.horizontal)
                .padding(.bottom, 12)
            }
            .padding(.top, 24)
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
        VStack(spacing: 16) {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 64, weight: .semibold))
                .padding(.bottom, 8)

            Text("Preferences")
                .font(.system(.largeTitle, design: .rounded)).bold()
                .foregroundStyle(Color.textMain)

            Text("Choose how Havn works for you.")
                .font(.body)
                .foregroundStyle(Color.textMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

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
                .accessibilityHint("Uses your device biometrics to lock Havn")

                Toggle("iCloud Sync (optional)", isOn: $useCloudSync)
                    .accessibilityHint("Requires iCloud; will enable after setup")
                    .tint(Color.accentColor)
                Text("Requires iCloud. Your data remains yours. We don’t collect analytics.")
                    .font(.footnote)
                    .foregroundStyle(Color.textMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)
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
            Spacer(minLength: 0)
        }
        .padding(.vertical, 64)
        .padding(.horizontal, 32)
    }

    private func finish() { hasOnboarded = true }
}

// MARK: Onboarding Page View
private struct OnbPageView: View {
    let symbol: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: symbol)
                .font(.system(size: 64, weight: .semibold))
                .padding(.bottom, 8)
                .foregroundStyle(Color.textMain)

            Text(title)
                .font(.system(.largeTitle, design: .rounded)).bold()
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.textMain)

            Text(subtitle)
                .font(.body)
                .foregroundStyle(Color.textMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Spacer(minLength: 0)
        }
        .padding(.vertical, 64)
        .padding(.horizontal, 32)
    }
}

#Preview {
    OnboardingView()
}
