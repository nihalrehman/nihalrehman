import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(AppLockManager.self) private var lockManager
    @Environment(\.modelContext) private var modelContext
    @Query private var transactions: [TransactionRecord]

    @AppStorage(SettingsKey.currencyCode) private var currencyCode = AppSettings.defaultCurrencyCode
    @AppStorage(SettingsKey.hideAmounts) private var hideAmounts = false
    @AppStorage(SettingsKey.excludeFromBackup) private var excludeFromBackup = true
    @AppStorage(SettingsKey.billReminders) private var billReminders = false

    @State private var shareItem: ShareItem?
    @State private var showingBackupPassword = false
    @State private var showingRestorePicker = false
    @State private var pendingRestoreData: Data?
    @State private var showingRestorePassword = false
    @State private var confirmErase = false
    @State private var message: String?
    @State private var isWorking = false

    var body: some View {
        Form {
            Section("General") {
                CurrencyPicker(selection: $currencyCode)
                Toggle("Hide amounts", isOn: $hideAmounts)
            }

            Section {
                Toggle(isOn: Binding(
                    get: { lockManager.lockEnabled },
                    set: { newValue in Task { await lockManager.setLockEnabled(newValue) } }
                )) {
                    Label("Require \(AppLockManager.biometryName)", systemImage: AppLockManager.biometryIcon)
                }
                if lockManager.lockEnabled {
                    Picker("Auto-Lock", selection: Binding(
                        get: { lockManager.autoLockSeconds },
                        set: { lockManager.autoLockSeconds = $0 }
                    )) {
                        ForEach(AppSettings.autoLockOptions) { option in
                            Text(option.title).tag(option.seconds)
                        }
                    }
                    Button("Lock Now") { lockManager.lock() }
                }
            } header: {
                Text("App Lock")
            } footer: {
                Text("Uses \(AppLockManager.biometryName) with your device passcode as a fallback. Ledgerly also hides its content in the app switcher.")
            }

            Section {
                Toggle("Exclude data from device backups", isOn: $excludeFromBackup)
                    .onChange(of: excludeFromBackup) { _, newValue in
                        DataProtection.setExcludedFromBackup(newValue, at: PersistenceController.storeDirectory)
                    }
            } header: {
                Text("Privacy")
            } footer: {
                Text("When on, your financial data never goes into iCloud or computer backups. Use an encrypted Ledgerly backup to move to a new phone.")
            }

            Section {
                Toggle("Bill reminders", isOn: $billReminders)
                    .onChange(of: billReminders) { _, enabled in
                        Task {
                            if enabled {
                                let granted = await NotificationScheduler.requestAuthorization()
                                if !granted {
                                    billReminders = false
                                    message = "Notifications are turned off for Ledgerly. Enable them in iOS Settings → Notifications."
                                }
                            }
                            await NotificationScheduler.reschedule(in: modelContext)
                        }
                    }
            } header: {
                Text("Notifications")
            } footer: {
                Text("Reminder text is generic — bill names and amounts are never shown on the lock screen.")
            }

            Section {
                Button {
                    Task { await exportCSV() }
                } label: {
                    Label("Export Transactions (CSV)", systemImage: "tablecells")
                }
                Button {
                    showingBackupPassword = true
                } label: {
                    Label("Create Encrypted Backup", systemImage: "lock.doc")
                }
                Button {
                    showingRestorePicker = true
                } label: {
                    Label("Restore from Backup", systemImage: "arrow.counterclockwise")
                }
            } header: {
                Text("Your Data")
            } footer: {
                Text("CSV files are not encrypted — store them carefully. Encrypted backups are protected by a password only you know; Ledgerly cannot recover it.")
            }

            Section {
                Button("Erase All Data", role: .destructive) { confirmErase = true }
            } footer: {
                Text("Permanently deletes every transaction, account, debt, goal and your profile, and destroys the encryption key.")
            }

            Section {
                LabeledContent("Version", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0")
                LabeledContent("Transactions", value: "\(transactions.count)")
            }
        }
        .navigationTitle("Settings")
        .disabled(isWorking)
        .overlay { if isWorking { ProgressView().controlSize(.large) } }
        .sheet(item: $shareItem) { item in
            ShareSheet(items: [item.url])
        }
        .sheet(isPresented: $showingBackupPassword) {
            BackupPasswordView(mode: .create) { password in
                Task { await createBackup(password: password) }
            }
        }
        .sheet(isPresented: $showingRestorePassword) {
            BackupPasswordView(mode: .restore) { password in
                Task { await restoreBackup(password: password) }
            }
        }
        .fileImporter(isPresented: $showingRestorePicker, allowedContentTypes: [.data, .json, .item]) { result in
            handleImport(result)
        }
        .confirmationDialog("Erase all data?", isPresented: $confirmErase, titleVisibility: .visible) {
            Button("Erase Everything", role: .destructive) {
                Task { await eraseAll() }
            }
        } message: {
            Text("This cannot be undone. Create an encrypted backup first if you may need your data later.")
        }
        .alert("Ledgerly", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(message ?? "")
        }
    }

    // MARK: - Actions

    private func exportCSV() async {
        guard await AppLockManager.authenticate(reason: "Export your transactions", allowWithoutPasscode: true) else { return }
        do {
            let url = try CSVExporter.exportTransactions(transactions, currencyCode: currencyCode)
            shareItem = ShareItem(url: url)
        } catch {
            message = "Export failed: \(error.localizedDescription)"
        }
    }

    private func createBackup(password: String) async {
        guard await AppLockManager.authenticate(reason: "Create an encrypted backup", allowWithoutPasscode: true) else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            let url = try await BackupService.createBackup(in: modelContext, password: password)
            shareItem = ShareItem(url: url)
        } catch {
            message = "Backup failed: \(error.localizedDescription)"
        }
    }

    private func handleImport(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            do {
                pendingRestoreData = try Data(contentsOf: url)
                // Give the document picker time to finish dismissing.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { showingRestorePassword = true }
            } catch {
                message = "Couldn't read the file: \(error.localizedDescription)"
            }
        case .failure(let error):
            message = error.localizedDescription
        }
    }

    private func restoreBackup(password: String) async {
        guard let data = pendingRestoreData else { return }
        pendingRestoreData = nil
        guard await AppLockManager.authenticate(reason: "Restore a backup", allowWithoutPasscode: true) else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            let payload = try await BackupService.restoreBackup(from: data, password: password, in: modelContext)
            currencyCode = payload.currencyCode
            await NotificationScheduler.reschedule(in: modelContext)
            message = "Restored \(payload.transactions.count) transactions from a backup made on \(payload.createdAt.formatted(date: .abbreviated, time: .shortened))."
        } catch {
            message = error.localizedDescription
        }
    }

    private func eraseAll() async {
        guard await AppLockManager.authenticate(reason: "Erase all Ledgerly data", allowWithoutPasscode: true) else { return }
        do {
            try DataManager.eraseEverything(in: modelContext)
            message = "All data has been erased."
        } catch {
            message = "Erase failed: \(error.localizedDescription)"
        }
    }
}

struct BackupPasswordView: View {
    enum Mode { case create, restore }

    let mode: Mode
    let onSubmit: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var password = ""
    @State private var confirm = ""

    private var isValid: Bool {
        switch mode {
        case .create: password.count >= PasswordCrypto.minimumPasswordLength && password == confirm
        case .restore: !password.isEmpty
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("Backup password", text: $password)
                        .textContentType(mode == .create ? .newPassword : .password)
                    if mode == .create {
                        SecureField("Confirm password", text: $confirm)
                            .textContentType(.newPassword)
                    }
                } footer: {
                    if mode == .create {
                        Text("At least \(PasswordCrypto.minimumPasswordLength) characters. The backup is encrypted with AES-256 using a key derived from this password (PBKDF2, 600,000 rounds). If you forget it, the backup cannot be opened.")
                    } else {
                        Text("Restoring replaces all data currently in Ledgerly.")
                    }
                }
            }
            .navigationTitle(mode == .create ? "Encrypted Backup" : "Restore Backup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(mode == .create ? "Create" : "Restore") {
                        let value = password
                        password = ""
                        confirm = ""
                        dismiss()
                        onSubmit(value)
                    }
                    .disabled(!isValid)
                }
            }
        }
    }
}
