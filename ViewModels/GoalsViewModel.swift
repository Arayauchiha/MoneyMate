import SwiftData
import SwiftUI

@Observable
final class GoalsViewModel {
    var goals: [Goal] = []
    var activeGoals: [Goal] = []
    var achievedGoals: [Goal] = []
    var completedGoals: [Goal] = []

    var goalToEdit: Goal?
    var isGoalFormPresented: Bool = false

    var isLoading: Bool = false
    var error: String?

    private var modelContext: ModelContext?
    private var appState: AppStateViewModel?
    private var allTransactions: [Transaction] = []
    
    func configure(context: ModelContext, appState: AppStateViewModel) {
        modelContext = context
        self.appState = appState
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
            
            // Persist evaluation results (like notification flags)
            save(context: context)

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
        guard goal.type == .savings else { return }
        // Full signature to avoid "Extra argument" ambiguities
        let transaction = Transaction(
            amount: amount,
            type: .transfer,
            category: nil,
            linkedGoal: goal,
            date: .now,
            title: "Funded: \(goal.title)",
            note: ""
        )
        context.insert(transaction)
        save(context: context)
        Task { await load() }
    }

    private var activeTransactions: [Transaction] {
        allTransactions.filter { $0.modelContext != nil && !$0.isArchived }
    }

    var availableToSave: Money {
        let active = activeTransactions
        let income = active.filter { $0.type == .income }.reduce(Decimal.zero) { $0 + $1.money.amount }
        let expenses = active.filter { $0.type == .expense }.reduce(Decimal.zero) { $0 + $1.money.amount }
        let transferred = active.filter { $0.type == .transfer && $0.linkedGoal != nil }.reduce(Decimal.zero) { $0 + $1.money.amount }
        let diff = income - expenses - transferred
        return Money(max(0, diff))
    }

    var isOverspent: Bool {
        let active = activeTransactions
        let income = active.filter { $0.type == .income }.reduce(Decimal.zero) { $0 + $1.money.amount }
        let expenses = active.filter { $0.type == .expense }.reduce(Decimal.zero) { $0 + $1.money.amount }
        let transferred = active.filter { $0.type == .transfer && $0.linkedGoal != nil }.reduce(Decimal.zero) { $0 + $1.money.amount }
        return (income - expenses - transferred) < 0
    }
    
    var hasNoTransactions: Bool {
        allTransactions.isEmpty
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
                    let hasViolated = activeTransactions.contains { txn in
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
            } else if goal.type == .dailyLimit {
                var successCount = 0
                let start = calendar.startOfDay(for: goal.startDate)
                let today = calendar.startOfDay(for: now)
                let endDate = min(today, calendar.startOfDay(for: goal.deadline))
                
                var date = start
                let blockList = Set(goal.blockedCategoryIDs)
                
                while date <= endDate {
                    let nextDay = calendar.date(byAdding: .day, value: 1, to: date)!
                    let dailyTotal = activeTransactions
                        .filter { txn in
                            txn.type == .expense &&
                            txn.date >= date && txn.date < nextDay &&
                            (blockList.isEmpty || (txn.category.map { blockList.contains($0.id) } ?? false))
                        }
                        .reduce(Decimal(0)) { $0 + $1.money.amount }
                    
                    if dailyTotal <= goal.targetAmount.amount {
                        successCount += 1
                    }
                    date = nextDay
                }
                goal.currentStreak = successCount // Reusing field for successful days
            }
            
            // Check for notifications
            checkThresholds(for: goal)
        }
    }

    private func checkThresholds(for goal: Goal) {
        guard let appState = appState, appState.isGoalAlertsEnabled else { return }
        
        let p = progressFraction(for: goal)
        
        if goal.type == .budgetCap {
            if p >= 0.8 && !goal.hasNotified80 {
                var catName = "Overall Budget"
                if !goal.blockedCategoryIDs.isEmpty {
                    let ids = Set(goal.blockedCategoryIDs)
                    do {
                        let categories = try modelContext?.fetch(FetchDescriptor<Category>()) ?? []
                        let names = categories.filter { ids.contains($0.id) }.map(\.name)
                        if !names.isEmpty {
                            catName = names.joined(separator: ", ")
                        }
                    } catch {}
                }
                NotificationManager.shared.sendThresholdAlert(for: .budget80(catName))
                goal.hasNotified80 = true
            } else if p < 0.8 {
                // Reset flag so user gets warned again if they spend more after cleaning up
                goal.hasNotified80 = false
            }
        } else if goal.type == .savings {
            if p >= 1.0 && !goal.hasNotified100 {
                NotificationManager.shared.sendThresholdAlert(for: .goalFilled(goal.title))
                goal.hasNotified100 = true
                goal.hasNotified90 = true 
            } else if p >= 0.9 && !goal.hasNotified90 {
                NotificationManager.shared.sendThresholdAlert(for: .goal90(goal.title))
                goal.hasNotified90 = true
            }
            
            // Notification Resets for backward progress
            if p < 1.0 {
                goal.hasNotified100 = false
            }
            if p < 0.9 {
                goal.hasNotified90 = false
            }
        }
    }

    func currentAmount(for goal: Goal) -> Money {
        switch goal.type {
        case .savings:
            let transferred = allTransactions
                .filter { !$0.isArchived && $0.linkedGoal?.id == goal.id }
                .reduce(Decimal.zero) { $0 + $1.money.amount }
            return Money(transferred)

        case .budgetCap:
            guard !goal.blockedCategoryIDs.isEmpty else { return .zero }
            let startOfDay = Calendar.current.startOfDay(for: goal.startDate)
            return Money(activeTransactions
                .filter {
                    !$0.isArchived &&
                    $0.type == .expense &&
                    $0.date >= startOfDay && $0.date <= goal.deadline &&
                    goal.blockedCategoryIDs.contains($0.category?.id ?? UUID())
                }
                .reduce(Decimal.zero) { $0 + $1.money.amount })

        case .noSpend, .dailyLimit:
            return Money(Decimal(goal.currentStreak))
        }
    }

    func status(for goal: Goal) -> GoalStatus {
        goal.status(currentAmount: currentAmount(for: goal))
    }

    func progressFraction(for goal: Goal) -> Double {
        goal.progress(currentAmount: currentAmount(for: goal))
    }

    @MainActor
    func progressLabel(for goal: Goal, symbol: String) -> String {
        goal.progressLabel(currentAmount: currentAmount(for: goal), symbol: symbol)
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
        // Active: Not expired AND not reached target
        activeGoals = goals.filter { goal in
            goal.isActive && !goal.isExpired && goal.status(currentAmount: currentAmount(for: goal)) != .achieved
        }
        
        // Achieved: Reached target but not expired
        achievedGoals = goals.filter { goal in
            goal.status(currentAmount: currentAmount(for: goal)) == .achieved && !goal.isExpired
        }
        
        // Completed/Expired: Actually expired or manually deactivated
        completedGoals = goals.filter { goal in
            goal.isExpired || !goal.isActive
        }
    }

    private func save(context: ModelContext) {
        do {
            try context.save()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
