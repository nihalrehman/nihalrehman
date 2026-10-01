import SwiftData
import SwiftUI

struct BudgetsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var budgets: [Budget]
    @Query(sort: \TransactionRecord.date, order: .reverse) private var transactions: [TransactionRecord]

    @State private var month = Date().startOfMonth
    @State private var showingAdd = false
    @State private var editing: Budget?

    private var statuses: [BudgetStatus] {
        budgets.map { BudgetStatus(budget: $0, spent: $0.spent(in: month, from: transactions)) }
            .sorted { lhs, rhs in
                if lhs.budget.isOverall != rhs.budget.isOverall { return lhs.budget.isOverall }
                return lhs.budget.title < rhs.budget.title
            }
    }

    private var categoryStatuses: [BudgetStatus] { statuses.filter { !$0.budget.isOverall } }
    private var overall: BudgetStatus? { statuses.first { $0.budget.isOverall } }

    /// Days left in the selected month (including today), for "per day" guidance.
    private var daysLeft: Int {
        guard month.startOfMonth == Date().startOfMonth else { return 0 }
        let today = Calendar.current.component(.day, from: Date())
        return month.daysInMonth - today + 1
    }

    var body: some View {
        NavigationStack {
            List {
                Section { MonthSelector(month: $month) }

                if let overall {
                    Section("Overall") { budgetRow(overall) }
                } else if !budgets.isEmpty {
                    let totalLimit = categoryStatuses.sum(\.budget.limit)
                    let totalSpent = categoryStatuses.sum(\.spent)
                    Section("All Category Budgets") {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                MoneyText(totalSpent).font(.headline)
                                Text("of").foregroundStyle(.secondary)
                                MoneyText(totalLimit).foregroundStyle(.secondary)
                            }
                            ProgressBar(value: totalLimit > 0 ? totalSpent.doubleValue / totalLimit.doubleValue : 0, tint: .accentColor)
                        }
                        .padding(.vertical, 4)
                    }
                }

                if !categoryStatuses.isEmpty {
                    Section("Categories") {
                        ForEach(categoryStatuses, id: \.budget.id) { status in
                            budgetRow(status)
                        }
                    }
                }
            }
            .overlay {
                if budgets.isEmpty {
                    ContentUnavailableView {
                        Label("No Budgets", systemImage: "gauge.with.dots.needle.33percent")
                    } description: {
                        Text("Set monthly limits for groceries, eating out, fuel or anything else, and get warned before you overspend.")
                    } actions: {
                        Button("Create a Budget") { showingAdd = true }
                            .buttonStyle(.borderedProminent)
                    }
                }
            }
            .navigationTitle("Budgets")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showingAdd = true } label: { Image(systemName: "plus.circle.fill").font(.title3) }
                }
            }
            .sheet(isPresented: $showingAdd) { BudgetFormView() }
            .sheet(item: $editing) { BudgetFormView(budget: $0) }
        }
    }

    private func budgetRow(_ status: BudgetStatus) -> some View {
        Button { editing = status.budget } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    if let category = status.budget.category {
                        CategoryIcon(icon: category.icon, color: category.color, size: 30)
                    } else {
                        CategoryIcon(icon: "chart.pie.fill", color: .accentColor, size: 30)
                    }
                    Text(status.budget.title).font(.body.weight(.medium)).foregroundStyle(.primary)
                    Spacer()
                    if status.progress >= 1 {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.red)
                    } else if status.progress >= status.budget.alertThreshold {
                        Image(systemName: "exclamationmark.circle.fill").foregroundStyle(.orange)
                    }
                }
                ProgressBar(value: status.progress, tint: status.color)
                HStack {
                    MoneyText(status.spent).font(.caption.weight(.semibold)).foregroundStyle(.primary)
                    Text("of").font(.caption).foregroundStyle(.secondary)
                    MoneyText(status.budget.limit).font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    if status.remaining >= 0 {
                        HStack(spacing: 3) {
                            MoneyText(status.remaining)
                            Text(daysLeft > 0 ? "left · " : "left")
                            if daysLeft > 0 {
                                MoneyText((status.remaining / Decimal(daysLeft)).rounded(2))
                                Text("/day")
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    } else {
                        HStack(spacing: 3) {
                            MoneyText(-status.remaining)
                            Text("over")
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.red)
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .swipeActions {
            Button(role: .destructive) {
                modelContext.delete(status.budget)
                try? modelContext.save()
            } label: { Label("Delete", systemImage: "trash") }
        }
    }
}

struct BudgetFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var budgets: [Budget]

    private let budget: Budget?
    @State private var category: LedgerCategory?
    @State private var isOverall: Bool
    @State private var limit: Decimal?
    @State private var threshold: Double

    init(budget: Budget? = nil) {
        self.budget = budget
        _category = State(initialValue: budget?.category)
        _isOverall = State(initialValue: budget.map { $0.isOverall } ?? false)
        _limit = State(initialValue: budget?.limit)
        _threshold = State(initialValue: budget?.alertThreshold ?? 0.8)
    }

    private var duplicate: Bool {
        budgets.contains { other in
            other.id != budget?.id && (isOverall ? other.isOverall : other.category?.id == category?.id && category != nil)
        }
    }

    private var isValid: Bool {
        guard let limit, limit > 0 else { return false }
        return (isOverall || category != nil) && !duplicate
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Budget for all spending", isOn: $isOverall)
                    if !isOverall {
                        NavigationLink {
                            CategoryPickerView(kind: .expense, selection: $category)
                        } label: {
                            LabeledContent("Category") {
                                if let category {
                                    Label(category.fullName, systemImage: category.icon).foregroundStyle(category.color)
                                } else {
                                    Text("Choose").foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                } footer: {
                    if duplicate {
                        Text("A budget for this already exists.").foregroundStyle(.red)
                    } else {
                        Text("Choosing a group (e.g. Food & Dining) includes all of its subcategories.")
                    }
                }

                Section("Monthly Limit") {
                    AmountField(title: "Amount", amount: $limit, large: true)
                }

                Section {
                    VStack(alignment: .leading) {
                        Text("Warn me at \(threshold.formatted(.percent.precision(.fractionLength(0)))) of the limit")
                        Slider(value: $threshold, in: 0.5...1, step: 0.05)
                    }
                }

                if let budget {
                    Section {
                        Button("Delete Budget", role: .destructive) {
                            modelContext.delete(budget)
                            try? modelContext.save()
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(budget == nil ? "New Budget" : "Edit Budget")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save", action: save).disabled(!isValid) }
            }
        }
    }

    private func save() {
        guard let limit else { return }
        let target: Budget
        if let budget {
            target = budget
            target.limit = limit
            target.alertThreshold = threshold
        } else {
            target = Budget(limit: limit, alertThreshold: threshold)
            modelContext.insert(target)
        }
        target.category = isOverall ? nil : category
        try? modelContext.save()
        dismiss()
    }
}
