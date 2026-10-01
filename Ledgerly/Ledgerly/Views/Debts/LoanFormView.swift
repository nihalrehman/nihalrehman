import SwiftData
import SwiftUI

struct LoanFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    private let loan: Loan?

    @State private var type: DebtType
    @State private var name: String
    @State private var lender: String
    @State private var accountNumber: String
    @State private var originalAmount: Decimal?
    @State private var currentBalance: Decimal?
    @State private var interestRate: Double?
    @State private var termYears: Int
    @State private var termExtraMonths: Int
    @State private var startDate: Date
    @State private var monthlyPayment: Decimal?
    @State private var paymentDay: Int
    @State private var creditLimit: Decimal?
    @State private var notes: String

    init(loan: Loan? = nil) {
        self.loan = loan
        _type = State(initialValue: loan?.type ?? .homeMortgage)
        _name = State(initialValue: loan?.name ?? "")
        _lender = State(initialValue: loan?.lender ?? "")
        _accountNumber = State(initialValue: loan?.accountNumber ?? "")
        _originalAmount = State(initialValue: loan?.originalAmount)
        _currentBalance = State(initialValue: loan?.currentBalance)
        _interestRate = State(initialValue: loan?.interestRate)
        _termYears = State(initialValue: (loan?.termMonths ?? 0) / 12)
        _termExtraMonths = State(initialValue: (loan?.termMonths ?? 0) % 12)
        _startDate = State(initialValue: loan?.startDate ?? Date())
        _monthlyPayment = State(initialValue: loan?.monthlyPayment)
        _paymentDay = State(initialValue: loan?.paymentDayOfMonth ?? 1)
        _creditLimit = State(initialValue: (loan?.creditLimit).flatMap { $0 > 0 ? $0 : nil })
        _notes = State(initialValue: loan?.notes ?? "")
    }

    private var termMonths: Int { termYears * 12 + termExtraMonths }

    private var suggestedPayment: Decimal? {
        guard !type.isRevolving, let principal = originalAmount, principal > 0, termMonths > 0 else { return nil }
        return LoanCalculator.monthlyPayment(principal: principal, annualRatePercent: interestRate ?? 0, months: termMonths)
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && (currentBalance ?? originalAmount ?? 0) >= 0 && (originalAmount ?? currentBalance) != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Type", selection: $type) {
                        ForEach(DebtType.allCases) { Label($0.title, systemImage: $0.icon).tag($0) }
                    }
                    TextField("Name (e.g. \(placeholderName))", text: $name)
                }

                Section {
                    TextField(type.isRevolving ? "Card issuer / bank" : "Lender / bank", text: $lender)
                    TextField(type.isRevolving ? "Card number (last 4 is enough)" : "Loan account number", text: $accountNumber)
                        .keyboardType(.asciiCapable)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                } header: {
                    Text("Lender")
                } footer: {
                    EncryptedFootnote(text: "Lender and account number are encrypted and masked in the app.")
                }

                Section("Amounts") {
                    LabeledContent(type.isRevolving ? "Highest balance" : "Original amount") {
                        AmountField(title: "0", amount: $originalAmount).multilineTextAlignment(.trailing)
                    }
                    LabeledContent("Current balance") {
                        AmountField(title: "Same as original", amount: $currentBalance).multilineTextAlignment(.trailing)
                    }
                    if type.isRevolving {
                        LabeledContent("Credit limit") {
                            AmountField(title: "0", amount: $creditLimit).multilineTextAlignment(.trailing)
                        }
                    }
                    LabeledContent("Interest rate (APR %)") {
                        TextField("0", value: $interestRate, format: .number.precision(.fractionLength(0...3)))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                }

                if !type.isRevolving {
                    Section("Term") {
                        Stepper("\(termYears) year\(termYears == 1 ? "" : "s")", value: $termYears, in: 0...40)
                        Stepper("+ \(termExtraMonths) month\(termExtraMonths == 1 ? "" : "s")", value: $termExtraMonths, in: 0...11)
                        DatePicker("Start date", selection: $startDate, displayedComponents: .date)
                    }
                }

                Section {
                    LabeledContent(type.isRevolving ? "Planned monthly payment" : "Monthly payment") {
                        AmountField(title: "0", amount: $monthlyPayment).multilineTextAlignment(.trailing)
                    }
                    if let suggestedPayment {
                        Button {
                            monthlyPayment = suggestedPayment
                        } label: {
                            HStack {
                                Text("Use calculated payment")
                                Spacer()
                                MoneyText(suggestedPayment)
                            }
                        }
                    }
                    Picker("Due on day", selection: $paymentDay) {
                        ForEach(1...28, id: \.self) { Text("\($0)").tag($0) }
                    }
                } header: {
                    Text("Payments")
                }

                Section("Notes") {
                    TextField("Optional", text: $notes, axis: .vertical).lineLimit(1...4)
                }
            }
            .navigationTitle(loan == nil ? "New Debt" : "Edit Debt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save", action: save).disabled(!isValid) }
            }
        }
    }

    private var placeholderName: String {
        switch type {
        case .homeMortgage: "Home Mortgage"
        case .carLoan: "Toyota Loan"
        case .creditCard: "Visa Card"
        case .studentLoan: "University Loan"
        default: type.title
        }
    }

    private func save() {
        let original = originalAmount ?? currentBalance ?? 0
        let balance = currentBalance ?? original
        let target: Loan
        if let loan {
            target = loan
        } else {
            target = Loan(name: "", type: type, originalAmount: original, currentBalance: balance, interestRate: 0, termMonths: 0, monthlyPayment: 0, startDate: startDate)
            modelContext.insert(target)
        }
        target.name = name.trimmingCharacters(in: .whitespaces)
        target.type = type
        target.originalAmount = max(original, balance)
        target.currentBalance = balance
        target.interestRate = interestRate ?? 0
        target.termMonths = type.isRevolving ? 0 : termMonths
        target.startDate = startDate
        target.monthlyPayment = monthlyPayment ?? suggestedPayment ?? 0
        target.paymentDayOfMonth = paymentDay
        target.creditLimit = type.isRevolving ? (creditLimit ?? 0) : 0
        target.lender = lender.trimmingCharacters(in: .whitespaces)
        target.accountNumber = accountNumber.trimmingCharacters(in: .whitespaces)
        target.notes = notes
        target.isClosed = balance == 0 && !type.isRevolving
        try? modelContext.save()
        dismiss()
    }
}
