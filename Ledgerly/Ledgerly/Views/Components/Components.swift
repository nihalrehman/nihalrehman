import SwiftUI
import UIKit

/// Displays a currency amount, honoring the "hide amounts" privacy toggle.
struct MoneyText: View {
    let amount: Decimal
    var kind: TransactionKind? = nil
    var colored = false

    @AppStorage(SettingsKey.currencyCode) private var currencyCode = AppSettings.defaultCurrencyCode
    @AppStorage(SettingsKey.hideAmounts) private var hideAmounts = false

    init(_ amount: Decimal, kind: TransactionKind? = nil, colored: Bool = false) {
        self.amount = amount
        self.kind = kind
        self.colored = colored
    }

    @ViewBuilder
    var body: some View {
        // Only force a color when asked, so callers can style plain amounts.
        if colored {
            Text(text).monospacedDigit().foregroundStyle(color)
        } else {
            Text(text).monospacedDigit()
        }
    }

    private var text: String {
        if hideAmounts { return "••••" }
        let formatted = amount.formatted(.currency(code: currencyCode))
        switch kind {
        case .income?: return "+" + formatted
        case .expense?: return "−" + formatted
        default: return formatted
        }
    }

    private var color: Color {
        guard colored else { return .primary }
        switch kind {
        case .income?: return .green
        case .expense?: return .primary
        case .transfer?: return .blue
        case nil: return amount < 0 ? .red : .primary
        }
    }
}

struct CategoryIcon: View {
    let icon: String
    let color: Color
    var size: CGFloat = 36

    var body: some View {
        Image(systemName: icon)
            .font(.system(size: size * 0.45, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(color.gradient, in: RoundedRectangle(cornerRadius: size * 0.28, style: .continuous))
    }
}

struct TransactionRow: View {
    let transaction: TransactionRecord

    var body: some View {
        HStack(spacing: 12) {
            if transaction.kind == .transfer {
                CategoryIcon(icon: "arrow.left.arrow.right", color: .blue)
            } else {
                CategoryIcon(icon: transaction.category?.icon ?? "questionmark", color: transaction.category?.color ?? .gray)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.displayTitle)
                    .font(.body)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                MoneyText(transaction.amount, kind: transaction.kind, colored: true)
                    .font(.body.weight(.semibold))
                if transaction.recurringRuleID != nil {
                    Image(systemName: "repeat").font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }

    private var subtitle: String {
        var parts: [String] = []
        if transaction.kind == .transfer {
            parts.append("\(transaction.account?.name ?? "?") → \(transaction.transferAccount?.name ?? "?")")
        } else {
            if let category = transaction.category { parts.append(category.fullName) }
            if let account = transaction.account { parts.append(account.name) }
        }
        return parts.joined(separator: " · ")
    }
}

struct ProgressBar: View {
    let value: Double
    var tint: Color = .accentColor
    var height: CGFloat = 8

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Color(.tertiarySystemFill))
                Capsule()
                    .fill(tint.gradient)
                    .frame(width: proxy.size.width * min(max(value, 0), 1))
            }
        }
        .frame(height: height)
    }
}

struct MonthSelector: View {
    @Binding var month: Date

    var body: some View {
        HStack {
            Button { month = month.adding(months: -1) } label: {
                Image(systemName: "chevron.left").padding(8)
            }
            Spacer()
            Text(month.monthTitle).font(.headline)
            Spacer()
            Button { month = month.adding(months: 1) } label: {
                Image(systemName: "chevron.right").padding(8)
            }
            .disabled(month.startOfMonth >= Date().startOfMonth)
        }
        .buttonStyle(.borderless)
    }
}

struct CurrencyPicker: View {
    @Binding var selection: String

    private static let codes: [String] = {
        let popular = ["AED", "USD", "EUR", "GBP", "INR", "PKR", "SAR", "QAR", "KWD", "OMR", "BHD", "CAD", "AUD", "SGD", "JPY", "CNY", "CHF", "ZAR", "NGN", "EGP", "BDT", "LKR", "PHP", "MYR", "IDR"]
        let all = Locale.commonISOCurrencyCodes
        return popular + all.filter { !popular.contains($0) }.sorted()
    }()

    var body: some View {
        Picker("Currency", selection: $selection) {
            ForEach(Self.codes, id: \.self) { code in
                Text("\(code) — \(Locale.current.localizedString(forCurrencyCode: code) ?? code)").tag(code)
            }
        }
        .pickerStyle(.navigationLink)
    }
}

/// A decimal amount entry field.
struct AmountField: View {
    let title: String
    @Binding var amount: Decimal?
    var large = false

    var body: some View {
        TextField(title, value: $amount, format: .number.precision(.fractionLength(0...2)))
            .keyboardType(.decimalPad)
            .font(large ? .system(size: 34, weight: .bold, design: .rounded) : .body)
            .monospacedDigit()
    }
}

/// Shows a masked value that can be revealed after Face ID / passcode.
struct SecureRevealRow: View {
    let title: String
    let value: String
    var masked: (String) -> String = { Masking.mask($0) }

    @State private var revealed = false

    var body: some View {
        if !value.isEmpty {
            LabeledContent(title) {
                HStack(spacing: 8) {
                    Text(revealed ? value : masked(value))
                        .monospaced()
                        .textSelection(.enabled)
                    Button {
                        if revealed {
                            revealed = false
                        } else {
                            Task {
                                revealed = await AppLockManager.authenticate(reason: "Reveal \(title.lowercased())", allowWithoutPasscode: true)
                            }
                        }
                    } label: {
                        Image(systemName: revealed ? "eye.slash" : "eye")
                    }
                    .buttonStyle(.borderless)
                }
            }
        }
    }
}

struct EncryptedFootnote: View {
    var text = "Encrypted on this device with AES-256."

    var body: some View {
        Label(text, systemImage: "lock.fill")
            .font(.footnote)
            .foregroundStyle(.secondary)
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

/// Wrapper so a URL can drive `.sheet(item:)`.
struct ShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

struct SectionHeader: View {
    let title: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack {
            Text(title).font(.headline)
            Spacer()
            if let actionTitle, let action {
                Button(actionTitle, action: action).font(.subheadline)
            }
        }
    }
}
