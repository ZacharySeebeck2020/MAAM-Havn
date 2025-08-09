//
//  BiometricLocker.swift
//  Havn
//
//  Created by Zac Seebeck on 8/9/25.
//

import LocalAuthentication

enum BiometricSupport {
    case available
    case unavailable(reason: String)
}

struct BiometricLocker {
    static func checkSupport() -> BiometricSupport {
        let ctx = LAContext()
        var error: NSError?
        if ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            return .available
        } else {
            let reason = error?.localizedDescription ?? "Biometrics not available on this device."
            return .unavailable(reason: reason)
        }
    }
}
