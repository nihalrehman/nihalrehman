import Foundation
import SwiftData
import SwiftUI

/// A debt being paid down: mortgage, car loan, credit card balance, student loan, etc.
@Model
final class Loan {
    var id: UUID = UUID()
    var name: String = ""
    var typeRaw: String = DebtType.personalLoan.rawValue
    var lenderCipher: Data?
    var accountNumberCipher: Data?
    var notesCipher: Data?
    var originalAmount: Decimal = 0
    var currentBalance: Decimal = 0
    /// Annual percentage rate, e.g. 4.5 for 4.5%.
    var interestRate: Double = 0
    /// Total term in months (0 for revolving debt such as credit cards).
    var termMonths: Int = 0
    var startDate: Date = Date()
    var monthlyPayment: Decimal = 0
    var paymentDayOfMonth: Int = 1
    /// Credit limit, for credit cards.
    var creditLimit: Decimal = 0
    var isClosed: Bool = false
    var createdAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \LoanPayment.loan)
    var payments: [LoanPayment]? = []

    init(name: String, type: DebtType, originalAmount: Decimal, currentBalance: Decimal, interestRate: Double, termMonths: Int, monthlyPayment: Decimal, startDate: Date) {
        self.id = UUID()
        self.name = name
        self.typeRaw = type.rawValue
        self.originalAmount = originalAmount
        self.currentBalance = currentBalance
        self.interestRate = interestRate
        self.termMonths = termMonths
        self.monthlyPayment = monthlyPayment
        self.startDate = startDate
        self.createdAt = Date()
    }

    var type: DebtType {
        get { DebtType(rawValue: typeRaw) ?? .other }
        set { typeRaw = newValue.rawValue }
    }

    var color: Color { Color(hex: type.colorHex) }

    var lender: String {
        get { FieldCrypto.open(lenderCipher) }
        set { lenderCipher = FieldCrypto.seal(newValue) }
    }

    var accountNumber: String {
        get { FieldCrypto.open(accountNumberCipher) }
        set { accountNumberCipher = FieldCrypto.seal(newValue) }
    }

    var notes: String {
        get { FieldCrypto.open(notesCipher) }
        set { notesCipher = FieldCrypto.seal(newValue) }
    }

    var sortedPayments: [LoanPayment] {
        (payments ?? []).sorted { $0.date > $1.date }
    }

    /// Share of the original amount already repaid (0...1).
    var progress: Double {
        guard originalAmount > 0 else { return 0 }
        let paid = (originalAmount - currentBalance).doubleValue / originalAmount.doubleValue
        return min(max(paid, 0), 1)
    }

    /// Credit utilisation for credit cards (0...1+).
    var utilization: Double? {
        guard type.isRevolving, creditLimit > 0 else { return nil }
        return currentBalance.doubleValue / creditLimit.doubleValue
    }

    var payoff: PayoffSummary {
        LoanCalculator.payoffSummary(balance: currentBalance, annualRatePercent: interestRate, payment: monthlyPayment, startDate: nextPaymentDate)
    }

    /// Next date a payment is due, based on the configured payment day.
    var nextPaymentDate: Date {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        var comps = cal.dateComponents([.year, .month], from: today)
        let day = min(max(paymentDayOfMonth, 1), 28)
        comps.day = day
        let thisMonth = cal.date(from: comps) ?? today
        return thisMonth >= today ? thisMonth : (cal.date(byAdding: .month, value: 1, to: thisMonth) ?? thisMonth)
    }

    /// Records a payment: splits it into interest and principal and reduces the balance.
    @discardableResult
    func applyPayment(amount: Decimal, date: Date, isExtra: Bool) -> LoanPayment {
        let interest = isExtra ? 0 : LoanCalculator.monthlyInterest(balance: currentBalance, annualRatePercent: interestRate)
        let interestPart = min(interest, amount)
        let principalPart = min(amount - interestPart, currentBalance)
        let payment = LoanPayment(date: date, amount: amount, principalPortion: principalPart, interestPortion: interestPart, isExtra: isExtra)
        currentBalance = max(currentBalance - principalPart, 0)
        if currentBalance == 0 && !type.isRevolving { isClosed = true }
        return payment
    }
}

@Model
final class LoanPayment {
    var id: UUID = UUID()
    var date: Date = Date()
    var amount: Decimal = 0
    var principalPortion: Decimal = 0
    var interestPortion: Decimal = 0
    var isExtra: Bool = false
    var loan: Loan?

    init(date: Date, amount: Decimal, principalPortion: Decimal, interestPortion: Decimal, isExtra: Bool) {
        self.id = UUID()
        self.date = date
        self.amount = amount
        self.principalPortion = principalPortion
        self.interestPortion = interestPortion
        self.isExtra = isExtra
    }
}
