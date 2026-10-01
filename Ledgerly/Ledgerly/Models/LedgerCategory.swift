import Foundation
import SwiftData
import SwiftUI

/// A spending or income category. Categories form a two-level tree:
/// top-level groups (e.g. "Transport") with subcategories (e.g. "Fuel").
@Model
final class LedgerCategory {
    var id: UUID = UUID()
    var name: String = ""
    var icon: String = "tag.fill"
    var colorHex: String = "#8E8E93"
    var kindRaw: String = CategoryKind.expense.rawValue
    var sortOrder: Int = 0
    var isSystem: Bool = false
    var createdAt: Date = Date()

    var parent: LedgerCategory?

    @Relationship(deleteRule: .cascade, inverse: \LedgerCategory.parent)
    var children: [LedgerCategory]? = []

    @Relationship(deleteRule: .nullify, inverse: \TransactionRecord.category)
    var transactions: [TransactionRecord]? = []

    @Relationship(deleteRule: .cascade, inverse: \Budget.category)
    var budgets: [Budget]? = []

    @Relationship(deleteRule: .nullify, inverse: \RecurringRule.category)
    var recurringRules: [RecurringRule]? = []

    init(name: String, icon: String, colorHex: String, kind: CategoryKind, sortOrder: Int = 0, isSystem: Bool = false) {
        self.id = UUID()
        self.name = name
        self.icon = icon
        self.colorHex = colorHex
        self.kindRaw = kind.rawValue
        self.sortOrder = sortOrder
        self.isSystem = isSystem
        self.createdAt = Date()
    }

    var kind: CategoryKind {
        get { CategoryKind(rawValue: kindRaw) ?? .expense }
        set { kindRaw = newValue.rawValue }
    }

    var color: Color { Color(hex: colorHex) }

    var isTopLevel: Bool { parent == nil }

    /// The top-level group this category belongs to (itself if top-level).
    var root: LedgerCategory { parent ?? self }

    var fullName: String {
        if let parent { return "\(parent.name) › \(name)" }
        return name
    }

    var sortedChildren: [LedgerCategory] {
        (children ?? []).sorted { ($0.sortOrder, $0.name) < ($1.sortOrder, $1.name) }
    }

    /// True if `other` is this category or one of its subcategories.
    func encompasses(_ other: LedgerCategory?) -> Bool {
        guard let other else { return false }
        return other.id == id || other.parent?.id == id
    }
}
