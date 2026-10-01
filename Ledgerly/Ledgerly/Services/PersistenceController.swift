import Foundation
import SwiftData

/// Builds the on-device SwiftData store.
///
/// - The store lives in Application Support/SecureStore with iOS Data Protection applied.
/// - CloudKit sync is explicitly disabled: data never leaves the device unless the
///   user exports an encrypted backup or a CSV themselves.
/// - By default the store is excluded from iCloud/computer backups.
enum PersistenceController {
    static let schema = Schema([
        LedgerCategory.self,
        TransactionRecord.self,
        Account.self,
        Budget.self,
        RecurringRule.self,
        Loan.self,
        LoanPayment.self,
        SavingsGoal.self,
        UserProfile.self,
    ])

    static var storeDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("SecureStore", isDirectory: true)
    }

    static func makeContainer() -> ModelContainer {
        let directory = storeDirectory
        DataProtection.protect(directory: directory)
        DataProtection.setExcludedFromBackup(AppSettings.excludeFromBackup, at: directory)

        let storeURL = directory.appendingPathComponent("Ledgerly.store")
        let configuration = ModelConfiguration(
            schema: schema,
            url: storeURL,
            allowsSave: true,
            cloudKitDatabase: .none
        )
        do {
            let container = try ModelContainer(for: schema, configurations: [configuration])
            // Re-apply protection to the SQLite files (-wal / -shm) created on open.
            DataProtection.protect(directory: directory)
            return container
        } catch {
            fatalError("Unable to open the secure data store: \(error)")
        }
    }

    /// In-memory container for SwiftUI previews and tests.
    @MainActor
    static func makePreviewContainer() -> ModelContainer {
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        do {
            let container = try ModelContainer(for: schema, configurations: [configuration])
            SeedData.seedIfNeeded(container.mainContext, force: true)
            return container
        } catch {
            fatalError("Unable to create preview container: \(error)")
        }
    }
}
