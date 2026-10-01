import Foundation

struct AmortizationRow: Identifiable, Hashable {
    let id: Int          // 1-based payment number
    let date: Date
    let payment: Decimal
    let principal: Decimal
    let interest: Decimal
    let balance: Decimal
}

struct PayoffSummary: Equatable {
    /// Months until the balance reaches zero; nil if the payment never covers interest.
    let months: Int?
    let totalInterest: Decimal
    let totalPaid: Decimal
    let payoffDate: Date?

    var neverPaysOff: Bool { months == nil }
}

/// Pure loan math (no persistence), so it can be unit-tested.
enum LoanCalculator {
    static let maxMonths = 1200 // 100 years safety cap

    /// Standard amortizing payment (EMI): P·r / (1 − (1 + r)^−n).
    static func monthlyPayment(principal: Decimal, annualRatePercent: Double, months: Int) -> Decimal {
        guard months > 0, principal > 0 else { return 0 }
        let p = principal.doubleValue
        let r = annualRatePercent / 100 / 12
        let payment: Double
        if r == 0 {
            payment = p / Double(months)
        } else {
            payment = p * r / (1 - pow(1 + r, -Double(months)))
        }
        return Decimal(payment).rounded(2, mode: .up)
    }

    static func monthlyInterest(balance: Decimal, annualRatePercent: Double) -> Decimal {
        guard balance > 0, annualRatePercent > 0 else { return 0 }
        let rate = Decimal(annualRatePercent) / 100 / 12
        return (balance * rate).rounded(2)
    }

    /// Month-by-month schedule until the balance is paid off (or the safety cap is hit).
    static func schedule(balance: Decimal, annualRatePercent: Double, payment: Decimal, extraPayment: Decimal = 0, startDate: Date) -> [AmortizationRow] {
        var rows: [AmortizationRow] = []
        var remaining = balance
        let totalPayment = payment + extraPayment
        guard remaining > 0, totalPayment > 0 else { return rows }

        var month = 0
        while remaining > 0 && month < maxMonths {
            let interest = monthlyInterest(balance: remaining, annualRatePercent: annualRatePercent)
            if totalPayment <= interest { break } // never pays off
            let principal = min(totalPayment - interest, remaining)
            remaining -= principal
            month += 1
            let date = Calendar.current.date(byAdding: .month, value: month - 1, to: startDate) ?? startDate
            rows.append(AmortizationRow(id: month, date: date, payment: principal + interest, principal: principal, interest: interest, balance: remaining))
        }
        return rows
    }

    static func payoffSummary(balance: Decimal, annualRatePercent: Double, payment: Decimal, extraPayment: Decimal = 0, startDate: Date) -> PayoffSummary {
        if balance <= 0 {
            return PayoffSummary(months: 0, totalInterest: 0, totalPaid: 0, payoffDate: startDate)
        }
        let rows = schedule(balance: balance, annualRatePercent: annualRatePercent, payment: payment, extraPayment: extraPayment, startDate: startDate)
        guard let last = rows.last, last.balance == 0 else {
            return PayoffSummary(months: nil, totalInterest: 0, totalPaid: 0, payoffDate: nil)
        }
        let interest = rows.sum(\.interest)
        let paid = rows.sum(\.payment)
        return PayoffSummary(months: rows.count, totalInterest: interest, totalPaid: paid, payoffDate: last.date)
    }

    /// Orders debts for payoff. Avalanche = highest interest first (saves the most money);
    /// snowball = smallest balance first (quickest wins).
    enum Strategy: String, CaseIterable, Identifiable {
        case avalanche, snowball
        var id: String { rawValue }
        var title: String { self == .avalanche ? "Avalanche" : "Snowball" }
        var explanation: String {
            switch self {
            case .avalanche: "Pay minimums on everything, then put extra money toward the highest interest rate first. Saves the most interest."
            case .snowball: "Pay minimums on everything, then put extra money toward the smallest balance first. Builds momentum with quick wins."
            }
        }
    }

    static func order(_ loans: [Loan], by strategy: Strategy) -> [Loan] {
        let active = loans.filter { !$0.isClosed && $0.currentBalance > 0 }
        switch strategy {
        case .avalanche:
            return active.sorted { $0.interestRate == $1.interestRate ? $0.currentBalance < $1.currentBalance : $0.interestRate > $1.interestRate }
        case .snowball:
            return active.sorted { $0.currentBalance == $1.currentBalance ? $0.interestRate > $1.interestRate : $0.currentBalance < $1.currentBalance }
        }
    }
}
