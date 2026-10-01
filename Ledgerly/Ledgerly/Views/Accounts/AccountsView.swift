import SwiftData
import SwiftUI

struct AccountsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Account.sortOrder) private var accounts: [Account]
    @State private var showingAdd = false
    @State private var showArchived = false
    @State private var pendingDelete: Account?

    private var visible: [Account] { accounts.filter { showArchived || !$0.isArchived } }
    private var assets: Decimal { accounts.filter { $0.includeInNetWorth && !$0.isArchived && $0.balance > 0 }.sum(\.balance) }
    private var liabilities: Decimal { accounts.filter { $0.includeInNetWorth && !$0.isArchived && $0.balance < 0 }.sum(\.balance) }

    var body: some View {
        List {
            Section {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Assets").font(.caption).foregroundStyle(.secondary)
                        MoneyText(assets).font(.headline)
                    }
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text("Owed on accounts").font(.caption).foregroundStyle(.secondary)
                        MoneyText(-liabilities).font(.headline).foregroundStyle(.red)
                    }
                }
            }

            ForEach(AccountType.allCases) { type in
                let items = visible.filter { $0.type == type }
                if !items.isEmpty {
                    Section(type.title) {
                        ForEach(items) { account in
                            NavigationLink { AccountDetailView(account: account) } label: { AccountRow(account: account) }
                                .swipeActions {
                                    Button(role: .destructive) { pendingDelete = account } label: { Label("Delete", systemImage: "trash") }
                                }
                        }
                    }
                }
            }

            if accounts.contains(where: \.isArchived) {
                Toggle("Show archived", isOn: $showArchived)
            }
        }
        .navigationTitle("Accounts")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showingAdd = true } label: { Image(systemName: "plus.circle.fill") }
            }
        }
        .sheet(isPresented: $showingAdd) { AccountFormView() }
        .confirmationDialog(
            "Delete \(pendingDelete?.name ?? "account")?",
            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
            titleVisibility: .visible
        ) {
            Button("Delete Account", role: .destructive) {
                if let pendingDelete {
                    modelContext.delete(pendingDelete)
                    try? modelContext.save()
                }
                pendingDelete = nil
            }
        } message: {
            Text("Its transactions are kept but will no longer be linked to an account. You can archive it instead to hide it.")
        }
    }
}

struct AccountRow: View {
    let account: Account

