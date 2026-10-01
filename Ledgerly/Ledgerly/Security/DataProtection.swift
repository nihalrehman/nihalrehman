import Foundation

/// Applies iOS Data Protection (hardware-backed file encryption) to the app's storage.
enum DataProtection {
    /// `completeUnlessOpen`: files are encrypted with a key derived from the device
    /// passcode and become unreadable when the device locks, except for handles
    /// already open (needed so SQLite can finish an in-flight write safely).
    static let storeProtection: FileProtectionType = .completeUnlessOpen

    /// Creates `directory` if needed and applies the protection class to it and to
    /// every file inside. New files inherit the directory's protection class.
    static func protect(directory: URL) {
        let fm = FileManager.default
        let attributes: [FileAttributeKey: Any] = [.protectionKey: storeProtection]
        if !fm.fileExists(atPath: directory.path) {
            try? fm.createDirectory(at: directory, withIntermediateDirectories: true, attributes: attributes)
        }
        try? fm.setAttributes(attributes, ofItemAtPath: directory.path)
        if let files = try? fm.contentsOfDirectory(atPath: directory.path) {
            for file in files {
                let path = directory.appendingPathComponent(file).path
                try? fm.setAttributes(attributes, ofItemAtPath: path)
            }
        }
    }

    /// Includes or excludes a directory from iCloud / computer backups.
    static func setExcludedFromBackup(_ excluded: Bool, at directory: URL) {
        var url = directory
        var values = URLResourceValues()
        values.isExcludedFromBackup = excluded
        try? url.setResourceValues(values)
    }
}
