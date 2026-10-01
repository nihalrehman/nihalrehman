import SwiftUI

/// Plain-language explanation of how Ledgerly protects data.
struct SecurityInfoView: View {
    @Environment(AppLockManager.self) private var lockManager
    @AppStorage(SettingsKey.excludeFromBackup) private var excludeFromBackup = true

    var body: some View {
        List {
            Section {
                status("App Lock", lockManager.lockEnabled, on: "\(AppLockManager.biometryName) required", off: "Off — turn on in Settings")
                status("Device passcode", AppLockManager.canAuthenticate, on: "Set", off: "Not set — iOS cannot encrypt your files without one")
                status("Backups", excludeFromBackup, on: "Excluded from iCloud/computer backups", off: "Included in device backups")
            } header: {
                Text("Status")
            }

            Section("How your data is protected") {
                item("iphone.gen3", "Stays on your device", "No account, no server, no cloud sync, no analytics or ads. Ledgerly makes no network requests.")
                item("lock.doc.fill", "Encrypted database", "The database uses iOS Data Protection: it is encrypted with a key tied to your device passcode and unreadable while the phone is locked.")
                item("key.fill", "Field-level AES-256 encryption", "Your name, email, phone, address, ID number, account numbers, lenders, payees and notes are additionally encrypted with AES-256-GCM before being saved.")
                item("lock.iphone", "Key in the Secure Keychain", "The encryption key lives in the iOS Keychain, readable only while your device is unlocked, never synced and never copied to backups.")
                item(AppLockManager.biometryIcon, "Biometric app lock", "Face ID / Touch ID with passcode fallback. Re-locks automatically when you leave the app.")
                item("eye.slash.fill", "Privacy screen & masking", "Content is hidden in the app switcher. Account and ID numbers are masked until you authenticate. A 'Hide amounts' mode is one tap away.")
                item("bell.badge.fill", "Discreet notifications", "Bill reminders never include names or amounts.")
                item("externaldrive.fill.badge.checkmark", "Encrypted backups", "Backups are sealed with AES-256-GCM using a key derived from your password via PBKDF2-SHA256 (600,000 rounds).")
                item("trash.fill", "Secure erase", "Erasing destroys the encryption key, making any leftover encrypted data permanently unreadable.")
            }
        }
        .navigationTitle("Security & Privacy")
    }

    private func status(_ title: String, _ ok: Bool, on: String, off: String) -> some View {
        HStack {
            Image(systemName: ok ? "checkmark.shield.fill" : "exclamationmark.shield.fill")
                .foregroundStyle(ok ? .green : .orange)
            VStack(alignment: .leading) {
                Text(title)
                Text(ok ? on : off).font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func item(_ icon: String, _ title: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.headline)
                Text(text).font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
