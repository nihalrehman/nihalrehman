import Foundation
import SwiftData
import SwiftUI

/// Where money is held or spent from: cash, bank accounts, cards, wallets.
@Model
final class Account {
    var id: UUID = UUID()
    var name: String = ""
    var typeRaw: String = AccountType.checking.rawValue
    var openingBalance: Decimal = 0
    var institutionCipher: Data?
    var accountNumberCipher: Data?
    var colorHex: String = "#0A84FF"
    var isArchived: Bool = false
    var includeInNetWorth: Bool = true
    var sortOrder: Int = 0
    var createdAt: Date = Date()

    @Relationship(deleteRule: .nullify, inverse: \TransactionRecord.account)
    var transactions: [TransactionRecord]? = []

    @Relationship(deleteRule: .nullify, inverse: \TransactionRecord.transferAccount)
    var incomingTransfers: [TransactionRecord]? = []

    @Relationship(deleteRule: .nullify, inverse: \RecurringRule.account)
    var recurringRules: [RecurringRule]? = []

    init(name: String, type: AccountType, openingBalance: Decimal = 0, colorHex: String = "#0A84FF", sortOrder: Int = 0) {
        self.id = UUID()
        self.name = name
        self.typeRaw = type.rawValue
        self.openingBalance = openingBalance
        self.colorHex = colorHex
        self.sortOrder = sortOrder
        self.createdAt = Date()
    }

    var type: AccountType {
        get { AccountType(rawValue: typeRaw) ?? .other }
        set { typeRaw = newValue.rawValue }
    }

    var color: Color { Color(hex: colorHex) }

    var institution: String {
        get { FieldCrypto.open(institutionCipher) }
        set { institutionCipher = FieldCrypto.seal(newValue) }
    }

    var accountNumber: String {
        get { FieldCrypto.open(accountNumberCipher) }
        set { accountNumberCipher = FieldCrypto.seal(newValue) }
    }

    var maskedNumber: String { Masking.mask(accountNumber) }

    /// Current balance: opening balance plus all movements in and out of this account.
    var balance: Decimal {
        var total = openingBalance
        for t in transactions ?? [] {
            switch t.kind {
            case .income: total += t.amount
            case .expense, .transfer: total -= t.amount
            }
        }
        for t in incomingTransfers ?? [] where t.kind == .transfer {
            total += t.amount
        }
        return total
    }
}
