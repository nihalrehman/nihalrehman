import Foundation

/// UserDefaults keys. Only non-sensitive preferences are stored in UserDefaults;
/// financial and personal data lives in the protected, encrypted store.
enum SettingsKey {
    static let currencyCode = "settings.currencyCode"
    static let hideAmounts = "privacy.hideAmounts"
    static let lockEnabled = "security.lockEnabled"
    static let autoLockSeconds = "security.autoLockSeconds"
    static let excludeFromBackup = "security.excludeFromBackup"
    static let billReminders = "settings.billReminders"
    static let didSeed = "data.didSeed.v1"
    static let didOnboard = "app.didOnboard.v1"
}

enum AppSettings {
    static var defaultCurrencyCode: String {
        Locale.current.currency?.identifier ?? "USD"
    }

    static var currencyCode: String {
        UserDefaults.standard.string(forKey: SettingsKey.currencyCode) ?? defaultCurrencyCode
    }

    static var excludeFromBackup: Bool {
        (UserDefaults.standard.object(forKey: SettingsKey.excludeFromBackup) as? Bool) ?? true
    }

    struct AutoLockOption: Identifiable {
        var id: Int { seconds }
        let seconds: Int
        let title: String
    }

    static let autoLockOptions: [AutoLockOption] = [
        AutoLockOption(seconds: 0, title: "Immediately"),
        AutoLockOption(seconds: 30, title: "After 30 seconds"),
        AutoLockOption(seconds: 60, title: "After 1 minute"),
        AutoLockOption(seconds: 300, title: "After 5 minutes"),
        AutoLockOption(seconds: 900, title: "After 15 minutes"),
    ]
}
