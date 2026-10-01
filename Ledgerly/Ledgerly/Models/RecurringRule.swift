import Foundation
import SwiftData

/// A repeating bill, subscription or income (rent, salary, Netflix, school fees...).
/// When `autoPost` is on, due occurrences are logged automatically; otherwise they
/// show up as upcoming bills to mark as paid or skip.
@Model
final class RecurringRule {
    var id: UUID = UUID()
    var name: String = ""
    var amount: Decimal = 0
    var kindRaw: String = TransactionKind.expense.rawValue
    var frequencyRaw: String = RecurrenceFrequency.monthly.rawValue
    var startDate: Date = Date()
    var nextDueDate: Date = Date()
    var endDate: Date?
    var occurrencesPosted: Int = 0
    var autoPost: Bool = false
    /// Days before the due date to send a reminder; negative disables reminders.
    var remindDaysBefore: Int = 1
    var isActive: Bool = true
    var notesCipher: Data?
    var createdAt: Date = Date()

    var category: LedgerCategory?
    var account: Account?

    init(name: String, amount: Decimal, kind: TransactionKind, frequency: RecurrenceFrequency, startDate: Date) {
        self.id = UUID()
        self.name = name
        self.amount = amount
        self.kindRaw = kind.rawValue
        self.frequencyRaw = frequency.rawValue
        self.startDate = startDate
        self.nextDueDate = startDate
        self.createdAt = Date()
    }

    var kind: TransactionKind {
        get { TransactionKind(rawValue: kindRaw) ?? .expense }
        set { kindRaw = newValue.rawValue }
    }

    var frequency: RecurrenceFrequency {
        get { RecurrenceFrequency(rawValue: frequencyRaw) ?? .monthly }
        set { frequencyRaw = newValue.rawValue }
    }

    var notes: String {
        get { FieldCrypto.open(notesCipher) }
        set { notesCipher = FieldCrypto.seal(newValue) }
    }

    /// Average monthly cost, useful for "fixed costs" summaries.
    var monthlyEquivalent: Decimal {
        (amount * Decimal(frequency.perYear) / 12).rounded(2)
    }

    /// Moves `nextDueDate` to the following occurrence and deactivates the rule past its end date.
    func advance() {
        occurrencesPosted += 1
        nextDueDate = frequency.date(from: startDate, occurrence: occurrencesPosted)
        if let endDate, nextDueDate > endDate {
            isActive = false
        }
    }

    /// Re-anchors the schedule (used after editing the start date or frequency).
    func resetSchedule(from start: Date) {
        startDate = start
        occurrencesPosted = 0
        nextDueDate = start
        isActive = endDate.map { start <= $0 } ?? true
    }
}
