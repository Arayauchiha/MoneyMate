import Foundation
import SwiftData
import SwiftUI

@Model
final class Category {
    var id: UUID
    var name: String
    var iconName: String
    var colorHex: String
    var isSystem: Bool

    private var budgetCapRaw: String?

    @Relationship(deleteRule: .nullify, inverse: \Transaction.category)
    var transactions: [Transaction] = []

    init(
        id: UUID = .init(),
        name: String,
        iconName: String,
        colorHex: String,
        isSystem: Bool = false,
        budgetCap: Money? = nil
    ) {
        self.id = id
        self.name = name
        self.iconName = iconName
        self.colorHex = colorHex
        self.isSystem = isSystem
        budgetCapRaw = budgetCap.map { "\($0.amount)" }
    }

    var budgetCap: Money? {
        get {
            guard let raw = budgetCapRaw, let d = Decimal(string: raw) else { return nil }
            return Money(d)
        }
        set { budgetCapRaw = newValue.map { "\($0.amount)" } }
    }

    var color: Color {
        Color(hex: colorHex)
    }

    var totalExpenses: Money {
        transactions
            .filter { $0.type == .expense }
            .reduce(.zero) { $0 + $1.money }
    }

    var budgetUsedFraction: Double? {
        guard let cap = budgetCap, !cap.isZero else { return nil }
        let fraction = (totalExpenses.amount / cap.amount) as NSDecimalNumber
        return min(fraction.doubleValue, 1.0)
    }
}

extension Category {
    @MainActor static let systemCategories: [Category] = [
        Category(name: "Food & dining", iconName: "fork.knife", colorHex: "FF4757", isSystem: true),
        Category(name: "Transport", iconName: "car.fill", colorHex: "2ED573", isSystem: true),
        Category(name: "Shopping", iconName: "bag.fill", colorHex: "1E90FF", isSystem: true),
        Category(name: "Housing", iconName: "house.fill", colorHex: "70a1ff", isSystem: true),
        Category(name: "Health", iconName: "heart.fill", colorHex: "FF6B6B", isSystem: true),
        Category(name: "Entertainment", iconName: "tv.fill", colorHex: "A55EEA", isSystem: true),
        Category(name: "Utilities", iconName: "bolt.fill", colorHex: "ECCC68", isSystem: true),
        Category(name: "Education", iconName: "book.fill", colorHex: "FF7F50", isSystem: true),
        Category(name: "Travel", iconName: "airplane", colorHex: "2bcbba", isSystem: true),
        Category(name: "Salary", iconName: "briefcase.fill", colorHex: "20bf6b", isSystem: true),
        Category(name: "Freelance", iconName: "laptopcomputer", colorHex: "f7b731", isSystem: true),
        Category(name: "Miscellaneous", iconName: "ellipsis.circle.fill", colorHex: "BDC3C7", isSystem: true)
    ]
}
