import Foundation

/// Exports transactions to CSV for spreadsheets or an accountant.
///
/// The file is written with complete file protection to a private temporary
/// folder and is purged on next launch. Text cells are neutralised against
/// spreadsheet formula injection (cells starting with = + - @ are prefixed).
enum CSVExporter {
    static var exportDirectory: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("LedgerlyExports", isDirectory: true)
    }

    static func exportTransactions(_ transactions: [TransactionRecord], currencyCode: String) throws -> URL {
        let header = ["Date", "Type", "Amount", "Currency", "Category Group", "Category", "Account", "To Account", "Payee", "Notes"]
        var lines = [header.map(escape).joined(separator: ",")]

        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withFullDate]

        for t in transactions.sorted(by: { $0.date < $1.date }) {
            let row: [String] = [
                dateFormatter.string(from: t.date),
                t.kind.title,
                NSDecimalNumber(decimal: t.amount).stringValue,
                currencyCode,
                t.category?.root.name ?? "",
                t.category?.name ?? "",
                t.account?.name ?? "",
                t.transferAccount?.name ?? "",
                t.payee,
                t.notes,
            ]
            lines.append(row.map(escape).joined(separator: ","))
        }

        let csv = lines.joined(separator: "\r\n")
        return try write(Data(csv.utf8), named: "Ledgerly-Transactions-\(dateFormatter.string(from: Date())).csv")
    }

    static func write(_ data: Data, named name: String) throws -> URL {
        let fm = FileManager.default
        try fm.createDirectory(at: exportDirectory, withIntermediateDirectories: true, attributes: [.protectionKey: FileProtectionType.complete])
        let url = exportDirectory.appendingPathComponent(name)
        try data.write(to: url, options: [.atomic, .completeFileProtection])
        return url
    }

    /// Removes any exported files left over from a previous session.
    static func purgeTemporaryExports() {
        try? FileManager.default.removeItem(at: exportDirectory)
    }

    static func escape(_ field: String) -> String {
        var value = field
        if let first = value.first, "=+-@\t\r".contains(first) {
            value = "'" + value
        }
        if value.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" || $0 == "\r" }) {
            value = "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return value
    }
}
