import Foundation
import SwiftData

extension ModelContainer {
    @MainActor
    static func appContainer() throws -> ModelContainer {
        let schema = Schema([
            Transaction.self,
            Category.self,
            Goal.self
        ])

        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true
        )

        let container = try ModelContainer(for: schema, configurations: config)

        seedSystemCategoriesIfNeeded(context: container.mainContext)

        return container
    }

    @MainActor
    private static func seedSystemCategoriesIfNeeded(context: ModelContext) {
        let descriptor = FetchDescriptor<Category>(
            predicate: #Predicate { $0.isSystem == true }
        )
        let existing = (try? context.fetch(descriptor)) ?? []
        guard existing.isEmpty else { return }

        for category in Category.systemCategories {
            context.insert(category)
        }
        try? context.save()
    }
}

extension ModelContainer {
    @MainActor
    static var preview: ModelContainer {
        let schema = Schema([Transaction.self, Category.self, Goal.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: config)
        let ctx = container.mainContext

        let food = Category(name: "Food & dining", iconName: "fork.knife", colorHex: "FF6B6B", isSystem: true, budgetCap: Money(500))
        let salary = Category(name: "Salary", iconName: "briefcase.fill", colorHex: "85C1E9", isSystem: true)
        let transport = Category(name: "Transport", iconName: "car.fill", colorHex: "4ECDC4", isSystem: true, budgetCap: Money(200))
        [food, salary, transport].forEach { ctx.insert($0) }

        let txns: [Transaction] = [
            Transaction(amount: Money(3200), type: .income, category: salary, date: .now.adding(days: -1), note: "Monthly salary"),
            Transaction(amount: Money(45.50), type: .expense, category: food, date: .now.adding(days: -1), note: "Lunch"),
            Transaction(amount: Money(12.00), type: .expense, category: transport, date: .now.adding(days: -2), note: "Metro"),
            Transaction(amount: Money(89.99), type: .expense, category: food, date: .now.adding(days: -3), note: "Grocery run"),
            Transaction(amount: Money(500), type: .income, category: salary, date: .now.adding(days: -5), note: "Freelance"),
            Transaction(amount: Money(34.00), type: .expense, category: transport, date: .now.adding(days: -6), note: "Cab")
        ]
        txns.forEach { ctx.insert($0) }

        let goal1 = Goal(title: "Emergency fund", type: .savings, targetAmount: Money(10000), deadline: .now.adding(days: 180))
        let goal2 = Goal(title: "No takeout in July", type: .noSpend, targetAmount: .zero, deadline: .now.adding(days: 20), blockedCategories: [food])
        let goal3 = Goal(title: "Keep food under ₹500", type: .budgetCap, targetAmount: Money(500), deadline: .now.adding(days: 30))
        [goal1, goal2, goal3].forEach { ctx.insert($0) }

        try? ctx.save()
        return container
    }
}
