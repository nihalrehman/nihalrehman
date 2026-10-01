import Foundation
import SwiftData

/// A monthly spending limit for a category group, a single subcategory,
/// or (when `category` is nil) for all spending.
@Model
final class Budget {
    var id: UUID = UUID()
    var limit: Decimal = 0
    /// Fraction of the limit (0...1) at which the budget is flagged as "close".
    var alertThreshold: Double = 0.8
    var createdAt: Date = Date()

    var category: LedgerCategory?

    init(limit: Decimal, alertThreshold: Double = 0.8) {
        self.id = UUID()
        self.limit = limit
        self.alertThreshold = alertThreshold
        self.createdAt = Date()
    }

    var isOverall: Bool { category == nil }

    var title: String { category?.fullName ?? "All Spending" }

    /// Total expenses in the given month that fall under this budget.
    func spent(in month: Date, from transactions: [TransactionRecord]) -> Decimal {
        let range = month.monthRange
        return transactions.reduce(into: Decimal(0)) { sum, t in
            guard t.kind == .expense, range.contains(t.date) else { return }
            if let category {
                if category.encompasses(t.category) { sum += t.amount }
            } else {
                sum += t.amount
            }
        }
    }
}
