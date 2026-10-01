import Foundation
import SwiftData

/// A single money movement: an expense, an income, or a transfer between accounts.
/// Free-text fields that can identify people or places (payee, notes) are stored
/// encrypted with AES-256-GCM; see `FieldCrypto`.
@Model
final class TransactionRecord {
    var id: UUID = UUID()
    var amount: Decimal = 0
    var kindRaw: String = TransactionKind.expense.rawValue
    var date: Date = Date()
    var createdAt: Date = Date()
    var payeeCipher: Data?
    var notesCipher: Data?
    /// Set when the transaction was generated from a recurring rule.
    var recurringRuleID: UUID?
    /// Set when the transaction was created by recording a debt payment.
    var loanPaymentID: UUID?

    var category: LedgerCategory?
    /// Source account (money leaves it for expenses/transfers, arrives for income).
    var account: Account?
    /// Destination account for transfers.
    var transferAccount: Account?

    init(amount: Decimal, kind: TransactionKind, date: Date) {
        self.id = UUID()
        self.amount = amount
        self.kindRaw = kind.rawValue
        self.date = date
        self.createdAt = Date()
    }

    var kind: TransactionKind {
        get { TransactionKind(rawValue: kindRaw) ?? .expense }
        set { kindRaw = newValue.rawValue }
    }

    var payee: String {
        get { FieldCrypto.open(payeeCipher) }
        set { payeeCipher = FieldCrypto.seal(newValue) }
    }

    var notes: String {
        get { FieldCrypto.open(notesCipher) }
        set { notesCipher = FieldCrypto.seal(newValue) }
    }

    /// Effect on overall cash flow: income positive, expense negative, transfers neutral.
    var signedAmount: Decimal {
        switch kind {
        case .income: amount
        case .expense: -amount
        case .transfer: 0
        }
    }

    var displayTitle: String {
        let p = payee
        if !p.isEmpty { return p }
        if kind == .transfer {
            return "Transfer to \(transferAccount?.name ?? "account")"
        }
        return category?.name ?? kind.title
    }
}
