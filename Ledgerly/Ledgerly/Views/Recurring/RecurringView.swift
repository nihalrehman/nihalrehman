import SwiftData
import SwiftUI

/// Bills, subscriptions and regular income (rent, salary, school fees, Netflix...).
struct RecurringView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \RecurringRule.nextDueDate) private var rules: [RecurringRule]
    @State private var showingAdd = false
    @State private var editing: RecurringRule?

    private var active: [RecurringRule] { rules.filter(\.isActive) }
    private var inactive: [RecurringRule] { rules.filter { !$0.isActive } }

    private var monthlyFixedCosts: Decimal {
        active.filter { $0.kind == .expense }.sum(\.monthlyEquivalent)
    }

    private var monthlyRecurringIncome: Decimal {
        active.filter { $0.kind == .income }.sum(\.monthlyEquivalent)
    }

    var body: some View {
        List {
            if !rules.isEmpty {
                Section {
                    LabeledContent("Fixed costs / month") { MoneyText(monthlyFixedCosts).bold() }
                    LabeledContent("Regular income / month") { MoneyText(monthlyRecurringIncome).foregroundStyle(.green) }
                }
            }

            if !active.isEmpty {
                Section("Upcoming") {
                    ForEach(active) { rule in
                        Button { editing = rule } label: { row(rule) }
                            .tint(.primary)
                            .swipeActions(edge: .leading) {
                                Button {
                                    RecurrenceEngine.markPaid(rule, in: modelContext)
                                    reschedule()
                                } label: { Label("Paid", systemImage: "checkmark") }
                                    .tint(.green)
                                Button {
                                    RecurrenceEngine.skip(rule, in: modelContext)
                                    reschedule()
                                } label: { Label("Skip", systemImage: "forward.end") }
                                    .tint(.orange)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    modelContext.delete(rule)
                                    try? modelContext.save()
                                    reschedule()
                                } label: { Label("Delete", systemImage: "trash") }
                            }
                    }
                }
            }

            if !inactive.isEmpty {
                Section("Ended") {
                    ForEach(inactive) { rule in
                        Button { editing = rule } label: { row(rule) }.tint(.primary)
                    }
                    .onDelete { offsets in
                        let items = inactive
                        for index in offsets { modelContext.delete(items[index]) }
                        try? modelContext.save()
                    }
                }
            }
        }
        .overlay {
            if rules.isEmpty {
                ContentUnavailableView {
                    Label("No Recurring Items", systemImage: "repeat.circle")
                } description: {
                    Text("Add rent, utilities, subscriptions, school fees or your salary. Ledgerly reminds you before bills are due and can log them automatically.")
                } actions: {
                    Button("Add Recurring Item") { showingAdd = true }.buttonStyle(.borderedProminent)
                }
            }
        }
        .navigationTitle("Bills & Recurring")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showingAdd = true } label: { Image(systemName: "plus.circle.fill") }
            }
        }
        .sheet(isPresented: $showingAdd, onDismiss: reschedule) { RecurringFormView() }
        .sheet(item: $editing, onDismiss: reschedule) { RecurringFormView(rule: $0) }
    }

    private func row(_ rule: RecurringRule) -> some View {
        HStack(spacing: 12) {
            CategoryIcon(icon: rule.category?.icon ?? "repeat", color: rule.category?.color ?? .gray)
            VStack(alignment: .leading, spacing: 2) {
                Text(rule.name).font(.body.weight(.medium))
                Text("\(rule.frequency.title) · \(rule.isActive ? "next " + rule.nextDueDate.formatted(date: .abbreviated, time: .omitted) : "ended")\(rule.autoPost ? " · auto" : "")")
                    .font(.caption)
                    .foregroundStyle(rule.isActive && rule.nextDueDate < Date().startOfDay ? .red : .secondary)
            }
            Spacer()
            MoneyText(rule.amount, kind: rule.kind, colored: true).font(.body.weight(.semibold))
        }
        .opacity(rule.isActive ? 1 : 0.5)
    }

    private func reschedule() {
        Task { await NotificationScheduler.reschedule(in: modelContext) }
    }
}

