import Foundation
import SwiftUI

struct CategoryTotal: Identifiable, Hashable {
    let id: String
    let name: String
    let icon: String
    let colorHex: String
    let amount: Decimal

    var color: Color { Color(hex: colorHex) }
}

struct DailyTotal: Identifiable, Hashable {
    var id: Date { day }
    let day: Date
    let amount: Decimal
}

struct PayeeTotal: Identifiable, Hashable {
    var id: String { name }
    let name: String
    let amount: Decimal
    let count: Int
}

struct MonthTotal: Identifiable, Hashable {
    var id: Date { month }
    let month: Date
    let income: Decimal
    let expenses: Decimal

    var net: Decimal { income - expenses }
}

/// Aggregations used by the dashboard and reports.
enum FinanceMath {
    static func transactions(_ all: [TransactionRecord], in range: Range<Date>) -> [TransactionRecord] {
        all.filter { range.contains($0.date) }
    }

    static func total(_ txs: [TransactionRecord], kind: TransactionKind) -> Decimal {
        txs.filter { $0.kind == kind }.sum(\.amount)
    }

    /// Expenses grouped by top-level category, largest first.
    static func expensesByGroup(_ txs: [TransactionRecord]) -> [CategoryTotal] {
        grouped(txs.filter { $0.kind == .expense }) { $0.category?.root }
    }

    /// Expenses grouped by the exact (sub)category, largest first.
    static func expensesBySubcategory(_ txs: [TransactionRecord]) -> [CategoryTotal] {
        grouped(txs.filter { $0.kind == .expense }) { $0.category }
    }

    static func incomeBySource(_ txs: [TransactionRecord]) -> [CategoryTotal] {
        grouped(txs.filter { $0.kind == .income }) { $0.category?.root }
    }

    private static func grouped(_ txs: [TransactionRecord], key: (TransactionRecord) -> LedgerCategory?) -> [CategoryTotal] {
        var totals: [String: (category: LedgerCategory?, amount: Decimal)] = [:]
        for t in txs {
            let category = key(t)
            let id = category?.id.uuidString ?? "uncategorized"
            totals[id, default: (category, 0)].amount += t.amount
        }
        return totals.map { id, entry in
            CategoryTotal(
                id: id,
                name: entry.category?.name ?? "Uncategorized",
                icon: entry.category?.icon ?? "questionmark.circle.fill",
                colorHex: entry.category?.colorHex ?? "#8E8E93",
                amount: entry.amount
            )
        }
        .sorted { $0.amount > $1.amount }
    }

    /// Income and expenses per month for the `count` months ending with `endingMonth`.
    static func monthlyTotals(_ txs: [TransactionRecord], endingMonth: Date, count: Int) -> [MonthTotal] {
        (0..<count).reversed().map { offset in
            let month = endingMonth.startOfMonth.adding(months: -offset)
            let monthTxs = transactions(txs, in: month.monthRange)
            return MonthTotal(month: month, income: total(monthTxs, kind: .income), expenses: total(monthTxs, kind: .expense))
        }
    }

    /// Expenses per day within the month (days with no spending included as zero).
    static func dailyExpenses(_ txs: [TransactionRecord], month: Date) -> [DailyTotal] {
        let start = month.startOfMonth
        var byDay: [Date: Decimal] = [:]
        for t in txs where t.kind == .expense && month.monthRange.contains(t.date) {
            byDay[t.date.startOfDay, default: 0] += t.amount
        }
        return (0..<month.daysInMonth).map { offset in
            let day = start.adding(days: offset)
            return DailyTotal(day: day, amount: byDay[day] ?? 0)
        }
    }

    /// Top payees by total spend (payee names are decrypted in memory only).
    static func topPayees(_ txs: [TransactionRecord], limit: Int = 5) -> [PayeeTotal] {
        var totals: [String: (amount: Decimal, count: Int)] = [:]
        for t in txs where t.kind == .expense {
            let name = t.payee.trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty else { continue }
            totals[name, default: (0, 0)].amount += t.amount
            totals[name, default: (0, 0)].count += 1
        }
        let sorted = totals
            .map { PayeeTotal(name: $0.key, amount: $0.value.amount, count: $0.value.count) }
            .sorted { $0.amount > $1.amount }
        return Array(sorted.prefix(limit))
    }

    /// Share of income kept (0...1, may be negative when overspending).
    static func savingsRate(income: Decimal, expenses: Decimal) -> Double? {
        guard income > 0 else { return nil }
        return (income - expenses).doubleValue / income.doubleValue
    }
}