    var body: some View {
        HStack(spacing: 12) {
            CategoryIcon(icon: account.type.icon, color: account.color)
            VStack(alignment: .leading, spacing: 2) {
                Text(account.name).font(.body.weight(.medium))
                let detail = [account.institution, account.maskedNumber].filter { !$0.isEmpty }.joined(separator: " · ")
                if !detail.isEmpty {
                    Text(detail).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            MoneyText(account.balance, colored: true).font(.body.weight(.semibold))
        }
        .opacity(account.isArchived ? 0.5 : 1)
    }
}

struct AccountDetailView: View {
    let account: Account
    @State private var showingEdit = false
    @State private var editing: TransactionRecord?

    private var history: [TransactionRecord] {
        ((account.transactions ?? []) + (account.incomingTransfers ?? [])).sorted { $0.date > $1.date }
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Balance").font(.caption).foregroundStyle(.secondary)
                    MoneyText(account.balance, colored: true).font(.system(.largeTitle, design: .rounded).weight(.bold))
                    if account.openingBalance != 0 {
                        HStack(spacing: 4) {
                            Text("Opening balance")
                            MoneyText(account.openingBalance)
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
                if !account.institution.isEmpty { LabeledContent("Institution", value: account.institution) }
                SecureRevealRow(title: "Account Number", value: account.accountNumber)
            }

            Section("Activity") {
                if history.isEmpty {
                    Text("No transactions yet.").foregroundStyle(.secondary)
                }
                ForEach(history) { tx in
                    Button { editing = tx } label: { TransactionRow(transaction: tx) }.tint(.primary)
                }
            }
        }
        .navigationTitle(account.name)
        .toolbar {
            ToolbarItem(placement: .primaryAction) { Button("Edit") { showingEdit = true } }
        }
        .sheet(isPresented: $showingEdit) { AccountFormView(account: account) }
        .sheet(item: $editing) { TransactionFormView(transaction: $0) }
    }
}

struct AccountFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var accounts: [Account]

    private let account: Account?
    @State private var name: String
    @State private var type: AccountType
    @State private var openingBalance: Decimal?
    @State private var institution: String
    @State private var accountNumber: String
    @State private var colorHex: String
    @State private var includeInNetWorth: Bool
    @State private var isArchived: Bool

    init(account: Account? = nil) {
        self.account = account
        _name = State(initialValue: account?.name ?? "")
        _type = State(initialValue: account?.type ?? .checking)
        _openingBalance = State(initialValue: account?.openingBalance)
        _institution = State(initialValue: account?.institution ?? "")
        _accountNumber = State(initialValue: account?.accountNumber ?? "")
        _colorHex = State(initialValue: account?.colorHex ?? "#0A84FF")
        _includeInNetWorth = State(initialValue: account?.includeInNetWorth ?? true)
        _isArchived = State(initialValue: account?.isArchived ?? false)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Account name", text: $name)
                    Picker("Type", selection: $type) {
                        ForEach(AccountType.allCases) { Label($0.title, systemImage: $0.icon).tag($0) }
                    }
                    LabeledContent("Opening balance") {
                        AmountField(title: "0", amount: $openingBalance).multilineTextAlignment(.trailing)
                    }
                } footer: {
                    if type.isLiability {
                        Text("For credit cards, enter what you currently owe as a negative number (e.g. -1500).")
                    }
                }

                Section {
                    TextField("Bank / institution", text: $institution)
                    TextField("Account or card number", text: $accountNumber)
                        .keyboardType(.asciiCapable)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                } header: {
                    Text("Bank Details (optional)")
                } footer: {
                    EncryptedFootnote(text: "Encrypted on this device. Only the last 4 digits are shown.")
                }

                Section("Color") {
                    ColorSwatchPicker(selection: $colorHex)
                }

                Section {
                    Toggle("Include in net worth", isOn: $includeInNetWorth)
                    if account != nil { Toggle("Archived", isOn: $isArchived) }
                }
            }
            .navigationTitle(account == nil ? "New Account" : "Edit Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func save() {
        let target: Account
        if let account {
            target = account
        } else {
            target = Account(name: "", type: type, sortOrder: (accounts.map(\.sortOrder).max() ?? 0) + 1)
            modelContext.insert(target)
        }
        target.name = name.trimmingCharacters(in: .whitespaces)
        target.type = type
        target.openingBalance = openingBalance ?? 0
        target.institution = institution.trimmingCharacters(in: .whitespaces)
        target.accountNumber = accountNumber.trimmingCharacters(in: .whitespaces)
        target.colorHex = colorHex
        target.includeInNetWorth = includeInNetWorth
        target.isArchived = isArchived
        try? modelContext.save()
        dismiss()
    }
}

struct ColorSwatchPicker: View {
    @Binding var selection: String

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 8), spacing: 10) {
            ForEach(Palette.colors, id: \.self) { hex in
                Circle()
                    .fill(Color(hex: hex))
                    .frame(width: 30, height: 30)
                    .overlay {
                        if hex == selection {
                            Image(systemName: "checkmark").font(.caption.bold()).foregroundStyle(.white)
                        }
                    }
                    .onTapGesture { selection = hex }
                    .accessibilityAddTraits(hex == selection ? .isSelected : [])
            }
        }
        .padding(.vertical, 4)
    }
}

struct IconPicker: View {
    @Binding var selection: String
    var color: Color

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 7), spacing: 10) {
            ForEach(Palette.icons, id: \.self) { icon in
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .frame(width: 36, height: 36)
                    .foregroundStyle(icon == selection ? .white : color)
                    .background(icon == selection ? color : Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 9))
                    .onTapGesture { selection = icon }
            }
        }
        .padding(.vertical, 4)
    }
}
