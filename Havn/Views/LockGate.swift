//
//  LockGate.swift
//  Havn
//
//  Created by Zac Seebeck on 8/9/25.
//

import SwiftUI
import LocalAuthentication

struct LockGate<Content: View>: View {
    @AppStorage("useBiometricLock") private var lockEnabled = false

    @State private var isUnlocked = false
    @State private var shouldLockOnNextActivate = false
    @State private var authInProgress = false
    @State private var lastUnlockAt: Date?

    @Environment(\.scenePhase) private var scenePhase

    private let allowPasscodeFallback: Bool
    private let gracePeriod: TimeInterval
    private let content: Content

    init(allowPasscodeFallback: Bool = true,
         gracePeriod: TimeInterval = 8,
         @ViewBuilder content: () -> Content) {
        self.allowPasscodeFallback = allowPasscodeFallback
        self.gracePeriod = gracePeriod
        self.content = content()
    }

    var body: some View {
        Group {
            if !lockEnabled || isUnlocked {
                content
            } else {
                lockScreen
                    .onAppear { authenticateIfNeeded() } // first time
            }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background:
                // Only relock after a true background transition
                shouldLockOnNextActivate = true
            case .active:
                // Return from background? Check grace + auth
                if lockEnabled, shouldLockOnNextActivate {
                    shouldLockOnNextActivate = false
                    if let last = lastUnlockAt, Date().timeIntervalSince(last) < gracePeriod {
                        // Within grace window → stay unlocked
                        isUnlocked = true
                    } else {
                        isUnlocked = false
                        authenticateIfNeeded()
                    }
                }
            default:
                break
            }
        }
    }

    private var lockScreen: some View {
        ZStack {
            Color("BackgroundColor").ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundStyle(Color("AccentColor"))
                Text("Tap to unlock")
                    .font(HavnTheme.Typeface.title)
                    .foregroundStyle(Color("TextMutedColor"))
                Button("Unlock", action: authenticateIfNeeded)
                    .buttonStyle(.borderedProminent)
                    .tint(Color("AccentColor"))
            }
            .padding()
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: authenticateIfNeeded)
    }

    private func authenticateIfNeeded() {
        guard lockEnabled, !isUnlocked, !authInProgress else { return }
        authInProgress = true

        let ctx = LAContext()
        ctx.localizedCancelTitle = "Cancel"
        let policy: LAPolicy = allowPasscodeFallback
            ? .deviceOwnerAuthentication
            : .deviceOwnerAuthenticationWithBiometrics

        var err: NSError?
        if ctx.canEvaluatePolicy(policy, error: &err) {
            ctx.evaluatePolicy(policy, localizedReason: "Unlock Havn") { success, _ in
                DispatchQueue.main.async {
                    authInProgress = false
                    if success {
                        isUnlocked = true
                        lastUnlockAt = Date()
                    }
                }
            }
        } else {
            // No biometrics/passcode available → remain locked; the toggle UI already handled messaging
            authInProgress = false
        }
    }
}
