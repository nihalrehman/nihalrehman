import Foundation
import SwiftData

/// Turns recurring rules into real transactions.
@MainActor
enum RecurrenceEngine {
    /// Posts every overdue occurrence of auto-post rules. Safe to call repeatedly.
    static func processDue(in context: ModelContext, now: Date = Date()) {
        let descriptor = FetchDescriptor<RecurringRule>(predicate: #Predicate { $0.isActive == true && $0.autoPost == true })
        guard let rules = try? context.fetch(descriptor) else { return }
        var changed = false
        for rule in rules {
            var safety = 0
            while rule.isActive && rule.nextDueDate <= now && safety < 400 {
                post(rule, on: rule.nextDueDate, in: context)
                rule.advance()
                safety += 1
                changed = true
            }
        }
        if changed { try? context.save() }
    }

    /// Logs the current occurrence as paid (today, or on its due date if `onDueDate`).
    static func markPaid(_ rule: RecurringRule, in context: ModelContext, onDueDate: Bool = false) {
        let date = onDueDate ? rule.nextDueDate : Date()
        post(rule, on: date, in: context)
        rule.advance()
        try? context.save()
    }

    static func skip(_ rule: RecurringRule, in context: ModelContext) {
        rule.advance()
        try? context.save()
    }

    @discardableResult
    private static func post(_ rule: RecurringRule, on date: Date, in context: ModelContext) -> TransactionRecord {
        let transaction = TransactionRecord(amount: rule.amount, kind: rule.kind, date: date)
        context.insert(transaction)
        transaction.category = rule.category
        transaction.account = rule.account
        transaction.payee = rule.name
        transaction.recurringRuleID = rule.id
        return transaction
    }
}
