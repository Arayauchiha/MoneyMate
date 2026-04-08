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
    var totalFundedToGoals: Money = .zero
    var averagePerDay: Money = .zero
    var monthlyTrend: [TrendTotal] = []
    var weeklyTrend: [TrendTotal] = []
    var dailyTrend: [TrendTotal] = []
    var monthlyComparisonTrends: [ComparisonTrend] = []
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
            let allTxns = try modelContext.fetch(descriptor).filter { $0.modelContext != nil }
            let activeTxns = allTxns.filter { !$0.isArchived }

            let (start, end) = selectedPeriod.dateRange
            let periodTxns = activeTxns.filter { $0.date >= start && $0.date <= end && $0.type == .expense }

            daysInPeriod = max(1, Calendar.current.dateComponents([.day], from: start, to: end).day ?? 1)
            categoryTotals = buildCategoryTotals(from: periodTxns)
            topCategory = categoryTotals.first
            totalForPeriod = periodTxns.reduce(.zero) { $0 + $1.money }
            totalFundedToGoals = activeTxns
                .filter { $0.date >= start && $0.date <= end && $0.type == .transfer && $0.linkedGoal != nil }
                .reduce(.zero) { $0 + $1.money }
            
            averagePerDay = computeAveragePerDay(total: totalForPeriod, from: start, to: end)
            weekComparison = buildWeekComparison(from: activeTxns)
            monthlyTrend = buildMonthlyTrend(from: activeTxns)
            weeklyTrend = buildWeeklyTrend(from: activeTxns)
            dailyTrend = buildDailyTrend(from: activeTxns)
            monthlyComparisonTrends = buildMonthlyComparisonTrends(from: activeTxns)

        } catch {
            self.error = error.localizedDescription
        }
    }

    private func buildCategoryTotals(from transactions: [Transaction]) -> [CategoryTotal] {
        let uncategorisedID = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
        let grouped = Dictionary(grouping: transactions, by: { $0.category?.id ?? uncategorisedID })
        return grouped
            .map { _, txns -> CategoryTotal in
                let total = txns.reduce(Money.zero) { $0 + $1.money }
                let category = txns.first { $0.category != nil }?.category
                return CategoryTotal(category: category, total: total, transactionCount: txns.count)
            }
            .sorted { $0.total.amount > $1.total.amount }
    }

    private func computeAveragePerDay(total: Money, from start: Date, to end: Date) -> Money {
        let days = max(1, Calendar.current.dateComponents([.day], from: start, to: end).day ?? 1)
        return Money(total.amount / Decimal(days))
    }

    private func buildWeekComparison(from transactions: [Transaction]) -> WeekComparison {
        let (thisStart, _) = TimePeriod.week.dateRange
        let lastStart = Calendar.current.date(byAdding: .day, value: -7, to: thisStart)!
        let lastEnd = Calendar.current.date(byAdding: .day, value: -1, to: thisStart)!

        let thisWeek = transactions
            .filter { $0.type == .expense && $0.date >= thisStart }
            .reduce(Money.zero) { $0 + $1.money }

        let lastWeek = transactions
            .filter { $0.type == .expense && $0.date >= lastStart && $0.date <= lastEnd }
            .reduce(Money.zero) { $0 + $1.money }

        return WeekComparison(thisWeek: thisWeek, lastWeek: lastWeek)
    }

    private func buildMonthlyTrend(from transactions: [Transaction]) -> [TrendTotal] {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"

        let expenses = transactions.filter { $0.type == .expense }
        let grouped = Dictionary(
            grouping: expenses,
            by: { calendar.dateComponents([.year, .month], from: $0.date) }
        )

        return grouped
            .map { components, txns -> TrendTotal in
                let date = calendar.date(from: components) ?? Date()
                let total = txns.reduce(Money.zero) { $0 + $1.money }
                return TrendTotal(label: formatter.string(from: date), total: total, date: date)
            }
            .sorted { $0.date < $1.date }
            .suffix(6)
            .map(\.self)
    }

    private func buildWeeklyTrend(from transactions: [Transaction]) -> [TrendTotal] {
        let calendar = Calendar.current
        let expenses = transactions.filter { $0.type == .expense }
        
        let grouped = Dictionary(
            grouping: expenses,
            by: { calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: $0.date) }
        )
        
        return grouped
            .map { components, txns -> TrendTotal in
                let date = calendar.date(from: components) ?? Date()
                let total = txns.reduce(Money.zero) { $0 + $1.money }
                return TrendTotal(label: "W\(calendar.component(.weekOfYear, from: date))", total: total, date: date)
            }
            .sorted { $0.date < $1.date }
            .suffix(8)
            .map(\.self)
    }

    private func buildDailyTrend(from transactions: [Transaction]) -> [TrendTotal] {
        let calendar = Calendar.current
        let today = Date()
        let cutoff = calendar.date(byAdding: .day, value: -14, to: today)! // Last 14 days
        let expenses = transactions.filter { $0.type == .expense && $0.date >= cutoff }
        
        let grouped = Dictionary(
            grouping: expenses,
            by: { calendar.startOfDay(for: $0.date) }
        )
        
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        
        return grouped
            .map { date, txns -> TrendTotal in
                let total = txns.reduce(Money.zero) { $0 + $1.money }
                return TrendTotal(label: formatter.string(from: date), total: total, date: date)
            }
            .sorted { $0.date < $1.date }
    }
    private func buildMonthlyComparisonTrends(from transactions: [Transaction]) -> [ComparisonTrend] {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"

        let grouped = Dictionary(
            grouping: transactions,
            by: { calendar.dateComponents([.year, .month], from: $0.date) }
        )

        return grouped
            .map { components, txns -> ComparisonTrend in
                let date = calendar.date(from: components) ?? Date()
                let income = txns.filter { $0.type == .income }.reduce(Money.zero) { $0 + $1.money }
                let expense = txns.filter { $0.type == .expense }.reduce(Money.zero) { $0 + $1.money }
                return ComparisonTrend(label: formatter.string(from: date), income: income, expense: expense, date: date)
            }
            .sorted { $0.date < $1.date }
            .suffix(6)
            .map(\.self)
    }
}

struct ComparisonTrend: Identifiable, Hashable {
    let id = UUID()
    let label: String
    let income: Money
    let expense: Money
    let date: Date
    
    var savings: Money {
        income - expense
    }
}

struct CategoryTotal: Identifiable, Equatable {
    let id: UUID
    let category: Category?
    let total: Money
    let transactionCount: Int

    init(category: Category?, total: Money, transactionCount: Int) {
        self.category = category
        self.total = total
        self.transactionCount = transactionCount
        // Stable ID based on category; 0000... for "Other"
        self.id = category?.id ?? UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
    }

    static func == (lhs: CategoryTotal, rhs: CategoryTotal) -> Bool {
        lhs.id == rhs.id && lhs.total == rhs.total && lhs.transactionCount == rhs.transactionCount
    }

    var categoryName: String {
        category?.name ?? "Miscellaneous"
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

struct TrendTotal: Identifiable, Hashable {
    let id = UUID()
    let label: String
    let total: Money
    let date: Date
}
