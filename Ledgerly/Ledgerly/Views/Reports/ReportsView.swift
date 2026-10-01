import Charts
import SwiftData
import SwiftUI

struct ReportsView: View {
    enum Period: String, CaseIterable, Identifiable {
        case thisMonth, lastMonth, last3, last6, thisYear, last12
        var id: String { rawValue }

        var title: String {
            switch self {
            case .thisMonth: "This Month"
            case .lastMonth: "Last Month"
            case .last3: "Last 3 Months"
            case .last6: "Last 6 Months"
            case .thisYear: "This Year"
            case .last12: "Last 12 Months"
            }
        }

        var range: Range<Date> {
            let now = Date()
            let thisMonth = now.startOfMonth
            switch self {
            case .thisMonth: return thisMonth..<thisMonth.startOfNextMonth
            case .lastMonth: return thisMonth.adding(months: -1)..<thisMonth
            case .last3: return thisMonth.adding(months: -2)..<thisMonth.startOfNextMonth
            case .last6: return thisMonth.adding(months: -5)..<thisMonth.startOfNextMonth
            case .thisYear:
                let start = Calendar.current.dateInterval(of: .year, for: now)?.start ?? thisMonth
                return start..<thisMonth.startOfNextMonth
            case .last12: return thisMonth.adding(months: -11)..<thisMonth.startOfNextMonth
            }
        }

        var monthCount: Int {
            let comps = Calendar.current.dateComponents([.month], from: range.lowerBound, to: range.upperBound)
            return max(comps.month ?? 1, 1)
        }
    }

    @Query(sort: \TransactionRecord.date, order: .reverse) private var transactions: [TransactionRecord]
    @State private var period: Period = .last6
    @State private var showSubcategories = false

    private var periodTransactions: [TransactionRecord] {
        FinanceMath.transactions(transactions, in: period.range)
    }

    var body: some View {
        let txs = periodTransactions
        let income = FinanceMath.total(txs, kind: .income)
        let expenses = FinanceMath.total(txs, kind: .expense)
        let breakdown = showSubcategories ? FinanceMath.expensesBySubcategory(txs) : FinanceMath.expensesByGroup(txs)
        let monthly = FinanceMath.monthlyTotals(transactions, endingMonth: period.range.upperBound.adding(days: -1), count: period.monthCount)

        return List {
            Section {
                Picker("Period", selection: $period) {
                    ForEach(Period.allCases) { Text($0.title).tag($0) }
                }
            }

            Section("Summary") {
                LabeledContent("Income") { MoneyText(income).foregroundStyle(.green) }
                LabeledContent("Expenses") { MoneyText(expenses).foregroundStyle(.red) }
                LabeledContent("Net") { MoneyText(income - expenses, colored: true).bold() }
                if let rate = FinanceMath.savingsRate(income: income, expenses: expenses) {
                    LabeledContent("Savings rate", value: rate.formatted(.percent.precision(.fractionLength(0))))
                }
                LabeledContent("Avg. monthly spending") { MoneyText((expenses / Decimal(period.monthCount)).rounded(2)) }
                LabeledContent("Transactions", value: "\(txs.count)")
            }

            if period.monthCount > 1 {
                Section("Income vs Expenses") {
                    Chart {
                        ForEach(monthly) { m in
                            BarMark(x: .value("Month", m.month, unit: .month), y: .value("Amount", m.income.doubleValue))
                                .foregroundStyle(by: .value("Type", "Income"))
                                .position(by: .value("Type", "Income"))
                            BarMark(x: .value("Month", m.month, unit: .month), y: .value("Amount", m.expenses.doubleValue))
                                .foregroundStyle(by: .value("Type", "Expenses"))
                                .position(by: .value("Type", "Expenses"))
                        }
                    }
                    .chartForegroundStyleScale(["Income": Color.green, "Expenses": Color.red])
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .month)) { _ in
                            AxisValueLabel(format: .dateTime.month(.narrow))
                        }
                    }
                    .frame(height: 200)
                    .padding(.vertical, 6)
                }
            }

            Section {
                Toggle("Show subcategories", isOn: $showSubcategories)
                if breakdown.isEmpty {
                    Text("No expenses in this period.").foregroundStyle(.secondary)
                } else {
                    Chart(breakdown.prefix(8)) { item in
                        BarMark(x: .value("Amount", item.amount.doubleValue), y: .value("Category", item.name))
                            .foregroundStyle(item.color.gradient)
                            .cornerRadius(4)
                    }
                    .chartXAxis(.hidden)
                    .frame(height: CGFloat(min(breakdown.count, 8)) * 32 + 16)

                    ForEach(breakdown) { item in
                        HStack(spacing: 10) {
                            CategoryIcon(icon: item.icon, color: item.color, size: 28)
                            Text(item.name)
                            Spacer()
                            VStack(alignment: .trailing, spacing: 0) {
                                MoneyText(item.amount).font(.subheadline.weight(.semibold))
                                if expenses > 0 {
                                    Text((item.amount.doubleValue / expenses.doubleValue).formatted(.percent.precision(.fractionLength(1))))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            } header: {
                Text("Spending by Category")
            }

            let payees = FinanceMath.topPayees(txs)
            if !payees.isEmpty {
                Section("Top Merchants") {
                    ForEach(payees) { payee in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(payee.name)
                                Text("\(payee.count) transaction\(payee.count == 1 ? "" : "s")").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            MoneyText(payee.amount).font(.subheadline.weight(.semibold))
                        }
                    }
                }
            }

            let incomeSources = FinanceMath.incomeBySource(txs)
            if !incomeSources.isEmpty {
                Section("Income Sources") {
                    ForEach(incomeSources) { item in
                        HStack(spacing: 10) {
                            CategoryIcon(icon: item.icon, color: item.color, size: 28)
                            Text(item.name)
                            Spacer()
                            MoneyText(item.amount).font(.subheadline.weight(.semibold))
                        }
                    }
                }
            }
        }
        .navigationTitle("Reports")
    }
}
