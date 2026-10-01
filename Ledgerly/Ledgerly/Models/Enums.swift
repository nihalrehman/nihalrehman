import Foundation

enum TransactionKind: String, CaseIterable, Identifiable, Codable {
    case expense, income, transfer

    var id: String { rawValue }

    var title: String {
        switch self {
        case .expense: "Expense"
        case .income: "Income"
        case .transfer: "Transfer"
        }
    }

    var icon: String {
        switch self {
        case .expense: "arrow.up.right.circle.fill"
        case .income: "arrow.down.left.circle.fill"
        case .transfer: "arrow.left.arrow.right.circle.fill"
        }
    }

    /// The category kind that applies to this transaction kind (transfers have no category).
    var categoryKind: CategoryKind? {
        switch self {
        case .expense: .expense
        case .income: .income
        case .transfer: nil
        }
    }
}

enum CategoryKind: String, CaseIterable, Identifiable, Codable {
    case expense, income

    var id: String { rawValue }
    var title: String { self == .expense ? "Expenses" : "Income" }
}

enum AccountType: String, CaseIterable, Identifiable, Codable {
    case cash, checking, savings, creditCard, digitalWallet, investment, other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .cash: "Cash"
        case .checking: "Current / Checking"
        case .savings: "Savings"
        case .creditCard: "Credit Card"
        case .digitalWallet: "Digital Wallet"
        case .investment: "Investment"
        case .other: "Other"
        }
    }

    var icon: String {
        switch self {
        case .cash: "banknote.fill"
        case .checking: "building.columns.fill"
        case .savings: "dollarsign.circle.fill"
        case .creditCard: "creditcard.fill"
        case .digitalWallet: "wallet.pass.fill"
        case .investment: "chart.line.uptrend.xyaxis"
        case .other: "tray.full.fill"
        }
    }

    /// Liability accounts normally carry a negative balance (money owed).
    var isLiability: Bool { self == .creditCard }
}

enum DebtType: String, CaseIterable, Identifiable, Codable {
    case homeMortgage, carLoan, creditCard, personalLoan, studentLoan, businessLoan, medical, other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .homeMortgage: "Home Mortgage"
        case .carLoan: "Car Loan"
        case .creditCard: "Credit Card"
        case .personalLoan: "Personal Loan"
        case .studentLoan: "Student Loan"
        case .businessLoan: "Business Loan"
        case .medical: "Medical Debt"
        case .other: "Other Debt"
        }
    }

    var icon: String {
        switch self {
        case .homeMortgage: "house.fill"
        case .carLoan: "car.fill"
        case .creditCard: "creditcard.fill"
        case .personalLoan: "person.fill"
        case .studentLoan: "graduationcap.fill"
        case .businessLoan: "briefcase.fill"
        case .medical: "cross.case.fill"
        case .other: "doc.text.fill"
        }
    }

    var colorHex: String {
        switch self {
        case .homeMortgage: "#5E5CE6"
        case .carLoan: "#0A84FF"
        case .creditCard: "#FF375F"
        case .personalLoan: "#FF9F0A"
        case .studentLoan: "#64D2FF"
        case .businessLoan: "#30D158"
        case .medical: "#FF453A"
        case .other: "#8E8E93"
        }
    }

    /// Revolving debt has no fixed term (e.g. credit cards).
    var isRevolving: Bool { self == .creditCard }

    /// Name of the seeded expense category used when a payment is logged as an expense.
    var paymentCategoryName: String {
        switch self {
        case .homeMortgage: "Mortgage Payment"
        case .carLoan: "Car Loan Payment"
        case .creditCard: "Credit Card Payment"
        case .personalLoan: "Personal Loan Payment"
        case .studentLoan: "Student Loan Payment"
        case .businessLoan, .medical, .other: "Other Debt Payment"
        }
    }
}

enum RecurrenceFrequency: String, CaseIterable, Identifiable, Codable {
    case daily, weekly, biweekly, monthly, quarterly, semiannual, yearly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .daily: "Daily"
        case .weekly: "Weekly"
        case .biweekly: "Every 2 Weeks"
        case .monthly: "Monthly"
        case .quarterly: "Quarterly"
        case .semiannual: "Every 6 Months"
        case .yearly: "Yearly"
        }
    }

    private var step: (component: Calendar.Component, value: Int) {
        switch self {
        case .daily: (.day, 1)
        case .weekly: (.day, 7)
        case .biweekly: (.day, 14)
        case .monthly: (.month, 1)
        case .quarterly: (.month, 3)
        case .semiannual: (.month, 6)
        case .yearly: (.year, 1)
        }
    }

    /// Date of the n-th occurrence counted from `start` (occurrence 0 is `start`).
    /// Computing from the anchor avoids day drift (e.g. Jan 31 → Feb 28 → Mar 28).
    func date(from start: Date, occurrence: Int, calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: step.component, value: step.value * occurrence, to: start) ?? start
    }

    /// Approximate number of occurrences per year, used for monthly-equivalent figures.
    var perYear: Double {
        switch self {
        case .daily: 365
        case .weekly: 52
        case .biweekly: 26
        case .monthly: 12
        case .quarterly: 4
        case .semiannual: 2
        case .yearly: 1
        }
    }
}
