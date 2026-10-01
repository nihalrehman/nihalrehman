import Foundation
import SwiftUI

// MARK: - Decimal

extension Decimal {
    var doubleValue: Double { NSDecimalNumber(decimal: self).doubleValue }

    func rounded(_ scale: Int, mode: NSDecimalNumber.RoundingMode = .plain) -> Decimal {
        var input = self
        var result = Decimal()
        NSDecimalRound(&result, &input, scale, mode)
        return result
    }

    func currencyString(_ code: String = AppSettings.currencyCode) -> String {
        formatted(.currency(code: code))
    }
}

extension Sequence {
    func sum(_ value: (Element) -> Decimal) -> Decimal {
        reduce(into: Decimal(0)) { $0 += value($1) }
    }
}

// MARK: - Date

extension Date {
    var startOfMonth: Date {
        Calendar.current.dateInterval(of: .month, for: self)?.start ?? self
    }

    var startOfNextMonth: Date {
        Calendar.current.date(byAdding: .month, value: 1, to: startOfMonth) ?? self
    }

    /// Half-open range covering the whole month containing this date.
    var monthRange: Range<Date> { startOfMonth..<startOfNextMonth }

    var startOfDay: Date { Calendar.current.startOfDay(for: self) }

    func adding(months: Int) -> Date {
        Calendar.current.date(byAdding: .month, value: months, to: self) ?? self
    }

    func adding(days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: days, to: self) ?? self
    }

    var monthTitle: String { formatted(.dateTime.month(.wide).year()) }

    var daysInMonth: Int {
        Calendar.current.range(of: .day, in: .month, for: self)?.count ?? 30
    }
}

// MARK: - Color

extension Color {
    /// Creates a color from "#RRGGBB" or "RRGGBB". Falls back to gray.
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        guard cleaned.count == 6, Scanner(string: cleaned).scanHexInt64(&value) else {
            self = .gray
            return
        }
        self.init(
            .sRGB,
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255,
            opacity: 1
        )
    }
}

enum Palette {
    static let colors: [String] = [
        "#FF453A", "#FF9F0A", "#FFD60A", "#30D158", "#34C759", "#63E6E2",
        "#40C8E0", "#64D2FF", "#0A84FF", "#5E5CE6", "#BF5AF2", "#FF375F",
        "#AC8E68", "#A2845E", "#8E8E93", "#636366",
    ]

    static let icons: [String] = [
        "house.fill", "sofa.fill", "bolt.fill", "drop.fill", "flame.fill", "wifi",
        "fork.knife", "cart.fill", "cup.and.saucer.fill", "takeoutbag.and.cup.and.straw.fill",
        "car.fill", "fuelpump.fill", "bus.fill", "tram.fill", "parkingsign.circle.fill",
        "bag.fill", "tshirt.fill", "desktopcomputer", "gift.fill", "heart.fill",
        "cross.case.fill", "pills.fill", "figure.run", "graduationcap.fill", "book.fill",
        "film.fill", "gamecontroller.fill", "music.note", "airplane", "bed.double.fill",
        "pawprint.fill", "person.2.fill", "creditcard.fill", "building.columns.fill",
        "briefcase.fill", "chart.line.uptrend.xyaxis", "wrench.and.screwdriver.fill",
        "scissors", "leaf.fill", "star.fill", "tag.fill", "ellipsis.circle.fill",
    ]
}

// MARK: - View helpers

struct CardBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

extension View {
    func card() -> some View { modifier(CardBackground()) }
}
