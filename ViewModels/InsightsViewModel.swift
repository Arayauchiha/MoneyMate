import SwiftData
import SwiftUI

@Observable
final class InsightsViewModel {
    var selectedPeriod: TimePeriod = .month {
        didSet { Task { await load() } }
    }

    var categoryTotals: [CategoryTotal] = []
    var weekComparison: WeekComparison?
    var topCategory: CategoryTotal?
    var totalForPeriod: Money = .zero
    var averagePerDay: Money = .zero
    var monthlyTrend: [MonthlyTotal] = []
    var daysInPeriod: Int = 1

    var isLoading: Bool = false
    var error: String?

    private var modelContext: ModelContext?

    func configure(context: ModelContext) {
        modelContext = context
        Task { await load() }
    }

    @MainActor
    func load() async {
        guard let modelContext else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let descriptor = FetchDescriptor<Transaction>(
                sortBy: [SortDescriptor(\.date, order: .reverse)]
            )
            let allTxns = try modelContext.fetch(descriptor)

            let (start, end) = selectedPeriod.dateRange
            let periodTxns = allTxns.filter { $0.date >= start && $0.date <= end && $0.type == .expense }

            daysInPeriod = max(1, Calendar.current.dateComponents([.day], from: start, to: end).day ?? 1)
            categoryTotals = buildCategoryTotals(from: periodTxns)
            topCategory = categoryTotals.first
            totalForPeriod = periodTxns.reduce(.zero) { $0 + $1.money }
            averagePerDay = computeAveragePerDay(total: totalForPeriod, from: start, to: end)
            weekComparison = buildWeekComparison(from: allTxns)
            monthlyTrend = buildMonthlyTrend(from: allTxns)

        } catch {
            self.error = error.localizedDescription
        }
    }

    private func buildCategoryTotals(from transactions: [Transaction]) -> [CategoryTotal] {
        let grouped = Dictionary(grouping: transactions, by: { $0.category?.id ?? UUID() })
        return grouped
            .map { _, txns -> CategoryTotal in
                let total = txns.reduce(Money.zero) { $0 + $1.money }
                let category = txns.first?.category
                return CategoryTotal(category: category, total: total, transactionCount: txns.count)
            }
            .sorted { $0.total.amount > $1.total.amount }
    }

    private func computeAveragePerDay(total: Money, from start: Date, to end: Date) -> Money {
        let days = max(1, Calendar.current.dateComponents([.day], from: start, to: end).day ?? 1)
        return Money(total.amount / Decimal(days))
    }

    private func buildWeekComparison(from transactions: [Transaction]) -> WeekComparison {
        let calendar = Calendar.current
        let today = Date()
        let thisStart = calendar.date(byAdding: .day, value: -6, to: today)!
        let lastStart = calendar.date(byAdding: .day, value: -13, to: today)!
        let lastEnd = calendar.date(byAdding: .day, value: -7, to: today)!

        let thisWeek = transactions
            .filter { $0.type == .expense && $0.date >= thisStart }
            .reduce(Money.zero) { $0 + $1.money }

        let lastWeek = transactions
            .filter { $0.type == .expense && $0.date >= lastStart && $0.date <= lastEnd }
            .reduce(Money.zero) { $0 + $1.money }

        return WeekComparison(thisWeek: thisWeek, lastWeek: lastWeek)
    }

    private func buildMonthlyTrend(from transactions: [Transaction]) -> [MonthlyTotal] {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yy"

        let expenses = transactions.filter { $0.type == .expense }
        let grouped = Dictionary(
            grouping: expenses,
            by: { calendar.dateComponents([.year, .month], from: $0.date) }
        )

        return grouped
            .map { components, txns -> MonthlyTotal in
                let date = calendar.date(from: components) ?? Date()
                let total = txns.reduce(Money.zero) { $0 + $1.money }
                return MonthlyTotal(month: formatter.string(from: date), total: total, date: date)
            }
            .sorted { $0.date < $1.date }
            .suffix(6)
            .map(\.self)
    }
}

struct CategoryTotal: Identifiable {
    let id = UUID()
    let category: Category?
    let total: Money
    let transactionCount: Int

    var categoryName: String {
        category?.name ?? "Uncategorised"
    }

    var categoryIcon: String {
        category?.iconName ?? "questionmark.circle"
    }

    var categoryColor: Color {
        category?.color ?? .gray
    }

    var formattedTotal: String {
        total.formatted
    }
}

struct WeekComparison {
    let thisWeek: Money
    let lastWeek: Money

    var delta: Money {
        thisWeek - lastWeek
    }

    var percentChange: Double? {
        guard !lastWeek.isZero else { return nil }
        return ((thisWeek.amount - lastWeek.amount) / lastWeek.amount * 100) as NSDecimalNumber as? Double
            ?? ((thisWeek.amount - lastWeek.amount) / lastWeek.amount * 100 as NSDecimalNumber).doubleValue
    }

    var isImproved: Bool {
        thisWeek.amount <= lastWeek.amount
    }
}

struct MonthlyTotal: Identifiable {
    let id = UUID()
    let month: String
    let total: Money
    let date: Date
}
