import CryptoKit
import XCTest
@testable import Ledgerly

final class SecurityTests: XCTestCase {
    private let service = CryptoService(fixedKey: SymmetricKey(size: .bits256))

    func testEncryptDecryptRoundTrip() throws {
        let plain = Data("Emirates ID 784-1990-1234567-1".utf8)
        let sealed = try service.encrypt(plain)
        XCTAssertNotEqual(sealed, plain)
        XCTAssertEqual(sealed.first, CryptoService.formatVersion)
        XCTAssertEqual(try service.decrypt(sealed), plain)
    }

    func testCiphertextIsRandomized() throws {
        let plain = Data("same input".utf8)
        XCTAssertNotEqual(try service.encrypt(plain), try service.encrypt(plain), "Each encryption must use a fresh nonce")
    }

    func testTamperingIsDetected() throws {
        var sealed = try service.encrypt(Data("balance 1000".utf8))
        sealed[sealed.count - 1] ^= 0xFF
        XCTAssertThrowsError(try service.decrypt(sealed))
    }

    func testWrongKeyFails() throws {
        let other = CryptoService(fixedKey: SymmetricKey(size: .bits256))
        let sealed = try service.encrypt(Data("secret".utf8))
        XCTAssertThrowsError(try other.decrypt(sealed))
    }

    func testUnknownVersionRejected() throws {
        var sealed = try service.encrypt(Data("x".utf8))
        sealed[0] = 99
        XCTAssertThrowsError(try service.decrypt(sealed))
    }

    func testPasswordBackupRoundTrip() throws {
        let payload = Data("{\"transactions\":[]}".utf8)
        let file = try PasswordCrypto.seal(payload, password: "correct horse battery", rounds: 1_000)
        XCTAssertFalse(String(decoding: file, as: UTF8.self).contains("transactions"))
        XCTAssertEqual(try PasswordCrypto.open(file, password: "correct horse battery"), payload)
    }

    func testPasswordBackupWrongPassword() throws {
        let file = try PasswordCrypto.seal(Data("data".utf8), password: "right-password", rounds: 1_000)
        XCTAssertThrowsError(try PasswordCrypto.open(file, password: "wrong-password"))
    }

    func testKeyDerivationIsDeterministicPerSalt() throws {
        let salt = PasswordCrypto.randomBytes(16)
        let a = try PasswordCrypto.deriveKey(password: "pw12345678", salt: salt, rounds: 1_000)
        let b = try PasswordCrypto.deriveKey(password: "pw12345678", salt: salt, rounds: 1_000)
        let c = try PasswordCrypto.deriveKey(password: "pw12345678", salt: PasswordCrypto.randomBytes(16), rounds: 1_000)
        XCTAssertEqual(a.withUnsafeBytes { Data($0) }, b.withUnsafeBytes { Data($0) })
        XCTAssertNotEqual(a.withUnsafeBytes { Data($0) }, c.withUnsafeBytes { Data($0) })
    }

    func testMasking() {
        XCTAssertEqual(Masking.mask("1234567890"), "•••• 7890")
        XCTAssertEqual(Masking.mask("123"), "•••")
        XCTAssertEqual(Masking.mask(""), "")
        XCTAssertEqual(Masking.maskEmail("jane@example.com"), "j•••@example.com")
    }

    func testCSVEscapingPreventsFormulaInjection() {
        XCTAssertEqual(CSVExporter.escape("=HYPERLINK(\"x\")"), "\"'=HYPERLINK(\"\"x\"\")\"")
        XCTAssertEqual(CSVExporter.escape("+1 555"), "'+1 555")
        XCTAssertEqual(CSVExporter.escape("Coffee, large"), "\"Coffee, large\"")
        XCTAssertEqual(CSVExporter.escape("Groceries"), "Groceries")
    }
}
