import XCTest
@testable import Ledgerly

final class FinanceTests: XCTestCase {
    private let start = Calendar.current.date(from: DateComponents(year: 2026, month: 1, day: 31))!

    // MARK: Loan maths

    func testMonthlyPaymentMatchesStandardFormula() {
        // 300,000 over 30 years at 6% → 1,798.65 / month (standard amortization tables).
        let payment = LoanCalculator.monthlyPayment(principal: 300_000, annualRatePercent: 6, months: 360)
        XCTAssertEqual(payment.doubleValue, 1798.66, accuracy: 0.02)
    }

    func testZeroInterestPayment() {
        let payment = LoanCalculator.monthlyPayment(principal: 12_000, annualRatePercent: 0, months: 12)
        XCTAssertEqual(payment, 1000)
    }

    func testScheduleRepaysLoanInTerm() {
        let payment = LoanCalculator.monthlyPayment(principal: 20_000, annualRatePercent: 5, months: 60)
        let rows = LoanCalculator.schedule(balance: 20_000, annualRatePercent: 5, payment: payment, startDate: start)
        XCTAssertEqual(rows.last?.balance, 0)
        XCTAssertLessThanOrEqual(rows.count, 60)
        XCTAssertGreaterThanOrEqual(rows.count, 59)
        let principalTotal = rows.reduce(Decimal(0)) { $0 + $1.principal }
        XCTAssertEqual(principalTotal, 20_000)
    }

    func testExtraPaymentShortensLoanAndSavesInterest() {
        let base = LoanCalculator.payoffSummary(balance: 20_000, annualRatePercent: 5, payment: 377.42, startDate: start)
        let extra = LoanCalculator.payoffSummary(balance: 20_000, annualRatePercent: 5, payment: 377.42, extraPayment: 100, startDate: start)
        XCTAssertLessThan(extra.months!, base.months!)
        XCTAssertLessThan(extra.totalInterest, base.totalInterest)
    }

    func testPaymentBelowInterestNeverPaysOff() {
        // 10,000 at 24% APR accrues 200/month; paying 150 never clears it.
        let summary = LoanCalculator.payoffSummary(balance: 10_000, annualRatePercent: 24, payment: 150, startDate: start)
        XCTAssertTrue(summary.neverPaysOff)
    }

    func testMonthlyInterest() {
        XCTAssertEqual(LoanCalculator.monthlyInterest(balance: 12_000, annualRatePercent: 12), 120)
        XCTAssertEqual(LoanCalculator.monthlyInterest(balance: 0, annualRatePercent: 12), 0)
    }

    // MARK: Recurrence

    func testMonthlyRecurrenceDoesNotDrift() {
        let f = RecurrenceFrequency.monthly
        let cal = Calendar.current
        let third = f.date(from: start, occurrence: 2) // Jan 31 → Mar 31
        XCTAssertEqual(cal.component(.month, from: third), 3)
        XCTAssertEqual(cal.component(.day, from: third), 31)
    }

    func testWeeklyAndYearlyRecurrence() {
        let cal = Calendar.current
        let week = RecurrenceFrequency.biweekly.date(from: start, occurrence: 1)
        XCTAssertEqual(cal.dateComponents([.day], from: start, to: week).day, 14)
        let year = RecurrenceFrequency.yearly.date(from: start, occurrence: 1)
        XCTAssertEqual(cal.component(.year, from: year), 2027)
    }

    // MARK: Helpers

    func testDecimalRounding() {
        XCTAssertEqual(Decimal(string: "10.005")!.rounded(2), Decimal(string: "10.01")!)
        XCTAssertEqual(Decimal(string: "10.004")!.rounded(2), Decimal(string: "10")!)
    }

    func testSavingsRate() {
        XCTAssertEqual(FinanceMath.savingsRate(income: 1000, expenses: 750)!, 0.25, accuracy: 0.0001)
        XCTAssertNil(FinanceMath.savingsRate(income: 0, expenses: 10))
    }

    func testMonthRangeIsHalfOpen() {
        let range = start.monthRange
        XCTAssertTrue(range.contains(start))
        XCTAssertFalse(range.contains(range.upperBound))
        XCTAssertEqual(Calendar.current.component(.day, from: range.lowerBound), 1)
    }
}
