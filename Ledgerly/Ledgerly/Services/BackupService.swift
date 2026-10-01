import Foundation
import SwiftData

/// Password-protected backups that can be restored on this or another device.
///
/// Records are serialised to JSON (sensitive fields decrypted only in memory),
/// then sealed with a key derived from the backup password (see `PasswordCrypto`).
/// Without the password the file is useless.
@MainActor
enum BackupService {
    static let fileExtension = "ledgerbackup"

    // MARK: - Create

    static func createBackup(in context: ModelContext, password: String) async throws -> URL {
        let payload = try makePayload(context)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let json = try encoder.encode(payload)
        let sealed = try await Task.detached(priority: .userInitiated) {
            try PasswordCrypto.seal(json, password: password)
        }.value
        let stamp = Date().formatted(.iso8601.year().month().day())
        return try CSVExporter.write(sealed, named: "Ledgerly-Backup-\(stamp).\(fileExtension)")
    }

    // MARK: - Restore

    /// Replaces all current data with the backup's contents.
    static func restoreBackup(from fileData: Data, password: String, in context: ModelContext) async throws -> BackupPayload {
        let json = try await Task.detached(priority: .userInitiated) {
            try PasswordCrypto.open(fileData, password: password)
        }.value
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let payload = try decoder.decode(BackupPayload.self, from: json)

        try DataManager.deleteAllRecords(in: context)
        apply(payload, to: context)
        try context.save()
        UserDefaults.standard.set(true, forKey: SettingsKey.didSeed)
        UserDefaults.standard.set(payload.currencyCode, forKey: SettingsKey.currencyCode)
        return payload
    }

    // MARK: - Mapping

    private static func makePayload(_ context: ModelContext) throws -> BackupPayload {
        let categories = try context.fetch(FetchDescriptor<LedgerCategory>())
        let accounts = try context.fetch(FetchDescriptor<Account>())
        let transactions = try context.fetch(FetchDescriptor<TransactionRecord>())
        let budgets = try context.fetch(FetchDescriptor<Budget>())
        let rules = try context.fetch(FetchDescriptor<RecurringRule>())
        let loans = try context.fetch(FetchDescriptor<Loan>())
        let goals = try context.fetch(FetchDescriptor<SavingsGoal>())
        let profile = try context.fetch(FetchDescriptor<UserProfile>()).first

        let categoryDTOs: [BackupPayload.Category] = categories.map { c in
            BackupPayload.Category(id: c.id, name: c.name, icon: c.icon, colorHex: c.colorHex, kind: c.kindRaw, sortOrder: c.sortOrder, isSystem: c.isSystem, parentID: c.parent?.id)
        }
        let accountDTOs: [BackupPayload.AccountDTO] = accounts.map { a in
            BackupPayload.AccountDTO(id: a.id, name: a.name, type: a.typeRaw, openingBalance: a.openingBalance, institution: a.institution, accountNumber: a.accountNumber, colorHex: a.colorHex, isArchived: a.isArchived, includeInNetWorth: a.includeInNetWorth, sortOrder: a.sortOrder)
        }
        let transactionDTOs: [BackupPayload.Transaction] = transactions.map { t in
            BackupPayload.Transaction(id: t.id, amount: t.amount, kind: t.kindRaw, date: t.date, payee: t.payee, notes: t.notes, categoryID: t.category?.id, accountID: t.account?.id, transferAccountID: t.transferAccount?.id, recurringRuleID: t.recurringRuleID, loanPaymentID: t.loanPaymentID)
        }
        let budgetDTOs: [BackupPayload.BudgetDTO] = budgets.map { b in
            BackupPayload.BudgetDTO(id: b.id, limit: b.limit, alertThreshold: b.alertThreshold, categoryID: b.category?.id)
        }
        let ruleDTOs: [BackupPayload.Recurring] = rules.map { r in
            BackupPayload.Recurring(id: r.id, name: r.name, amount: r.amount, kind: r.kindRaw, frequency: r.frequencyRaw, startDate: r.startDate, nextDueDate: r.nextDueDate, endDate: r.endDate, occurrencesPosted: r.occurrencesPosted, autoPost: r.autoPost, remindDaysBefore: r.remindDaysBefore, isActive: r.isActive, notes: r.notes, categoryID: r.category?.id, accountID: r.account?.id)
        }
        let loanDTOs: [BackupPayload.LoanDTO] = loans.map { loan in
            let payments: [BackupPayload.Payment] = (loan.payments ?? []).map { p in
                BackupPayload.Payment(id: p.id, date: p.date, amount: p.amount, principalPortion: p.principalPortion, interestPortion: p.interestPortion, isExtra: p.isExtra)
            }
            return BackupPayload.LoanDTO(id: loan.id, name: loan.name, type: loan.typeRaw, lender: loan.lender, accountNumber: loan.accountNumber, notes: loan.notes, originalAmount: loan.originalAmount, currentBalance: loan.currentBalance, interestRate: loan.interestRate, termMonths: loan.termMonths, startDate: loan.startDate, monthlyPayment: loan.monthlyPayment, paymentDayOfMonth: loan.paymentDayOfMonth, creditLimit: loan.creditLimit, isClosed: loan.isClosed, payments: payments)
        }
        let goalDTOs: [BackupPayload.Goal] = goals.map { g in
            BackupPayload.Goal(id: g.id, name: g.name, icon: g.icon, colorHex: g.colorHex, targetAmount: g.targetAmount, savedAmount: g.savedAmount, targetDate: g.targetDate, notes: g.notes)
        }
        var profileDTO: BackupPayload.Profile?
        if let p = profile {
            profileDTO = BackupPayload.Profile(fullName: p.fullName, email: p.email, phone: p.phone, address: p.address, dateOfBirth: p.dateOfBirth, nationalID: p.nationalID, employer: p.employer, monthlyIncome: p.monthlyIncome)
        }

        return BackupPayload(
            appVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0",
            createdAt: Date(),
            currencyCode: AppSettings.currencyCode,
            categories: categoryDTOs,
            accounts: accountDTOs,
            transactions: transactionDTOs,
            budgets: budgetDTOs,
            recurringRules: ruleDTOs,
            loans: loanDTOs,
            goals: goalDTOs,
            profile: profileDTO
        )
    }

