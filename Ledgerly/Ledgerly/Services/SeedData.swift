import Foundation
import SwiftData

/// Default categories and accounts created on first launch. Users can rename,
/// recolor, delete or add to all of these.
enum SeedData {
    typealias Sub = (name: String, icon: String)

    static let expenseGroups: [(name: String, icon: String, color: String, subs: [Sub])] = [
        ("Housing", "house.fill", "#5E5CE6", [
            ("Rent", "key.fill"),
            ("Mortgage Payment", "house.fill"),
            ("Property Tax", "building.columns.fill"),
            ("Home Insurance", "shield.fill"),
            ("Maintenance & Repairs", "wrench.and.screwdriver.fill"),
            ("HOA / Service Charges", "building.2.fill"),
        ]),
        ("Household", "sofa.fill", "#BF5AF2", [
            ("Furniture", "sofa.fill"),
            ("Appliances", "washer.fill"),
            ("Home Supplies", "basket.fill"),
            ("Cleaning & Laundry", "sparkles"),
            ("Decor & Garden", "leaf.fill"),
            ("Domestic Help", "person.fill"),
        ]),
        ("Utilities", "bolt.fill", "#FFD60A", [
            ("Electricity", "bolt.fill"),
            ("Water", "drop.fill"),
            ("Gas", "flame.fill"),
            ("Internet", "wifi"),
            ("Mobile Phone", "iphone"),
            ("TV & Streaming", "tv.fill"),
        ]),
        ("Food & Dining", "fork.knife", "#FF9F0A", [
            ("Groceries", "cart.fill"),
            ("Eating Out", "fork.knife"),
            ("Coffee & Snacks", "cup.and.saucer.fill"),
            ("Food Delivery", "takeoutbag.and.cup.and.straw.fill"),
        ]),
        ("Transport", "car.fill", "#0A84FF", [
            ("Fuel", "fuelpump.fill"),
            ("Public Transit", "tram.fill"),
            ("Taxi & Rideshare", "car.fill"),
            ("Parking & Tolls", "parkingsign.circle.fill"),
            ("Car Maintenance", "wrench.and.screwdriver.fill"),
            ("Car Insurance", "shield.fill"),
            ("Car Loan Payment", "car.fill"),
            ("Registration & Fines", "doc.text.fill"),
        ]),
        ("Shopping", "bag.fill", "#FF375F", [
            ("Clothing & Shoes", "tshirt.fill"),
            ("Electronics", "desktopcomputer"),
            ("Personal Care", "scissors"),
            ("Online Shopping", "shippingbox.fill"),
            ("Gifts", "gift.fill"),
        ]),
        ("Health", "heart.fill", "#FF453A", [
            ("Doctor & Hospital", "stethoscope"),
            ("Pharmacy", "pills.fill"),
            ("Health Insurance", "cross.case.fill"),
            ("Dental & Vision", "eye.fill"),
            ("Fitness & Gym", "figure.run"),
        ]),
        ("Education", "graduationcap.fill", "#64D2FF", [
            ("Tuition & School Fees", "graduationcap.fill"),
            ("Books & Supplies", "book.fill"),
            ("Courses & Training", "laptopcomputer"),
        ]),
        ("Entertainment", "film.fill", "#30D158", [
            ("Movies & Events", "ticket.fill"),
            ("Hobbies", "paintbrush.fill"),
            ("Subscriptions", "repeat"),
            ("Games", "gamecontroller.fill"),
        ]),
        ("Travel", "airplane", "#40C8E0", [
            ("Flights", "airplane"),
            ("Hotels", "bed.double.fill"),
            ("Vacation Spending", "sun.max.fill"),
            ("Visa & Travel Docs", "doc.text.fill"),
        ]),
        ("Family & Kids", "person.2.fill", "#AC8E68", [
            ("Childcare", "figure.and.child.holdinghands"),
            ("Kids Activities", "soccerball"),
            ("Allowance", "banknote.fill"),
            ("Family Support", "heart.circle.fill"),
        ]),
        ("Pets", "pawprint.fill", "#A2845E", [
            ("Pet Food", "pawprint.fill"),
            ("Vet", "cross.case.fill"),
            ("Pet Supplies", "bag.fill"),
        ]),
        ("Debt Payments", "creditcard.fill", "#8E8E93", [
            ("Credit Card Payment", "creditcard.fill"),
            ("Personal Loan Payment", "person.fill"),
            ("Student Loan Payment", "graduationcap.fill"),
            ("Other Debt Payment", "doc.text.fill"),
        ]),
        ("Financial & Fees", "building.columns.fill", "#636366", [
            ("Bank Fees", "building.columns.fill"),
            ("Taxes", "percent"),
            ("Life Insurance", "shield.fill"),
            ("Professional Services", "briefcase.fill"),
        ]),
        ("Giving", "gift.fill", "#32ADE6", [
            ("Charity & Donations", "hand.raised.fill"),
            ("Gifts to Others", "gift.fill"),
        ]),
        ("Miscellaneous", "ellipsis.circle.fill", "#98989D", [
            ("Other", "questionmark.circle.fill"),
        ]),
    ]

    static let incomeCategories: [(name: String, icon: String, color: String)] = [
        ("Salary", "briefcase.fill", "#34C759"),
        ("Bonus & Commission", "star.fill", "#30D158"),
        ("Business & Freelance", "laptopcomputer", "#63E6E2"),
        ("Investments & Dividends", "chart.line.uptrend.xyaxis", "#0A84FF"),
        ("Rental Income", "house.fill", "#5E5CE6"),
        ("Refunds & Cashback", "arrow.uturn.backward.circle.fill", "#FF9F0A"),
        ("Gifts Received", "gift.fill", "#FF375F"),
        ("Other Income", "plus.circle.fill", "#8E8E93"),
    ]

    @MainActor
    static func seedIfNeeded(_ context: ModelContext, force: Bool = false) {
        let defaults = UserDefaults.standard
        let existing = (try? context.fetchCount(FetchDescriptor<LedgerCategory>())) ?? 0
        guard force || (!defaults.bool(forKey: SettingsKey.didSeed) && existing == 0) else { return }

        seedCategories(context)

        let cash = Account(name: "Cash", type: .cash, colorHex: "#30D158", sortOrder: 0)
        let bank = Account(name: "Bank Account", type: .checking, colorHex: "#0A84FF", sortOrder: 1)
        context.insert(cash)
        context.insert(bank)

        try? context.save()
        defaults.set(true, forKey: SettingsKey.didSeed)
    }

    @MainActor
    static func seedCategories(_ context: ModelContext) {
        for (groupIndex, group) in expenseGroups.enumerated() {
            let parent = LedgerCategory(name: group.name, icon: group.icon, colorHex: group.color, kind: .expense, sortOrder: groupIndex, isSystem: true)
            context.insert(parent)
            for (subIndex, sub) in group.subs.enumerated() {
                let child = LedgerCategory(name: sub.name, icon: sub.icon, colorHex: group.color, kind: .expense, sortOrder: subIndex, isSystem: true)
                context.insert(child)
                child.parent = parent
            }
        }
        for (index, item) in incomeCategories.enumerated() {
            let category = LedgerCategory(name: item.name, icon: item.icon, colorHex: item.color, kind: .income, sortOrder: index, isSystem: true)
            context.insert(category)
        }
    }
}
