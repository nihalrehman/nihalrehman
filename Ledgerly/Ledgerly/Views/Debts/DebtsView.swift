import Charts
import SwiftData
import SwiftUI

/// Overview of all debts: mortgages, car loans, credit cards, student loans...
struct DebtsView: View {
    @Query(sort: \Loan.createdAt) private var loans: [Loan]
    @State private var showingAdd = false
    @State private var strategy: LoanCalculator.Strategy = .avalanche

    private var openLoans: [Loan] { loans.filter { !$0.isClosed } }
    private var closedLoans: [Loan] { loans.filter { $0.isClosed } }
    private var totalDebt: Decimal { openLoans.sum(\.currentBalance) }
    private var totalMonthly: Decimal { openLoans.sum(\.monthlyPayment) }
    private var totalOriginal: Decimal { openLoans.sum(\.originalAmount) }

    private var debtFreeDate: Date? {
        let summaries = openLoans.map(\.payoff)
        guard !summaries.isEmpty, summaries.allSatisfy({ !$0.neverPaysOff }) else { return nil }
        return summaries.compactMap(\.payoffDate).max()
    }

    var body: some View {
        NavigationStack {
            List {
                if !loans.isEmpty {
                    Section { summary }

                    if !openLoans.isEmpty {
                        Section {
                            Chart(openLoans) { loan in
                                BarMark(x: .value("Balance", loan.currentBalance.doubleValue), y: .value("Debt", loan.name))
                                    .foregroundStyle(loan.color.gradient)
                                    .cornerRadius(4)
                            }
                            .chartXAxis(.hidden)
                            .frame(height: CGFloat(openLoans.count) * 36 + 20)
                        } header: {
                            Text("Balances")
                        }

                        Section {
                            ForEach(openLoans) { loan in
                                NavigationLink { LoanDetailView(loan: loan) } label: { LoanRow(loan: loan) }
                            }
                        } header: {
                            Text("Active Debts")
                        }

                        if openLoans.count > 1 {
                            Section {
                                Picker("Strategy", selection: $strategy) {
                                    ForEach(LoanCalculator.Strategy.allCases) { Text($0.title).tag($0) }
                                }
                                .pickerStyle(.segmented)
                                Text(strategy.explanation).font(.caption).foregroundStyle(.secondary)
                                ForEach(Array(LoanCalculator.order(openLoans, by: strategy).enumerated()), id: \.element.id) { index, loan in
                                    HStack {
                                        Text("\(index + 1)")
                                            .font(.caption.bold())
                                            .frame(width: 22, height: 22)
                                            .background(Circle().fill(index == 0 ? Color.accentColor : Color(.tertiarySystemFill)))
                                            .foregroundStyle(index == 0 ? .white : .primary)
                                        Text(loan.name)
                                        Spacer()
                                        Text("\(loan.interestRate.formatted(.number.precision(.fractionLength(0...2))))%")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        MoneyText(loan.currentBalance).font(.caption)
                                    }
                                }
                            } header: {
                                Text("Payoff Plan")
                            }
                        }
                    }

                    if !closedLoans.isEmpty {
                        Section("Paid Off 🎉") {
                            ForEach(closedLoans) { loan in
                                NavigationLink { LoanDetailView(loan: loan) } label: { LoanRow(loan: loan) }
                            }
                        }
                    }
                }
            }
            .overlay {
                if loans.isEmpty {
                    ContentUnavailableView {
                        Label("No Debts Tracked", systemImage: "creditcard")
                    } description: {
                        Text("Add your mortgage, car loan, credit cards or other loans to see payoff dates, interest costs and a plan to become debt-free.")
                    } actions: {
                        Button("Add a Debt") { showingAdd = true }.buttonStyle(.borderedProminent)
                    }
                }
            }
            .navigationTitle("Debts")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showingAdd = true } label: { Image(systemName: "plus.circle.fill").font(.title3) }
                }
            }
            .sheet(isPresented: $showingAdd) { LoanFormView() }
        }
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Total Owed").font(.caption).foregroundStyle(.secondary)
            MoneyText(totalDebt).font(.system(.largeTitle, design: .rounded).weight(.bold))
            if totalOriginal > 0 {
                let progress = max(0, min(1, 1 - totalDebt.doubleValue / totalOriginal.doubleValue))
                ProgressBar(value: progress, tint: .green)
                Text("\(progress.formatted(.percent.precision(.fractionLength(0)))) of original balances repaid")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            HStack {
                VStack(alignment: .leading) {
                    Text("Monthly Payments").font(.caption).foregroundStyle(.secondary)
                    MoneyText(totalMonthly).font(.headline)
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text("Debt-Free").font(.caption).foregroundStyle(.secondary)
                    Text(debtFreeDate?.formatted(.dateTime.month(.abbreviated).year()) ?? "—").font(.headline)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct LoanRow: View {
    let loan: Loan

    var body: some View {
        HStack(spacing: 12) {
            CategoryIcon(icon: loan.type.icon, color: loan.color)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(loan.name).font(.body.weight(.medium))
                    Spacer()
                    MoneyText(loan.currentBalance).font(.body.weight(.semibold))
                }
                if let utilization = loan.utilization {
                    ProgressBar(value: utilization, tint: utilization > 0.3 ? .orange : .green, height: 5)
                    Text("\(utilization.formatted(.percent.precision(.fractionLength(0)))) of limit used · \(loan.interestRate.formatted(.number.precision(.fractionLength(0...2))))% APR")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ProgressBar(value: loan.progress, tint: loan.color, height: 5)
                    Text("\(loan.type.title) · \(loan.interestRate.formatted(.number.precision(.fractionLength(0...2))))% · \(loan.progress.formatted(.percent.precision(.fractionLength(0)))) paid")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }
}
