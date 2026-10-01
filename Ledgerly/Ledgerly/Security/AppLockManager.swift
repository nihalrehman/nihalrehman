import Foundation
import LocalAuthentication
import Observation

/// Controls the app lock: Face ID / Touch ID with device-passcode fallback.
///
/// - The app starts locked when the lock is enabled.
/// - After going to the background it re-locks once the auto-lock delay has passed.
/// - The in-memory encryption key is evicted whenever the app locks.
@MainActor
@Observable
final class AppLockManager {
    private(set) var isLocked: Bool
    private(set) var isAuthenticating = false
    var lastError: String?

    var lockEnabled: Bool {
        didSet { UserDefaults.standard.set(lockEnabled, forKey: SettingsKey.lockEnabled) }
    }

    /// Seconds in the background before the app re-locks (0 = immediately).
    var autoLockSeconds: Int {
        didSet { UserDefaults.standard.set(autoLockSeconds, forKey: SettingsKey.autoLockSeconds) }
    }

    @ObservationIgnored private var backgroundedAt: Date?

    init() {
        let defaults = UserDefaults.standard
        defaults.register(defaults: [
            SettingsKey.lockEnabled: true,
            SettingsKey.autoLockSeconds: 0,
        ])
        let enabled = defaults.bool(forKey: SettingsKey.lockEnabled)
        self.lockEnabled = enabled
        self.autoLockSeconds = defaults.integer(forKey: SettingsKey.autoLockSeconds)
        self.isLocked = enabled
    }

    // MARK: - Capabilities

    static var biometryType: LABiometryType {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        return context.biometryType
    }

    static var biometryName: String {
        switch biometryType {
        case .faceID: "Face ID"
        case .touchID: "Touch ID"
        case .opticID: "Optic ID"
        default: "Passcode"
        }
    }

    static var biometryIcon: String {
        switch biometryType {
        case .faceID: "faceid"
        case .touchID: "touchid"
        case .opticID: "opticid"
        default: "lock.fill"
        }
    }

    /// Whether the device can authenticate the owner at all (requires a device passcode).
    static var canAuthenticate: Bool {
        LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
    }

    // MARK: - Lifecycle

    func sceneDidEnterBackground() {
        backgroundedAt = Date()
        if lockEnabled && autoLockSeconds == 0 {
            lock()
        }
    }

    func sceneDidBecomeActive() {
        if lockEnabled, let backgroundedAt,
           Date().timeIntervalSince(backgroundedAt) >= Double(autoLockSeconds) {
            lock()
        }
        backgroundedAt = nil
        if isLocked {
            Task { await unlock() }
        }
    }

    func lock() {
        guard lockEnabled else { return }
        isLocked = true
        CryptoService.shared.evictKeyFromMemory()
    }

    // MARK: - Authentication

    func unlock() async {
        guard isLocked, !isAuthenticating else { return }
        guard Self.canAuthenticate else {
            // Without a device passcode iOS cannot protect anything; don't trap the
            // user out of their own data, but explain why the lock is off.
            lockEnabled = false
            isLocked = false
            lastError = "App Lock was turned off because this device has no passcode. Set a passcode in iOS Settings to protect your data."
            return
        }
        if await Self.authenticate(reason: "Unlock Ledgerly to access your financial data") {
            isLocked = false
            lastError = nil
        }
    }

    /// Turns the lock on or off. Both directions require the owner to authenticate.
    func setLockEnabled(_ enabled: Bool) async {
        guard enabled != lockEnabled else { return }
        guard Self.canAuthenticate else {
            lastError = "Set a device passcode in iOS Settings to enable App Lock."
            return
        }
        let reason = enabled ? "Turn on App Lock" : "Turn off App Lock"
        if await Self.authenticate(reason: reason) {
            lockEnabled = enabled
            lastError = nil
        }
    }

    /// One-off owner verification for sensitive actions (revealing numbers,
    /// exporting, erasing data). Returns true if the device has no passcode
    /// only when `allowWithoutPasscode` is set.
    @discardableResult
    static func authenticate(reason: String, allowWithoutPasscode: Bool = false) async -> Bool {
        let context = LAContext()
        context.localizedCancelTitle = "Cancel"
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            return allowWithoutPasscode
        }
        do {
            return try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
        } catch {
            return false
        }
    }
}
