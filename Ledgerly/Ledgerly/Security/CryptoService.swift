import CryptoKit
import Foundation

/// Field-level encryption for sensitive data using AES-256-GCM (authenticated encryption).
///
/// A random 256-bit data key is generated on first use and kept in the Keychain
/// (device-only, available only while unlocked). Each value gets a fresh random
/// nonce, and GCM's authentication tag detects any tampering.
///
/// Payload layout: `[1-byte format version][12-byte nonce][ciphertext][16-byte tag]`.
final class CryptoService: @unchecked Sendable {
    enum CryptoError: Error, LocalizedError {
        case invalidPayload
        case unsupportedVersion(UInt8)

        var errorDescription: String? {
            switch self {
            case .invalidPayload: "The encrypted data is corrupted."
            case .unsupportedVersion(let v): "Unsupported encryption format version \(v)."
            }
        }
    }

    static let shared = CryptoService()

    static let keyAccount = "data-encryption-key.v1"
    static let formatVersion: UInt8 = 1

    private let lock = NSLock()
    private var cachedKey: SymmetricKey?
    /// When set, the service uses this key instead of the Keychain (unit tests).
    private let fixedKey: SymmetricKey?

    init(fixedKey: SymmetricKey? = nil) {
        self.fixedKey = fixedKey
    }

    func encrypt(_ plaintext: Data) throws -> Data {
        let sealed = try AES.GCM.seal(plaintext, using: try dataKey())
        guard let combined = sealed.combined else { throw CryptoError.invalidPayload }
        var output = Data([Self.formatVersion])
        output.append(combined)
        return output
    }

    func decrypt(_ payload: Data) throws -> Data {
        guard let version = payload.first else { throw CryptoError.invalidPayload }
        guard version == Self.formatVersion else { throw CryptoError.unsupportedVersion(version) }
        let box = try AES.GCM.SealedBox(combined: Data(payload.dropFirst()))
        return try AES.GCM.open(box, using: try dataKey())
    }

    /// Drops the in-memory copy of the key (it is re-read from the Keychain on demand).
    func evictKeyFromMemory() {
        lock.lock()
        cachedKey = nil
        lock.unlock()
    }

    /// Permanently destroys the data key ("crypto-shredding"): any ciphertext still
    /// on disk becomes unrecoverable. A new key is generated on next use.
    func destroyKey() {
        lock.lock()
        cachedKey = nil
        KeychainStore.delete(Self.keyAccount)
        lock.unlock()
    }

    private func dataKey() throws -> SymmetricKey {
        if let fixedKey { return fixedKey }
        lock.lock()
        defer { lock.unlock() }
        if let cachedKey { return cachedKey }

        // `read` throws on errors other than "not found", so a locked device can
        // never cause the existing key to be overwritten by a new one.
        if let raw = try KeychainStore.read(Self.keyAccount) {
            let key = SymmetricKey(data: raw)
            cachedKey = key
            return key
        }

        let key = SymmetricKey(size: .bits256)
        let raw = key.withUnsafeBytes { Data($0) }
        try KeychainStore.save(raw, account: Self.keyAccount)
        cachedKey = key
        return key
    }
}

/// Helpers used by model properties to transparently encrypt/decrypt strings.
enum FieldCrypto {
    static var service: CryptoService = .shared

    /// Encrypts a string. Empty strings are stored as nil.
    static func seal(_ value: String) -> Data? {
        guard !value.isEmpty else { return nil }
        return try? service.encrypt(Data(value.utf8))
    }

    /// Decrypts a stored value. Returns an empty string if absent or unreadable.
    static func open(_ data: Data?) -> String {
        guard let data, let plain = try? service.decrypt(data) else { return "" }
        return String(decoding: plain, as: UTF8.self)
    }
}
