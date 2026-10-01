import Foundation
import SwiftData
import UserNotifications

/// Bulk data operations: erase everything, crypto-shred the key.
@MainActor
enum DataManager {
    /// Deletes every record in the store (keeps the encryption key).
    static func deleteAllRecords(in context: ModelContext) throws {
        try deleteAll(TransactionRecord.self, in: context)
        try deleteAll(LoanPayment.self, in: context)
        try deleteAll(Loan.self, in: context)
        try deleteAll(Budget.self, in: context)
        try deleteAll(RecurringRule.self, in: context)
        try deleteAll(SavingsGoal.self, in: context)
        try deleteAll(UserProfile.self, in: context)
        try deleteAll(Account.self, in: context)
        try deleteAll(LedgerCategory.self, in: context)
        try context.save()
    }

    /// Factory reset: deletes all records, destroys the encryption key so any
    /// residual ciphertext on disk is unrecoverable, removes pending reminders,
    /// clears exports and re-creates the default categories.
    static func eraseEverything(in context: ModelContext) throws {
        try deleteAllRecords(in: context)
        CryptoService.shared.destroyKey()
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        CSVExporter.purgeTemporaryExports()
        UserDefaults.standard.removeObject(forKey: SettingsKey.didSeed)
        SeedData.seedIfNeeded(context)
    }

    private static func deleteAll<T: PersistentModel>(_ type: T.Type, in context: ModelContext) throws {
        for object in try context.fetch(FetchDescriptor<T>()) {
            context.delete(object)
        }
    }
}
