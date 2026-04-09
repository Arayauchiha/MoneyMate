import SwiftData
import SwiftUI

@Observable
final class HomeViewModel {
    var totalBalance: Money = .zero
    var expendableAmount: Money = .zero
    var totalIncome: Money = .zero
    var totalExpenses: Money = .zero
    var totalFundedToGoals: Money = .zero
    var savingsRate: Double = 0

    var recentTransactions: [Transaction] = []
    var weeklyChartData: [DailyTotal] = []
    var topCategory: Category?

    var isLoading: Bool = false
    var error: String?

    private var modelContext: ModelContext?

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
            let allTxns = try context.fetch(FetchDescriptor<Transaction>(
                sortBy: [SortDescriptor(\.date, order: .reverse)]
            )).filter { $0.modelContext != nil }

            let activeTxns = allTxns.filter { !$0.isArchived }

            totalIncome = activeTxns.filter { $0.type == .income }.reduce(.zero) { $0 + $1.money }
            totalExpenses = activeTxns.filter { $0.type == .expense }.reduce(.zero) { $0 + $1.money }
            totalFundedToGoals = activeTxns.filter { $0.type == .transfer && $0.linkedGoal != nil }.reduce(.zero) { $0 + $1.money }

            totalBalance = totalIncome - totalExpenses
            expendableAmount = totalBalance - totalFundedToGoals

            let incomeAmount = NSDecimalNumber(decimal: totalIncome.amount).doubleValue
            let expenseAmount = NSDecimalNumber(decimal: totalExpenses.amount).doubleValue
            savingsRate = incomeAmount.isZero ? 0.0 : max(0.0, (incomeAmount - expenseAmount) / incomeAmount)

            recentTransactions = Array(activeTxns.prefix(5))
            weeklyChartData = buildWeeklyChart(from: activeTxns)
            topCategory = findTopCategory(from: activeTxns)

        } catch {
            self.error = error.localizedDescription
        }
    }

    func refresh() {
        Task { await load() }
    }

    private func buildWeeklyChart(from transactions: [Transaction]) -> [DailyTotal] {
        let (start, _) = TimePeriod.week.dateRange
        let calendar = Calendar.current

        return (0 ..< 7).map { offset -> DailyTotal in
            let day = calendar.date(byAdding: .day, value: offset, to: start)!
            let dayStart = calendar.startOfDay(for: day)
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!

            let dayExpenses = transactions
                .filter { $0.type == .expense && $0.date >= dayStart && $0.date < dayEnd }
                .reduce(.zero) { $0 + $1.money }

            return DailyTotal(date: day, total: dayExpenses)
        }
    }

    private func findTopCategory(from transactions: [Transaction]) -> Category? {
        let expenses = transactions.filter { $0.type == .expense }
        let grouped = Dictionary(grouping: expenses, by: { $0.category?.id })
        let top = grouped.max { a, b in
            let sumA = a.value.reduce(Money.zero) { $0 + $1.money }
            let sumB = b.value.reduce(Money.zero) { $0 + $1.money }
            return sumA.amount < sumB.amount
        }
        return top?.value.first?.category
    }
}

struct DailyTotal: Identifiable, Equatable {
    let id = UUID()
    let date: Date
    let total: Money

    static func == (lhs: DailyTotal, rhs: DailyTotal) -> Bool {
        lhs.date == rhs.date && lhs.total.amount == rhs.total.amount
    }

    var dayLabel: String {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return f.string(from: date)
    }
}
