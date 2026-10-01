import CommonCrypto
import CryptoKit
import Foundation

/// Password-based encryption used for portable backup files.
///
/// The key is derived with PBKDF2-HMAC-SHA256 (600,000 iterations, per current
/// OWASP guidance) from the user's backup password and a random 16-byte salt,
/// then the data is sealed with AES-256-GCM.
enum PasswordCrypto {
    static let defaultRounds: UInt32 = 600_000
    static let minimumPasswordLength = 8

    enum PasswordCryptoError: Error, LocalizedError {
        case keyDerivationFailed
        case wrongPasswordOrCorrupted

        var errorDescription: String? {
            switch self {
            case .keyDerivationFailed: "Could not derive an encryption key from the password."
            case .wrongPasswordOrCorrupted: "Incorrect password, or the backup file is damaged."
            }
        }
    }

    struct Envelope: Codable {
        var format: String = "ledgerly-encrypted-backup"
        var version: Int = 1
        var kdf: String = "PBKDF2-HMAC-SHA256"
        var rounds: UInt32
        var salt: Data
        var cipher: String = "AES-256-GCM"
        var ciphertext: Data
    }

    static func randomBytes(_ count: Int) -> Data {
        var data = Data(count: count)
        let status = data.withUnsafeMutableBytes { buffer in
            SecRandomCopyBytes(kSecRandomDefault, count, buffer.baseAddress!)
        }
        precondition(status == errSecSuccess, "Secure random number generation failed")
        return data
    }

    static func deriveKey(password: String, salt: Data, rounds: UInt32) throws -> SymmetricKey {
        guard !password.isEmpty, !salt.isEmpty else { throw PasswordCryptoError.keyDerivationFailed }
        let passwordLength = password.utf8.count
        let keyLength = 32
        var derived = [UInt8](repeating: 0, count: keyLength)
        let status: Int32 = password.withCString { pwdPtr in
            salt.withUnsafeBytes { saltBuffer in
                derived.withUnsafeMutableBufferPointer { out in
                    CCKeyDerivationPBKDF(
                        CCPBKDFAlgorithm(kCCPBKDF2),
                        pwdPtr, passwordLength,
                        saltBuffer.bindMemory(to: UInt8.self).baseAddress, saltBuffer.count,
                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                        rounds,
                        out.baseAddress, keyLength
                    )
                }
            }
        }
        guard status == Int32(kCCSuccess) else { throw PasswordCryptoError.keyDerivationFailed }
        let key = SymmetricKey(data: derived)
        derived.resetBytes(in: 0..<keyLength)
        return key
    }

    static func seal(_ plaintext: Data, password: String, rounds: UInt32 = defaultRounds) throws -> Data {
        let salt = randomBytes(16)
        let key = try deriveKey(password: password, salt: salt, rounds: rounds)
        let sealed = try AES.GCM.seal(plaintext, using: key)
        guard let combined = sealed.combined else { throw PasswordCryptoError.keyDerivationFailed }
        let envelope = Envelope(rounds: rounds, salt: salt, ciphertext: combined)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(envelope)
    }

    static func open(_ fileData: Data, password: String) throws -> Data {
        let envelope = try JSONDecoder().decode(Envelope.self, from: fileData)
        guard envelope.format == "ledgerly-encrypted-backup", envelope.version == 1 else {
            throw PasswordCryptoError.wrongPasswordOrCorrupted
        }
        let key = try deriveKey(password: password, salt: envelope.salt, rounds: envelope.rounds)
        do {
            let box = try AES.GCM.SealedBox(combined: envelope.ciphertext)
            return try AES.GCM.open(box, using: key)
        } catch {
            throw PasswordCryptoError.wrongPasswordOrCorrupted
        }
    }
}

private extension Array where Element == UInt8 {
    mutating func resetBytes(in range: Range<Int>) {
        for i in range { self[i] = 0 }
    }
}
