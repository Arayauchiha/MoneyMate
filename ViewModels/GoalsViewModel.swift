import SwiftData
import SwiftUI

@Observable
final class GoalsViewModel {
    var goals: [Goal] = []
    var activeGoals: [Goal] = []
    var completedGoals: [Goal] = []

    var goalToEdit: Goal?
    var isGoalFormPresented: Bool = false

    var isLoading: Bool = false
    var error: String?

    private var modelContext: ModelContext?
    private var allTransactions: [Transaction] = []

    func configure(context: ModelContext) {
        modelContext = context
        Task { await load() }
    }

    @MainActor
    func load() async {
        guard let context = modelContext else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let goalDesc = FetchDescriptor<Goal>(
                sortBy: [SortDescriptor(\.deadline, order: .forward)]
            )
            goals = try context.fetch(goalDesc)

            let txnDesc = FetchDescriptor<Transaction>(
                sortBy: [SortDescriptor(\.date, order: .reverse)]
            )
            allTransactions = try context.fetch(txnDesc)

            partitionGoals()

        } catch {
            self.error = error.localizedDescription
        }
    }

    @MainActor
    func add(
        title: String,
        type: GoalType,
        targetAmount: Money,
        deadline: Date,
        blockedCategories: [Category] = []
    ) {
        guard let context = modelContext else { return }
        let goal = Goal(
            title: title,
            type: type,
            targetAmount: targetAmount,
            deadline: deadline,
            blockedCategories: blockedCategories
        )
        context.insert(goal)
        save(context: context)
        Task { await load() }
    }

    @MainActor
    func update(
        goal: Goal,
        title: String,
        targetAmount: Money,
        deadline: Date
    ) {
        goal.title = title
        goal.targetAmount = targetAmount
        goal.deadline = deadline
        guard let context = modelContext else { return }
        save(context: context)
        Task { await load() }
    }

    @MainActor
    func delete(_ goal: Goal) {
        guard let context = modelContext else { return }
        context.delete(goal)
        save(context: context)
        Task { await load() }
    }

    func currentAmount(for goal: Goal) -> Money {
        switch goal.type {
        case .savings:
            let income = allTransactions.filter { $0.type == .income }.reduce(.zero) { $0 + $1.money }
            let expenses = allTransactions.filter { $0.type == .expense }.reduce(.zero) { $0 + $1.money }
            return income - expenses

        case .budgetCap:
            guard !goal.blockedCategoryIDs.isEmpty else { return .zero }
            let now = Date()
            let monthStart = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: now))!
            return allTransactions
                .filter {
                    $0.type == .expense &&
                        $0.date >= monthStart &&
                        goal.blockedCategoryIDs.contains($0.category?.id ?? UUID())
                }
                .reduce(.zero) { $0 + $1.money }

        case .noSpend:
            return Money(goal.currentStreak)
        }
    }

    func status(for goal: Goal) -> GoalStatus {
        goal.status(currentAmount: currentAmount(for: goal))
    }

    func progressFraction(for goal: Goal) -> Double {
        goal.progress(currentAmount: currentAmount(for: goal))
    }

    func progressLabel(for goal: Goal) -> String {
        goal.progressLabel(currentAmount: currentAmount(for: goal))
    }

    func presentAdd() {
        goalToEdit = nil
        isGoalFormPresented = true
    }

    func presentEdit(_ goal: Goal) {
        goalToEdit = goal
        isGoalFormPresented = true
    }

    private func partitionGoals() {
        activeGoals = goals.filter { $0.isActive && !$0.isExpired }
        completedGoals = goals.filter { !$0.isActive || $0.isExpired }
    }

    private func save(context: ModelContext) {
        do {
            try context.save()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
