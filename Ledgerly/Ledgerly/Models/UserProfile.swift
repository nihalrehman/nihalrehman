import Foundation
import SwiftData

/// The owner's personal details. Every field is individually encrypted with
/// AES-256-GCM before it touches the database.
@Model
final class UserProfile {
    var id: UUID = UUID()
    var fullNameCipher: Data?
    var emailCipher: Data?
    var phoneCipher: Data?
    var addressCipher: Data?
    var dateOfBirthCipher: Data?
    var nationalIDCipher: Data?
    var employerCipher: Data?
    var monthlyIncomeCipher: Data?
    var updatedAt: Date = Date()

    init() {
        self.id = UUID()
        self.updatedAt = Date()
    }

    var fullName: String {
        get { FieldCrypto.open(fullNameCipher) }
        set { fullNameCipher = FieldCrypto.seal(newValue) }
    }

    var email: String {
        get { FieldCrypto.open(emailCipher) }
        set { emailCipher = FieldCrypto.seal(newValue) }
    }

    var phone: String {
        get { FieldCrypto.open(phoneCipher) }
        set { phoneCipher = FieldCrypto.seal(newValue) }
    }

    var address: String {
        get { FieldCrypto.open(addressCipher) }
        set { addressCipher = FieldCrypto.seal(newValue) }
    }

    /// ISO-8601 date string (yyyy-MM-dd), empty if not set.
    var dateOfBirth: String {
        get { FieldCrypto.open(dateOfBirthCipher) }
        set { dateOfBirthCipher = FieldCrypto.seal(newValue) }
    }

    var nationalID: String {
        get { FieldCrypto.open(nationalIDCipher) }
        set { nationalIDCipher = FieldCrypto.seal(newValue) }
    }

    var employer: String {
        get { FieldCrypto.open(employerCipher) }
        set { employerCipher = FieldCrypto.seal(newValue) }
    }

    /// Expected monthly take-home income, stored as an encrypted decimal string.
    var monthlyIncome: Decimal? {
        get { Decimal(string: FieldCrypto.open(monthlyIncomeCipher), locale: Locale(identifier: "en_US_POSIX")) }
        set { monthlyIncomeCipher = FieldCrypto.seal(newValue.map { NSDecimalNumber(decimal: $0).stringValue } ?? "") }
    }

    var firstName: String {
        fullName.split(separator: " ").first.map(String.init) ?? ""
    }
}
