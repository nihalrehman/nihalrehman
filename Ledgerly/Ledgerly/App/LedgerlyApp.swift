import SwiftData
import SwiftUI

@main
struct LedgerlyApp: App {
    @State private var lockManager = AppLockManager()
    private let container: ModelContainer

    init() {
        // Remove any CSV/backup files exported during a previous session.
        CSVExporter.purgeTemporaryExports()
        container = PersistenceController.makeContainer()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(lockManager)
        }
        .modelContainer(container)
    }
}