    private static func apply(_ payload: BackupPayload, to context: ModelContext) {
        var categories: [UUID: LedgerCategory] = [:]
        for dto in payload.categories {
            let c = LedgerCategory(name: dto.name, icon: dto.icon, colorHex: dto.colorHex, kind: CategoryKind(rawValue: dto.kind) ?? .expense, sortOrder: dto.sortOrder, isSystem: dto.isSystem)
            c.id = dto.id
            context.insert(c)
            categories[dto.id] = c
        }
        for dto in payload.categories {
            if let parentID = dto.parentID { categories[dto.id]?.parent = categories[parentID] }
        }

        var accounts: [UUID: Account] = [:]
        for dto in payload.accounts {
            let a = Account(name: dto.name, type: AccountType(rawValue: dto.type) ?? .other, openingBalance: dto.openingBalance, colorHex: dto.colorHex, sortOrder: dto.sortOrder)
            a.id = dto.id
            context.insert(a)
            a.institution = dto.institution
            a.accountNumber = dto.accountNumber
            a.isArchived = dto.isArchived
            a.includeInNetWorth = dto.includeInNetWorth
            accounts[dto.id] = a
        }

        for dto in payload.transactions {
            let t = TransactionRecord(amount: dto.amount, kind: TransactionKind(rawValue: dto.kind) ?? .expense, date: dto.date)
            t.id = dto.id
            context.insert(t)
            t.payee = dto.payee
            t.notes = dto.notes
            t.recurringRuleID = dto.recurringRuleID
            t.loanPaymentID = dto.loanPaymentID
            t.category = dto.categoryID.flatMap { categories[$0] }
            t.account = dto.accountID.flatMap { accounts[$0] }
            t.transferAccount = dto.transferAccountID.flatMap { accounts[$0] }
        }

        for dto in payload.budgets {
            let b = Budget(limit: dto.limit, alertThreshold: dto.alertThreshold)
            b.id = dto.id
            context.insert(b)
            b.category = dto.categoryID.flatMap { categories[$0] }
        }

        for dto in payload.recurringRules {
            let r = RecurringRule(name: dto.name, amount: dto.amount, kind: TransactionKind(rawValue: dto.kind) ?? .expense, frequency: RecurrenceFrequency(rawValue: dto.frequency) ?? .monthly, startDate: dto.startDate)
            r.id = dto.id
            context.insert(r)
            r.nextDueDate = dto.nextDueDate
            r.endDate = dto.endDate
            r.occurrencesPosted = dto.occurrencesPosted
            r.autoPost = dto.autoPost
            r.remindDaysBefore = dto.remindDaysBefore
            r.isActive = dto.isActive
            r.notes = dto.notes
            r.category = dto.categoryID.flatMap { categories[$0] }
            r.account = dto.accountID.flatMap { accounts[$0] }
        }

        for dto in payload.loans {
            let l = Loan(name: dto.name, type: DebtType(rawValue: dto.type) ?? .other, originalAmount: dto.originalAmount, currentBalance: dto.currentBalance, interestRate: dto.interestRate, termMonths: dto.termMonths, monthlyPayment: dto.monthlyPayment, startDate: dto.startDate)
            l.id = dto.id
            context.insert(l)
            l.lender = dto.lender
            l.accountNumber = dto.accountNumber
            l.notes = dto.notes
            l.paymentDayOfMonth = dto.paymentDayOfMonth
            l.creditLimit = dto.creditLimit
            l.isClosed = dto.isClosed
            for p in dto.payments {
                let payment = LoanPayment(date: p.date, amount: p.amount, principalPortion: p.principalPortion, interestPortion: p.interestPortion, isExtra: p.isExtra)
                payment.id = p.id
                context.insert(payment)
                payment.loan = l
            }
        }

        for dto in payload.goals {
            let g = SavingsGoal(name: dto.name, icon: dto.icon, colorHex: dto.colorHex, targetAmount: dto.targetAmount, savedAmount: dto.savedAmount, targetDate: dto.targetDate)
            g.id = dto.id
            context.insert(g)
            g.notes = dto.notes
        }

        if let dto = payload.profile {
            let p = UserProfile()
            context.insert(p)
            p.fullName = dto.fullName
            p.email = dto.email
            p.phone = dto.phone
            p.address = dto.address
            p.dateOfBirth = dto.dateOfBirth
            p.nationalID = dto.nationalID
            p.employer = dto.employer
            p.monthlyIncome = dto.monthlyIncome
        }
    }
}

