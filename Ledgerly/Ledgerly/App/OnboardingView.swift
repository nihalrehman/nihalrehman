import SwiftUI

/// First-run welcome: picks the currency and explains how data is protected.
struct OnboardingView: View {
    var onFinish: () -> Void

    @AppStorage(SettingsKey.currencyCode) private var currencyCode = AppSettings.defaultCurrencyCode

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    VStack(alignment: .leading, spacing: 8) {
                        Image(systemName: "chart.pie.fill")
                            .font(.system(size: 52))
                            .foregroundStyle(.tint)
                        Text("Welcome to Ledgerly")
                            .font(.largeTitle.bold())
                        Text("Track every expense, plan budgets, pay down debt and grow savings — privately, on your device.")
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 18) {
                        feature("list.bullet.rectangle.fill", "Log everything", "Groceries, fuel, rent, eating out, furniture, bills — 80+ ready-made categories.")
                        feature("gauge.with.dots.needle.33percent", "Budgets that warn you", "Monthly limits per category with early warnings.")
                        feature("creditcard.fill", "Debt planner", "Mortgages, car loans, credit cards: payoff dates, interest and amortization.")
                        feature("lock.shield.fill", "Private by design", "Face ID lock, AES-256 encryption of personal details, no accounts, no cloud, no tracking.")
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Your currency").font(.headline)
                        CurrencyPicker(selection: $currencyCode)
                            .padding()
                            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(24)
            }
            .background(Color(.systemGroupedBackground))
            .safeAreaInset(edge: .bottom) {
                Button(action: onFinish) {
                    Text("Get Started").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding()
                .background(.bar)
            }
        }
        .interactiveDismissDisabled()
    }

    private func feature(_ icon: String, _ title: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.tint)
                .frame(width: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(text).font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }
}