struct RecurringFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Account.sortOrder) private var accounts: [Account]
    @AppStorage(SettingsKey.billReminders) private var remindersEnabled = false

    private let rule: RecurringRule?
    @State private var name: String
    @State private var amount: Decimal?
    @State private var kind: TransactionKind
    @State private var frequency: RecurrenceFrequency
    @State private var startDate: Date
    @State private var hasEndDate: Bool
    @State private var endDate: Date
    @State private var category: LedgerCategory?
    @State private var account: Account?
    @State private var autoPost: Bool
    @State private var remindDaysBefore: Int
    @State private var notes: String

    init(rule: RecurringRule? = nil) {
        self.rule = rule
        _name = State(initialValue: rule?.name ?? "")
        _amount = State(initialValue: rule?.amount)
        _kind = State(initialValue: rule?.kind ?? .expense)
        _frequency = State(initialValue: rule?.frequency ?? .monthly)
        _startDate = State(initialValue: rule?.nextDueDate ?? Date())
        _hasEndDate = State(initialValue: rule?.endDate != nil)
        _endDate = State(initialValue: rule?.endDate ?? Date().adding(months: 12))
        _category = State(initialValue: rule?.category)
        _account = State(initialValue: rule?.account)
        _autoPost = State(initialValue: rule?.autoPost ?? false)
        _remindDaysBefore = State(initialValue: rule?.remindDaysBefore ?? 1)
        _notes = State(initialValue: rule?.notes ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Type", selection: $kind) {
                        Text("Bill / Expense").tag(TransactionKind.expense)
                        Text("Income").tag(TransactionKind.income)
                    }
                    .pickerStyle(.segmented)
                    TextField(kind == .expense ? "Name (e.g. Rent, DEWA, Netflix)" : "Name (e.g. Salary)", text: $name)
                    LabeledContent("Amount") { AmountField(title: "0", amount: $amount).multilineTextAlignment(.trailing) }
                    NavigationLink {
                        CategoryPickerView(kind: kind == .income ? .income : .expense, selection: $category)
                    } label: {
                        LabeledContent("Category") {
                            if let category {
                                Label(category.name, systemImage: category.icon).foregroundStyle(category.color)
                            } else {
                                Text("Choose").foregroundStyle(.secondary)
                            }
                        }
                    }
                    Picker("Account", selection: $account) {
                        Text("None").tag(nil as Account?)
                        ForEach(accounts.filter { !$0.isArchived }) { Text($0.name).tag($0 as Account?) }
                    }
                }

                Section("Schedule") {
                    Picker("Repeats", selection: $frequency) {
                        ForEach(RecurrenceFrequency.allCases) { Text($0.title).tag($0) }
                    }
                    DatePicker(rule == nil ? "First due date" : "Next due date", selection: $startDate, displayedComponents: .date)
                    Toggle("Ends", isOn: $hasEndDate)
                    if hasEndDate {
                        DatePicker("End date", selection: $endDate, in: startDate..., displayedComponents: .date)
                    }
                }

                Section {
                    Toggle("Log automatically when due", isOn: $autoPost)
                    if kind == .expense {
                        Picker("Remind me", selection: $remindDaysBefore) {
                            Text("Never").tag(-1)
                            Text("On the day").tag(0)
                            Text("1 day before").tag(1)
                            Text("2 days before").tag(2)
                            Text("3 days before").tag(3)
                            Text("1 week before").tag(7)
                        }
                    }
                } footer: {
                    if kind == .expense && remindDaysBefore >= 0 && !remindersEnabled {
                        Text("Turn on Bill Reminders in Settings to receive notifications.")
                    } else {
                        Text("Reminders never show bill names or amounts on your lock screen.")
                    }
                }

                Section("Notes") {
                    TextField("Optional", text: $notes, axis: .vertical)
                }
            }
            .navigationTitle(rule == nil ? "New Recurring" : "Edit Recurring")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || (amount ?? 0) <= 0)
                }
            }
            .onChange(of: kind) { _, newKind in
                if category?.kind != newKind.categoryKind { category = nil }
            }
        }
    }

    private func save() {
        guard let amount else { return }
        let target: RecurringRule
        if let rule {
            target = rule
            target.amount = amount
            target.kind = kind
        } else {
            target = RecurringRule(name: "", amount: amount, kind: kind, frequency: frequency, startDate: startDate)
            modelContext.insert(target)
        }
        let scheduleChanged = rule == nil || rule?.frequency != frequency || rule?.nextDueDate != startDate || rule?.endDate != (hasEndDate ? endDate : nil)
        target.name = name.trimmingCharacters(in: .whitespaces)
        target.frequency = frequency
        target.endDate = hasEndDate ? endDate : nil
        if scheduleChanged { target.resetSchedule(from: startDate) }
        target.category = category
        target.account = account
        target.autoPost = autoPost
        target.remindDaysBefore = kind == .expense ? remindDaysBefore : -1
        target.notes = notes
        try? modelContext.save()
        RecurrenceEngine.processDue(in: modelContext)
        dismiss()
    }
}
