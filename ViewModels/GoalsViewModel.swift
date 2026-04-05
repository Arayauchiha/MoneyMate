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

            evaluateGoals()
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
        startDate: Date = .now,
        deadline: Date,
        blockedCategories: [Category] = []
    ) {
        guard let context = modelContext else { return }
        // Using explicit init order to aid compiler
        let goal = Goal(
            title: title,
            type: type,
            targetAmount: targetAmount,
            startDate: startDate,
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
        startDate: Date,
        deadline: Date,
        blockedCategories: [Category]
    ) {
        goal.title = title
        goal.targetAmount = targetAmount
        goal.startDate = startDate
        goal.deadline = deadline
        goal.blockedCategoryIDs = blockedCategories.map { $0.id }
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

    @MainActor
    func fund(goal: Goal, amount: Money) {
        guard let context = modelContext else { return }
        // Full signature to avoid "Extra argument" ambiguities
        let transaction = Transaction(
            amount: amount,
            type: .transfer,
            category: nil,
            linkedGoal: goal,
            date: .now,
            note: "Funded \(goal.title)"
        )
        context.insert(transaction)
        save(context: context)
        Task { await load() }
    }

    var availableToSave: Money {
        let income = allTransactions.filter { $0.type == .income }.reduce(Decimal.zero) { $0 + $1.money.amount }
        let expenses = allTransactions.filter { $0.type == .expense }.reduce(Decimal.zero) { $0 + $1.money.amount }
        let transferred = allTransactions.filter { $0.type == .transfer && $0.linkedGoal != nil }.reduce(Decimal.zero) { $0 + $1.money.amount }
        return Money(income - expenses - transferred)
    }

    private func evaluateGoals() {
        let now = Date()
        let calendar = Calendar.current
        for goal in goals {
            if goal.type == .noSpend {
                var streak = 0
                var longest = 0
                let start = calendar.startOfDay(for: goal.startDate)
                let today = calendar.startOfDay(for: now)
                let endDate = min(today, calendar.startOfDay(for: goal.deadline))
                
                var date = start
                let blockList = Set(goal.blockedCategoryIDs)
                
                while date <= endDate {
                    let nextDay = calendar.date(byAdding: .day, value: 1, to: date)!
                    let hasViolated = allTransactions.contains { txn in
                        txn.type == .expense &&
                        txn.date >= date && txn.date < nextDay &&
                        (txn.category.map { blockList.contains($0.id) } ?? false)
                    }
                    if hasViolated {
                        streak = 0
                    } else {
                        streak += 1
                        longest = max(longest, streak)
                    }
                    date = nextDay
                }
                goal.currentStreak = streak
                goal.longestStreak = max(goal.longestStreak, longest)
            }
        }
    }

    func currentAmount(for goal: Goal) -> Money {
        switch goal.type {
        case .savings:
            let transferred = allTransactions
                .filter { $0.linkedGoal?.id == goal.id }
                .reduce(Decimal.zero) { $0 + $1.money.amount }
            return Money(transferred)

        case .budgetCap:
            guard !goal.blockedCategoryIDs.isEmpty else { return .zero }
            return Money(allTransactions
                .filter {
                    $0.type == .expense &&
                    $0.date >= goal.startDate && $0.date <= goal.deadline &&
                    goal.blockedCategoryIDs.contains($0.category?.id ?? UUID())
                }
                .reduce(Decimal.zero) { $0 + $1.money.amount })

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
