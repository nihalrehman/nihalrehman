import SwiftData
import SwiftUI

struct TransactionsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TransactionRecord.date, order: .reverse) private var transactions: [TransactionRecord]
    @Query(sort: \Account.sortOrder) private var accounts: [Account]

    @State private var search = ""
    @State private var kindFilter: TransactionKind?
    @State private var accountFilter: Account?
    @State private var categoryFilter: LedgerCategory?
    @State private var month: Date? = Date().startOfMonth
    @State private var showingAdd = false
    @State private var editing: TransactionRecord?
    @State private var showingCategoryFilter = false

    private var filtered: [TransactionRecord] {
        let range = month?.monthRange
        return transactions.filter { t in
            if let range, !range.contains(t.date) { return false }
            if let kindFilter, t.kind != kindFilter { return false }
            if let accountFilter, t.account?.id != accountFilter.id && t.transferAccount?.id != accountFilter.id { return false }
            if let categoryFilter, !categoryFilter.encompasses(t.category) { return false }
            if !search.isEmpty {
                let haystack = [t.payee, t.notes, t.category?.fullName ?? "", t.account?.name ?? ""].joined(separator: " ")
                if !haystack.localizedCaseInsensitiveContains(search) { return false }
            }
            return true
        }
    }

    private struct DayGroup: Identifiable {
        var id: Date { day }
        let day: Date
        let items: [TransactionRecord]
    }

    private var groupedByDay: [DayGroup] {
        Dictionary(grouping: filtered) { $0.date.startOfDay }
            .map { DayGroup(day: $0.key, items: $0.value.sorted { $0.date > $1.date }) }
            .sorted { $0.day > $1.day }
    }

    private var isFiltering: Bool {
        kindFilter != nil || accountFilter != nil || categoryFilter != nil
    }

    var body: some View {
        NavigationStack {
            List {
                summarySection

                ForEach(groupedByDay) { group in
                    Section {
                        ForEach(group.items) { tx in
                            Button { editing = tx } label: { TransactionRow(transaction: tx) }
                                .tint(.primary)
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        modelContext.delete(tx)
                                        try? modelContext.save()
                                    } label: { Label("Delete", systemImage: "trash") }
                                }
                                .swipeActions(edge: .leading) {
                                    Button { duplicate(tx) } label: { Label("Duplicate", systemImage: "plus.square.on.square") }
                                        .tint(.indigo)
                                }
                        }
                    } header: {
                        HStack {
                            Text(group.day.formatted(.dateTime.weekday(.wide).day().month(.abbreviated)))
                            Spacer()
                            MoneyText(group.items.sum(\.signedAmount))
                        }
                    }
                }
            }
            .overlay {
                if filtered.isEmpty {
                    if search.isEmpty {
                        ContentUnavailableView("No Transactions", systemImage: "list.bullet.rectangle", description: Text("Tap + to log an expense or income."))
                    } else {
                        ContentUnavailableView.search(text: search)
                    }
                }
            }
            .searchable(text: $search, prompt: "Payee, note, category")
            .navigationTitle("Transactions")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { filterMenu }
                ToolbarItem(placement: .primaryAction) {
                    Button { showingAdd = true } label: { Image(systemName: "plus.circle.fill").font(.title3) }
                }
            }
            .sheet(isPresented: $showingAdd) { TransactionFormView() }
            .sheet(item: $editing) { TransactionFormView(transaction: $0) }
            .sheet(isPresented: $showingCategoryFilter) {
                NavigationStack {
                    CategoryPickerView(kind: kindFilter == .income ? .income : .expense, selection: $categoryFilter)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) { Button("Done") { showingCategoryFilter = false } }
                        }
                }
                .onChange(of: categoryFilter) { _, _ in showingCategoryFilter = false }
            }
        }
    }

    @ViewBuilder
    private var summarySection: some View {
        Section {
            HStack {
                Button { month = month?.adding(months: -1) ?? Date().startOfMonth } label: { Image(systemName: "chevron.left") }
                Spacer()
                Menu {
                    Button("This Month") { month = Date().startOfMonth }
                    Button("All Time") { month = nil }
                } label: {
                    Text(month?.monthTitle ?? "All Time").font(.headline)
                }
                Spacer()
                Button { month = month?.adding(months: 1) } label: { Image(systemName: "chevron.right") }
                    .disabled(month == nil || month! >= Date().startOfMonth)
            }
            .buttonStyle(.borderless)

            HStack {
                stat("In", FinanceMath.total(filtered, kind: .income), .green)
                Divider()
                stat("Out", FinanceMath.total(filtered, kind: .expense), .red)
                Divider()
                stat("Net", filtered.sum(\.signedAmount), .primary)
            }
            .frame(maxWidth: .infinity)

            if isFiltering {
                HStack {
                    Image(systemName: "line.3.horizontal.decrease.circle.fill").foregroundStyle(.tint)
                    Text(filterDescription).font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button("Clear") {
                        kindFilter = nil
                        accountFilter = nil
                        categoryFilter = nil
                    }
                    .font(.caption)
                    .buttonStyle(.borderless)
                }
            }
        }
    }

    private func stat(_ title: String, _ value: Decimal, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            MoneyText(value).font(.subheadline.weight(.semibold)).foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
    }

    private var filterDescription: String {
        [kindFilter?.title, accountFilter?.name, categoryFilter?.name].compactMap { $0 }.joined(separator: " · ")
    }

    private var filterMenu: some View {
        Menu {
            Picker("Type", selection: $kindFilter) {
                Text("All Types").tag(nil as TransactionKind?)
                ForEach(TransactionKind.allCases) { Text($0.title).tag($0 as TransactionKind?) }
            }
            Picker("Account", selection: $accountFilter) {
                Text("All Accounts").tag(nil as Account?)
                ForEach(accounts) { Text($0.name).tag($0 as Account?) }
            }
            Button {
                showingCategoryFilter = true
            } label: {
                Label(categoryFilter?.name ?? "Filter by Category", systemImage: "tag")
            }
            if isFiltering {
                Button("Clear Filters", role: .destructive) {
                    kindFilter = nil
                    accountFilter = nil
                    categoryFilter = nil
                }
            }
        } label: {
            Image(systemName: isFiltering ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
        }
    }

    private func duplicate(_ tx: TransactionRecord) {
        let copy = TransactionRecord(amount: tx.amount, kind: tx.kind, date: Date())
        modelContext.insert(copy)
        copy.category = tx.category
        copy.account = tx.account
        copy.transferAccount = tx.transferAccount
        copy.payee = tx.payee
        copy.notes = tx.notes
        try? modelContext.save()
    }
}
