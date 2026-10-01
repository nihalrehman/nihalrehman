import Foundation
import SwiftData
import SwiftUI

/// Something being saved for: emergency fund, house deposit, holiday, new car...
@Model
final class SavingsGoal {
    var id: UUID = UUID()
    var name: String = ""
    var icon: String = "star.fill"
    var colorHex: String = "#30D158"
    var targetAmount: Decimal = 0
    var savedAmount: Decimal = 0
    var targetDate: Date?
    var notesCipher: Data?
    var createdAt: Date = Date()

    init(name: String, icon: String, colorHex: String, targetAmount: Decimal, savedAmount: Decimal = 0, targetDate: Date? = nil) {
        self.id = UUID()
        self.name = name
        self.icon = icon
        self.colorHex = colorHex
        self.targetAmount = targetAmount
        self.savedAmount = savedAmount
        self.targetDate = targetDate
        self.createdAt = Date()
    }

    var color: Color { Color(hex: colorHex) }

    var notes: String {
        get { FieldCrypto.open(notesCipher) }
        set { notesCipher = FieldCrypto.seal(newValue) }
    }

    var progress: Double {
        guard targetAmount > 0 else { return 0 }
        return min(savedAmount.doubleValue / targetAmount.doubleValue, 1)
    }

    var remaining: Decimal { max(targetAmount - savedAmount, 0) }

    var isComplete: Bool { savedAmount >= targetAmount && targetAmount > 0 }

    /// Monthly contribution needed to hit the target by `targetDate`.
    var requiredMonthlyContribution: Decimal? {
        guard let targetDate, remaining > 0 else { return nil }
        let months = Calendar.current.dateComponents([.month], from: Date(), to: targetDate).month ?? 0
        guard months > 0 else { return remaining }
        return (remaining / Decimal(months)).rounded(2)
    }
}
