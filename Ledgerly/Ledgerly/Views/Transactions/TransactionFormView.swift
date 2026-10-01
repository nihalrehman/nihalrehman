import SwiftData
import SwiftUI

/// Add or edit an expense, income or transfer.
struct TransactionFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Account.sortOrder) private var accounts: [Account]

    private let transaction: TransactionRecord?

    @State private var kind: TransactionKind
    @State private var amount: Decimal?
    @State private var date: Date
    @State private var category: LedgerCategory?
    @State private var account: Account?
    @State private var transferAccount: Account?
    @State private var payee: String
    @State private var notes: String
    @State private var confirmDelete = false
    @FocusState private var amountFocused: Bool

    init(transaction: TransactionRecord? = nil, defaultKind: TransactionKind = .expense) {
        self.transaction = transaction
        _kind = State(initialValue: transaction?.kind ?? defaultKind)
        _amount = State(initialValue: transaction?.amount)
        _date = State(initialValue: transaction?.date ?? Date())
        _category = State(initialValue: transaction?.category)
        _account = State(initialValue: transaction?.account)
        _transferAccount = State(initialValue: transaction?.transferAccount)
        _payee = State(initialValue: transaction?.payee ?? "")
        _notes = State(initialValue: transaction?.notes ?? "")
    }

    private var activeAccounts: [Account] { accounts.filter { !$0.isArchived || $0.id == account?.id || $0.id == transferAccount?.id } }

    private var isValid: Bool {
        guard let amount, amount > 0 else { return false }
        if kind == .transfer {
            return account != nil && transferAccount != nil && account?.id != transferAccount?.id
        }
        return true
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Type", selection: $kind) {
                        ForEach(TransactionKind.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }

                Section("Amount") {
                    AmountField(title: "0.00", amount: $amount, large: true)
                        .focused($amountFocused)
                }

                Section {
                    if let categoryKind = kind.categoryKind {
                        NavigationLink {
                            CategoryPickerView(kind: categoryKind, selection: $category)
                        } label: {
                            LabeledContent("Category") {
                                if let category {
                                    Label(category.name, systemImage: category.icon)
                                        .foregroundStyle(category.color)
                                } else {
                                    Text("Choose").foregroundStyle(.secondary)
                                }
                            }
                        }
                    }

                    Picker(kind == .transfer ? "From Account" : "Account", selection: $account) {
                        Text("None").tag(nil as Account?)
                        ForEach(activeAccounts) { Text($0.name).tag($0 as Account?) }
                    }

                    if kind == .transfer {
                        Picker("To Account", selection: $transferAccount) {
                            Text("None").tag(nil as Account?)
                            ForEach(activeAccounts.filter { $0.id != account?.id }) { Text($0.name).tag($0 as Account?) }
                        }
                    }

                    DatePicker("Date", selection: $date)
                }

                Section {
                    TextField(kind == .income ? "Received from" : "Payee / merchant", text: $payee)
                        .textContentType(.organizationName)
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(1...5)
                } header: {
                    Text("Details")
                } footer: {
                    EncryptedFootnote(text: "Payee and notes are encrypted on this device.")
                }

                if transaction != nil {
                    Section {
                        Button("Delete Transaction", role: .destructive) { confirmDelete = true }
                    }
                }
            }
            .navigationTitle(transaction == nil ? "New \(kind.title)" : "Edit \(kind.title)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).disabled(!isValid)
                }
            }
            .onChange(of: kind) { _, newKind in
                if category?.kind != newKind.categoryKind { category = nil }
                if newKind != .transfer { transferAccount = nil }
            }
            .onAppear {
                if transaction == nil {
                    amountFocused = true
                    if account == nil { account = accounts.first { !$0.isArchived } }
                }
            }
            .confirmationDialog("Delete this transaction?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    if let transaction { modelContext.delete(transaction) }
                    try? modelContext.save()
                    dismiss()
                }
            }
        }
    }

    private func save() {
        guard let amount else { return }
        let record: TransactionRecord
        if let transaction {
            record = transaction
            record.amount = amount
            record.kind = kind
            record.date = date
        } else {
            record = TransactionRecord(amount: amount, kind: kind, date: date)
            modelContext.insert(record)
        }
        record.category = kind == .transfer ? nil : category
        record.account = account
        record.transferAccount = kind == .transfer ? transferAccount : nil
        record.payee = payee.trimmingCharacters(in: .whitespacesAndNewlines)
        record.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        try? modelContext.save()
        dismiss()
    }
}
