import SwiftUI

struct MainTabView: View {
    @Environment(AppLockManager.self) private var lockManager

    var body: some View {
        TabView {
            DashboardView()
                .tabItem { Label("Overview", systemImage: "chart.pie.fill") }
            TransactionsView()
                .tabItem { Label("Transactions", systemImage: "list.bullet.rectangle.fill") }
            BudgetsView()
                .tabItem { Label("Budgets", systemImage: "gauge.with.dots.needle.33percent") }
            DebtsView()
                .tabItem { Label("Debts", systemImage: "creditcard.fill") }
            MoreView()
                .tabItem { Label("More", systemImage: "ellipsis.circle.fill") }
        }
        .alert("App Lock", isPresented: Binding(
            get: { lockManager.lastError != nil },
            set: { if !$0 { lockManager.lastError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(lockManager.lastError ?? "")
        }
    }
}