// MARK: - Backup DTOs

struct BackupPayload: Codable {
    struct Category: Codable { var id: UUID; var name, icon, colorHex, kind: String; var sortOrder: Int; var isSystem: Bool; var parentID: UUID? }
    struct AccountDTO: Codable { var id: UUID; var name, type: String; var openingBalance: Decimal; var institution, accountNumber, colorHex: String; var isArchived, includeInNetWorth: Bool; var sortOrder: Int }
    struct Transaction: Codable { var id: UUID; var amount: Decimal; var kind: String; var date: Date; var payee, notes: String; var categoryID, accountID, transferAccountID, recurringRuleID, loanPaymentID: UUID? }
    struct BudgetDTO: Codable { var id: UUID; var limit: Decimal; var alertThreshold: Double; var categoryID: UUID? }
    struct Recurring: Codable { var id: UUID; var name: String; var amount: Decimal; var kind, frequency: String; var startDate, nextDueDate: Date; var endDate: Date?; var occurrencesPosted: Int; var autoPost: Bool; var remindDaysBefore: Int; var isActive: Bool; var notes: String; var categoryID, accountID: UUID? }
    struct Payment: Codable { var id: UUID; var date: Date; var amount, principalPortion, interestPortion: Decimal; var isExtra: Bool }
    struct LoanDTO: Codable { var id: UUID; var name, type, lender, accountNumber, notes: String; var originalAmount, currentBalance: Decimal; var interestRate: Double; var termMonths: Int; var startDate: Date; var monthlyPayment: Decimal; var paymentDayOfMonth: Int; var creditLimit: Decimal; var isClosed: Bool; var payments: [Payment] }
    struct Goal: Codable { var id: UUID; var name, icon, colorHex: String; var targetAmount, savedAmount: Decimal; var targetDate: Date?; var notes: String }
    struct Profile: Codable { var fullName, email, phone, address, dateOfBirth, nationalID, employer: String; var monthlyIncome: Decimal? }

    var appVersion: String
    var createdAt: Date
    var currencyCode: String
    var categories: [Category]
    var accounts: [AccountDTO]
    var transactions: [Transaction]
    var budgets: [BudgetDTO]
    var recurringRules: [Recurring]
    var loans: [LoanDTO]
    var goals: [Goal]
    var profile: Profile?
}
