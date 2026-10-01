import SwiftData
import SwiftUI

/// Records a debt payment, splits it into principal/interest, and optionally
/// logs it as an expense from one of the user's accounts.
struct RecordPaymentView: View {
    let loan: Loan

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Account.sortOrder) private var accounts: [Account]
    @Query private var categories: [LedgerCategory]

    @State private var amount: Decimal?
    @State private var date = Date()
    @State private var isExtra = false
    @State private var logExpense = true
    @State private var account: Account?

    init(loan: Loan) {
        self.loan = loan
        _amount = State(initialValue: loan.monthlyPayment > 0 ? min(loan.monthlyPayment, loan.currentBalance + LoanCalculator.monthlyInterest(balance: loan.currentBalance, annualRatePercent: loan.interestRate)) : nil)
    }

    private var interest: Decimal {
        isExtra ? 0 : LoanCalculator.monthlyInterest(balance: loan.currentBalance, annualRatePercent: loan.interestRate)
    }

    private var principal: Decimal {
        guard let amount else { return 0 }
        return max(min(amount - min(interest, amount), loan.currentBalance), 0)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Payment") {
                    AmountField(title: "Amount", amount: $amount, large: true)
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                    Toggle("Extra payment (all to principal)", isOn: $isExtra)
                }

                Section("Breakdown") {
                    LabeledContent("Interest") { MoneyText(min(interest, amount ?? 0)) }
                    LabeledContent("Principal") { MoneyText(principal) }
                    LabeledContent("New balance") { MoneyText(max(loan.currentBalance - principal, 0)).bold() }
                }

                Section {
                    Toggle("Log as an expense", isOn: $logExpense)
                    if logExpense {
                        Picker("Paid from", selection: $account) {
                            Text("None").tag(nil as Account?)
                            ForEach(accounts.filter { !$0.isArchived }) { Text($0.name).tag($0 as Account?) }
                        }
                    }
                } footer: {
                    Text("Adds the payment to your spending under “\(loan.type.paymentCategoryName)” so your budgets and reports stay complete.")
                }
            }
            .navigationTitle("Record Payment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).disabled((amount ?? 0) <= 0)
                }
            }
            .onAppear {
                if account == nil { account = accounts.first { $0.type == .checking && !$0.isArchived } ?? accounts.first }
            }
        }
    }

    private func save() {
        guard let amount, amount > 0 else { return }
        let payment = loan.applyPayment(amount: amount, date: date, isExtra: isExtra)
        modelContext.insert(payment)
        payment.loan = loan

        if logExpense {
            let expense = TransactionRecord(amount: amount, kind: .expense, date: date)
            modelContext.insert(expense)
            expense.category = categories.first { $0.name == loan.type.paymentCategoryName && $0.kind == .expense }
            expense.account = account
            expense.payee = loan.name
            expense.loanPaymentID = payment.id
        }
        try? modelContext.save()
        dismiss()
    }
}

/// Manually corrects a balance — e.g. new credit card charges or a lender statement.
struct AdjustBalanceView: View {
    let loan: Loan

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var newBalance: Decimal?

    init(loan: Loan) {
        self.loan = loan
        _newBalance = State(initialValue: loan.currentBalance)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    AmountField(title: "Balance", amount: $newBalance, large: true)
                } header: {
                    Text("Current balance")
                } footer: {
                    Text(loan.type.isRevolving
                         ? "Enter the balance from your latest statement or banking app, including new purchases."
                         : "Use this if your lender's statement differs from Ledgerly's estimate.")
                }
            }
            .navigationTitle("Update Balance")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let value = max(newBalance ?? 0, 0)
                        loan.currentBalance = value
                        if value > loan.originalAmount { loan.originalAmount = value }
                        loan.isClosed = value == 0 && !loan.type.isRevolving
                        try? modelContext.save()
                        dismiss()
                    }
                    .disabled(newBalance == nil)
                }
            }
        }
    }
}
