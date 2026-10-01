import Charts
import SwiftData
import SwiftUI

struct LoanDetailView: View {
    let loan: Loan

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var showingPayment = false
    @State private var showingEdit = false
    @State private var showingAdjust = false
    @State private var confirmDelete = false
    @State private var extraPayment: Double = 0

    private var baseline: PayoffSummary { loan.payoff }

    private var withExtra: PayoffSummary {
        LoanCalculator.payoffSummary(balance: loan.currentBalance, annualRatePercent: loan.interestRate, payment: loan.monthlyPayment, extraPayment: Decimal(extraPayment), startDate: loan.nextPaymentDate)
    }

    private var extraRange: ClosedRange<Double> {
        let upper = max(loan.monthlyPayment.doubleValue * 2, 100)
        return 0...upper.rounded()
    }

    var body: some View {
        List {
            Section { header }

            Section("Details") {
                LabeledContent("Type", value: loan.type.title)
                if !loan.lender.isEmpty { LabeledContent("Lender", value: loan.lender) }
                SecureRevealRow(title: "Account Number", value: loan.accountNumber)
                LabeledContent("Interest Rate", value: "\(loan.interestRate.formatted(.number.precision(.fractionLength(0...3))))% APR")
                LabeledContent("Monthly Payment") { MoneyText(loan.monthlyPayment) }
                LabeledContent("Monthly Interest Now") {
                    MoneyText(LoanCalculator.monthlyInterest(balance: loan.currentBalance, annualRatePercent: loan.interestRate))
                }
                if !loan.isClosed {
                    LabeledContent("Next Due", value: loan.nextPaymentDate.formatted(date: .abbreviated, time: .omitted))
                }
                if loan.termMonths > 0 {
                    LabeledContent("Term", value: "\(loan.termMonths / 12)y \(loan.termMonths % 12)m from \(loan.startDate.formatted(.dateTime.month(.abbreviated).year()))")
                }
                if loan.type.isRevolving && loan.creditLimit > 0 {
                    LabeledContent("Credit Limit") { MoneyText(loan.creditLimit) }
                    LabeledContent("Available Credit") { MoneyText(max(loan.creditLimit - loan.currentBalance, 0)) }
                }
                if !loan.notes.isEmpty {
                    Text(loan.notes).font(.callout).foregroundStyle(.secondary)
                }
            }

            if !loan.isClosed && loan.currentBalance > 0 {
                Section {
                    projection
                } header: {
                    Text("Payoff Projection")
                }

                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Extra each month")
                            Spacer()
                            MoneyText(Decimal(extraPayment)).font(.headline)
                        }
                        Slider(value: $extraPayment, in: extraRange, step: 10)
                        if extraPayment > 0, let baseMonths = baseline.months, let newMonths = withExtra.months {
                            Text("Pay off \(baseMonths - newMonths) months sooner and save \((baseline.totalInterest - withExtra.totalInterest).currencyString()) in interest.")
                                .font(.callout)
                                .foregroundStyle(.green)
                        }
                    }
                } header: {
                    Text("What If I Pay More?")
                }

