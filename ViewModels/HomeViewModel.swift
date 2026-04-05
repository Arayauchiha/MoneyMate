import SwiftData
import SwiftUI

@Observable
final class HomeViewModel {
    var totalBalance: Money = .zero
    var expendableAmount: Money = .zero
    var totalIncome: Money = .zero
    var totalExpenses: Money = .zero
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
            ))

            totalIncome = allTxns.filter { $0.type == .income }.reduce(.zero) { $0 + $1.money }
            totalExpenses = allTxns.filter { $0.type == .expense }.reduce(.zero) { $0 + $1.money }
            let totalTransfers = allTxns.filter { $0.type == .transfer && $0.linkedGoal != nil }.reduce(.zero) { $0 + $1.money }
            
            totalBalance = totalIncome - totalExpenses
            expendableAmount = totalBalance - totalTransfers
            savingsRate = totalIncome.isZero ? 0.0 : max(0.0, (totalIncome - totalExpenses).amount / totalIncome.amount).doubleValue

            recentTransactions = Array(allTxns.prefix(5))
            weeklyChartData = buildWeeklyChart(from: allTxns)
            topCategory = findTopCategory(from: allTxns)

        } catch {
            self.error = error.localizedDescription
        }
    }

    func refresh() {
        Task { await load() }
    }

    private func buildWeeklyChart(from transactions: [Transaction]) -> [DailyTotal] {
        let calendar = Calendar.current
        let today = Date()

        return (0 ..< 7).reversed().map { offset -> DailyTotal in
            let day = calendar.date(byAdding: .day, value: -offset, to: today)!
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

struct DailyTotal: Identifiable {
    let id = UUID()
    let date: Date
    let total: Money

    var dayLabel: String {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return f.string(from: date)
    }
}
