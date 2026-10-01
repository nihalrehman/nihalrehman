import Foundation

enum Masking {
    /// Masks all but the last four characters: "123456789" → "•••• 6789".
    static func mask(_ value: String, visible: Int = 4) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return "" }
        guard trimmed.count > visible else { return String(repeating: "•", count: trimmed.count) }
        return "•••• " + trimmed.suffix(visible)
    }

    /// Masks an email address: "jane.doe@example.com" → "j•••••••@example.com".
    static func maskEmail(_ email: String) -> String {
        let parts = email.split(separator: "@", maxSplits: 1)
        guard parts.count == 2, let first = parts[0].first else { return mask(email) }
        return "\(first)\(String(repeating: "•", count: max(parts[0].count - 1, 3)))@\(parts[1])"
    }
}
