import Charts
import SwiftData
import SwiftUI

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TransactionRecord.date, order: .reverse) private var transactions: [TransactionRecord]
    @Query(sort: \Account.sortOrder) private var accounts: [Account]
    @Query private var loans: [Loan]
    @Query private var budgets: [Budget]
    @Query(filter: #Predicate<RecurringRule> { $0.isActive == true }, sort: \RecurringRule.nextDueDate) private var rules: [RecurringRule]
    @Query private var goals: [SavingsGoal]
    @Query private var profiles: [UserProfile]

    @AppStorage(SettingsKey.hideAmounts) private var hideAmounts = false
    @State private var month = Date().startOfMonth
    @State private var addKind: TransactionKind?
    @State private var editing: TransactionRecord?

    private var monthTransactions: [TransactionRecord] {
        FinanceMath.transactions(transactions, in: month.monthRange)
    }

    private var income: Decimal { FinanceMath.total(monthTransactions, kind: .income) }
    private var expenses: Decimal { FinanceMath.total(monthTransactions, kind: .expense) }

    private var assets: Decimal {
        accounts.filter { $0.includeInNetWorth && !$0.isArchived }.sum(\.balance)
    }

    private var debt: Decimal {
        loans.filter { !$0.isClosed }.sum(\.currentBalance)
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let base = hour < 12 ? "Good morning" : hour < 18 ? "Good afternoon" : "Good evening"
        if let name = profiles.first?.firstName, !name.isEmpty { return "\(base), \(name)" }
        return base
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    MonthSelector(month: $month)
                    cashFlowCard
                    quickAddRow
                    netWorthCard
                    spendingCard
                    dailyCard
                    budgetsCard
                    upcomingCard
                    goalsCard
                    recentCard
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(greeting)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { hideAmounts.toggle() } label: {
                        Image(systemName: hideAmounts ? "eye.slash" : "eye")
                    }
                    .accessibilityLabel(hideAmounts ? "Show amounts" : "Hide amounts")
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { addKind = .expense } label: { Image(systemName: "plus.circle.fill").font(.title3) }
                }
            }
            .sheet(item: $addKind) { TransactionFormView(defaultKind: $0) }
            .sheet(item: $editing) { TransactionFormView(transaction: $0) }
        }
    }

    // MARK: - Cards

    private var cashFlowCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Cash Flow").font(.headline)
            HStack(alignment: .top) {
                metric("Income", income, color: .green, icon: "arrow.down.left")
                metric("Spent", expenses, color: .red, icon: "arrow.up.right")
                metric("Left", income - expenses, color: income >= expenses ? .blue : .orange, icon: "equal")
            }
            if let rate = FinanceMath.savingsRate(income: income, expenses: expenses) {
                Text(rate >= 0 ? "You kept \(rate.formatted(.percent.precision(.fractionLength(0)))) of your income." : "You spent \((-rate).formatted(.percent.precision(.fractionLength(0)))) more than you earned.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .card()
    }

    private func metric(_ title: String, _ value: Decimal, color: Color, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: icon)
                .font(.caption.weight(.medium))
                .foregroundStyle(color)
            MoneyText(value)
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var quickAddRow: some View {
        HStack(spacing: 12) {
            quickButton("Expense", "minus.circle.fill", .red) { addKind = .expense }
            quickButton("Income", "plus.circle.fill", .green) { addKind = .income }
            quickButton("Transfer", "arrow.left.arrow.right.circle.fill", .blue) { addKind = .transfer }
        }
    }

    private func quickButton(_ title: String, _ icon: String, _ color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon).font(.title2).foregroundStyle(color)
                Text(title).font(.caption.weight(.medium)).foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var netWorthCard: some View {
        NavigationLink {
            AccountsView()
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Net Worth").font(.headline)
                    Spacer()
                    Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                }
                MoneyText(assets - debt, colored: true)
                    .font(.system(.title, design: .rounded).weight(.bold))
                HStack {
                    VStack(alignment: .leading) {
                        Text("Accounts").font(.caption).foregroundStyle(.secondary)
                        MoneyText(assets).font(.subheadline.weight(.semibold))
                    }
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text("Debts").font(.caption).foregroundStyle(.secondary)
                        MoneyText(debt).font(.subheadline.weight(.semibold)).foregroundStyle(.red)
                    }
                }
            }
            .card()
        }
        .buttonStyle(.plain)
    }

    private var spendingCard: some View {
        let breakdown = FinanceMath.expensesByGroup(monthTransactions)
        return VStack(alignment: .leading, spacing: 12) {
            Text("Where Your Money Went").font(.headline)
            if breakdown.isEmpty {
                Text("No expenses logged this month yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 80)
            } else {
                HStack(alignment: .center, spacing: 16) {
                    Chart(breakdown) { item in
                        SectorMark(angle: .value("Amount", item.amount.doubleValue), innerRadius: .ratio(0.62), angularInset: 1.5)
                            .cornerRadius(3)
                            .foregroundStyle(item.color)
                    }
                    .frame(width: 140, height: 140)
                    .overlay {
                        VStack(spacing: 0) {
                            Text("Total").font(.caption2).foregroundStyle(.secondary)
                            MoneyText(expenses).font(.caption.weight(.bold)).minimumScaleFactor(0.5).lineLimit(1)
                        }
                        .frame(width: 80)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(breakdown.prefix(6)) { item in
                            HStack(spacing: 6) {
                                Circle().fill(item.color).frame(width: 8, height: 8)
                                Text(item.name).font(.caption).lineLimit(1)
                                Spacer(minLength: 4)
                                Text(share(item.amount)).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .card()
    }

    private func share(_ amount: Decimal) -> String {
        guard expenses > 0 else { return "" }
        return (amount.doubleValue / expenses.doubleValue).formatted(.percent.precision(.fractionLength(0)))
    }

    private var dailyCard: some View {
        let daily = FinanceMath.dailyExpenses(transactions, month: month)
        let elapsedDays = month.startOfMonth == Date().startOfMonth ? Calendar.current.component(.day, from: Date()) : month.daysInMonth
        let average = elapsedDays > 0 ? expenses / Decimal(elapsedDays) : 0
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Daily Spending").font(.headline)
                Spacer()
                HStack(spacing: 4) {
                    Text("Avg").font(.caption).foregroundStyle(.secondary)
                    MoneyText(average.rounded(2)).font(.caption.weight(.semibold))
                }
            }
            Chart {
                ForEach(daily) { entry in
                    BarMark(x: .value("Day", entry.day, unit: .day), y: .value("Spent", entry.amount.doubleValue))
                        .foregroundStyle(Color.accentColor.gradient)
                        .cornerRadius(2)
                }
                if average > 0 {
                    RuleMark(y: .value("Average", average.doubleValue))
                        .foregroundStyle(.orange)
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                }
            }
            .chartYAxis(hideAmounts ? .hidden : .automatic)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                    AxisValueLabel(format: .dateTime.day())
                }
            }
            .frame(height: 140)
        }
        .card()
    }

    @ViewBuilder
    private var budgetsCard: some View {
        if !budgets.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Budgets").font(.headline)
                ForEach(budgetStatuses.prefix(4), id: \.budget.id) { status in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(status.budget.title).font(.subheadline).lineLimit(1)
                            Spacer()
                            MoneyText(status.spent).font(.caption.weight(.semibold))
                            Text("/").font(.caption).foregroundStyle(.secondary)
                            MoneyText(status.budget.limit).font(.caption).foregroundStyle(.secondary)
                        }
                        ProgressBar(value: status.progress, tint: status.color, height: 6)
                    }
                }
            }
            .card()
        }
    }

    private var budgetStatuses: [BudgetStatus] {
        budgets.map { BudgetStatus(budget: $0, spent: $0.spent(in: month, from: transactions)) }
            .sorted { $0.progress > $1.progress }
    }

    @ViewBuilder
    private var upcomingCard: some View {
        let horizon = Date().adding(days: 30)
        let upcoming = rules.filter { $0.kind == .expense && $0.nextDueDate <= horizon }.prefix(5)
        if !upcoming.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Upcoming Bills").font(.headline)
                ForEach(Array(upcoming)) { rule in
                    HStack(spacing: 12) {
                        CategoryIcon(icon: rule.category?.icon ?? "calendar", color: rule.category?.color ?? .gray, size: 30)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(rule.name).font(.subheadline).lineLimit(1)
                            Text(dueText(rule.nextDueDate))
                                .font(.caption)
                                .foregroundStyle(rule.nextDueDate < Date().startOfDay ? .red : .secondary)
                        }
                        Spacer()
                        MoneyText(rule.amount).font(.subheadline.weight(.semibold))
                        if !rule.autoPost {
                            Button {
                                RecurrenceEngine.markPaid(rule, in: modelContext)
                            } label: {
                                Image(systemName: "checkmark.circle").font(.title3)
                            }
                            .buttonStyle(.borderless)
                            .accessibilityLabel("Mark as paid")
                        }
                    }
                }
            }
            .card()
        }
    }

    private func dueText(_ date: Date) -> String {
        let days = Calendar.current.dateComponents([.day], from: Date().startOfDay, to: date.startOfDay).day ?? 0
        switch days {
        case ..<0: return "Overdue by \(-days) day\(days == -1 ? "" : "s")"
        case 0: return "Due today"
        case 1: return "Due tomorrow"
        default: return "Due in \(days) days · \(date.formatted(.dateTime.day().month(.abbreviated)))"
        }
    }

    @ViewBuilder
    private var goalsCard: some View {
        let active = goals.filter { !$0.isComplete }.prefix(3)
        if !active.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Savings Goals").font(.headline)
                ForEach(Array(active)) { goal in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Label(goal.name, systemImage: goal.icon).font(.subheadline).foregroundStyle(goal.color)
                            Spacer()
                            Text(goal.progress.formatted(.percent.precision(.fractionLength(0))))
                                .font(.caption.weight(.semibold))
                        }
                        ProgressBar(value: goal.progress, tint: goal.color, height: 6)
                    }
                }
            }
            .card()
        }
    }

    private var recentCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recent").font(.headline)
            if transactions.isEmpty {
                Text("Your latest transactions will appear here.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(transactions.prefix(6)) { tx in
                    Button { editing = tx } label: { TransactionRow(transaction: tx) }
                        .buttonStyle(.plain)
                    if tx.id != transactions.prefix(6).last?.id { Divider() }
                }
            }
        }
        .card()
    }
}

struct BudgetStatus {
    let budget: Budget
    let spent: Decimal

    var progress: Double {
        guard budget.limit > 0 else { return 0 }
        return spent.doubleValue / budget.limit.doubleValue
    }

    var remaining: Decimal { budget.limit - spent }

    var color: Color {
        if progress >= 1 { return .red }
        if progress >= budget.alertThreshold { return .orange }
        return .green
    }
}