                Section {
                    NavigationLink("Amortization Schedule") {
                        AmortizationView(loan: loan, extraPayment: Decimal(extraPayment))
                    }
                }
            }

            Section("Payment History") {
                if loan.sortedPayments.isEmpty {
                    Text("No payments recorded yet.").foregroundStyle(.secondary)
                }
                ForEach(loan.sortedPayments) { payment in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(payment.date.formatted(date: .abbreviated, time: .omitted))
                            HStack(spacing: 4) {
                                Text("Principal")
                                MoneyText(payment.principalPortion)
                                Text("· Interest")
                                MoneyText(payment.interestPortion)
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing) {
                            MoneyText(payment.amount).font(.body.weight(.semibold))
                            if payment.isExtra { Text("Extra").font(.caption2).foregroundStyle(.green) }
                        }
                    }
                }
                .onDelete(perform: deletePayments)
            }

            Section {
                Button("Delete Debt", role: .destructive) { confirmDelete = true }
            }
        }
        .navigationTitle(loan.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button { showingPayment = true } label: { Label("Record Payment", systemImage: "checkmark.circle") }
                    Button { showingAdjust = true } label: { Label(loan.type.isRevolving ? "Update Balance / Add Charges" : "Adjust Balance", systemImage: "slider.horizontal.3") }
                    Button { showingEdit = true } label: { Label("Edit", systemImage: "pencil") }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if !loan.isClosed {
                Button { showingPayment = true } label: {
                    Label("Record Payment", systemImage: "checkmark.circle.fill").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding()
                .background(.bar)
            }
        }
        .sheet(isPresented: $showingPayment) { RecordPaymentView(loan: loan) }
        .sheet(isPresented: $showingEdit) { LoanFormView(loan: loan) }
        .sheet(isPresented: $showingAdjust) { AdjustBalanceView(loan: loan) }
        .confirmationDialog("Delete \(loan.name)?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete Debt and Payment History", role: .destructive) {
                // Leave the screen first so nothing renders a deleted model.
                let context = modelContext
                let target = loan
                dismiss()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    context.delete(target)
                    try? context.save()
                }
            }
        } message: {
            Text("Expenses already logged for past payments are kept.")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                CategoryIcon(icon: loan.type.icon, color: loan.color, size: 44)
                VStack(alignment: .leading) {
                    Text("Remaining Balance").font(.caption).foregroundStyle(.secondary)
                    MoneyText(loan.currentBalance).font(.system(.title, design: .rounded).weight(.bold))
                }
            }
            if let utilization = loan.utilization {
                ProgressBar(value: utilization, tint: utilization > 0.3 ? .orange : .green)
                Text("\(utilization.formatted(.percent.precision(.fractionLength(0)))) credit utilization (keep under 30% for a healthy credit score)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ProgressBar(value: loan.progress, tint: loan.color)
                HStack {
                    Text("\(loan.progress.formatted(.percent.precision(.fractionLength(0)))) paid off")
                    Spacer()
                    Text("of ")
                    MoneyText(loan.originalAmount)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var projection: some View {
        if loan.monthlyPayment <= 0 {
            Text("Add a monthly payment to see when this debt will be paid off.")
                .foregroundStyle(.secondary)
        } else if baseline.neverPaysOff {
            Label("Your monthly payment doesn't cover the interest. The balance will never go down — increase the payment.", systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
        } else {
            let summary = extraPayment > 0 ? withExtra : baseline
            LabeledContent("Debt-free by", value: summary.payoffDate?.formatted(.dateTime.month(.wide).year()) ?? "—")
            LabeledContent("Payments left", value: "\(summary.months ?? 0)")
            LabeledContent("Interest still to pay") { MoneyText(summary.totalInterest) }
            LabeledContent("Total still to pay") { MoneyText(summary.totalPaid) }
            balanceChart
        }
    }

    private var balanceChart: some View {
        let base = LoanCalculator.schedule(balance: loan.currentBalance, annualRatePercent: loan.interestRate, payment: loan.monthlyPayment, startDate: loan.nextPaymentDate)
        let extra = extraPayment > 0 ? LoanCalculator.schedule(balance: loan.currentBalance, annualRatePercent: loan.interestRate, payment: loan.monthlyPayment, extraPayment: Decimal(extraPayment), startDate: loan.nextPaymentDate) : []
        return Chart {
            ForEach(base) { row in
                LineMark(x: .value("Date", row.date), y: .value("Balance", row.balance.doubleValue), series: .value("Plan", "Current"))
                    .foregroundStyle(loan.color)
            }
            ForEach(extra) { row in
                LineMark(x: .value("Date", row.date), y: .value("Balance", row.balance.doubleValue), series: .value("Plan", "With extra"))
                    .foregroundStyle(.green)
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 3]))
            }
        }
        .chartYAxis(.hidden)
        .frame(height: 160)
        .padding(.vertical, 6)
    }

    private func deletePayments(_ offsets: IndexSet) {
        let payments = loan.sortedPayments
        for index in offsets {
            let payment = payments[index]
            // Reverse the principal reduction so the balance stays correct.
            loan.currentBalance += payment.principalPortion
            if loan.currentBalance > 0 { loan.isClosed = false }
            modelContext.delete(payment)
        }
        try? modelContext.save()
    }
}

struct AmortizationView: View {
    let loan: Loan
    let extraPayment: Decimal

    private var rows: [AmortizationRow] {
        LoanCalculator.schedule(balance: loan.currentBalance, annualRatePercent: loan.interestRate, payment: loan.monthlyPayment, extraPayment: extraPayment, startDate: loan.nextPaymentDate)
    }

    var body: some View {
        List {
            Section {
                HStack {
                    Text("#").frame(width: 34, alignment: .leading)
                    Text("Date").frame(maxWidth: .infinity, alignment: .leading)
                    Text("Principal").frame(maxWidth: .infinity, alignment: .trailing)
                    Text("Interest").frame(maxWidth: .infinity, alignment: .trailing)
                    Text("Balance").frame(maxWidth: .infinity, alignment: .trailing)
                }
                .font(.caption.bold())
                .foregroundStyle(.secondary)

                ForEach(rows) { row in
                    HStack {
                        Text("\(row.id)").frame(width: 34, alignment: .leading).foregroundStyle(.secondary)
                        Text(row.date.formatted(.dateTime.month(.abbreviated).year(.twoDigits))).frame(maxWidth: .infinity, alignment: .leading)
                        MoneyText(row.principal).frame(maxWidth: .infinity, alignment: .trailing)
                        MoneyText(row.interest).frame(maxWidth: .infinity, alignment: .trailing).foregroundStyle(.orange)
                        MoneyText(row.balance).frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .font(.caption)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                }
            } footer: {
                Text("Estimates assume a fixed rate and on-time payments. Interest is calculated monthly on the remaining balance.")
            }
        }
        .listStyle(.plain)
        .navigationTitle("Schedule")
        .navigationBarTitleDisplayMode(.inline)
    }
}
