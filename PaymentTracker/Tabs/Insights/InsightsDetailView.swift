import SwiftUI
import Charts
import SwiftData

enum InsightDetailType {
    case totalSpend
    case dailyAverage
    case fundedToGoals
    
    var title: String {
        switch self {
        case .totalSpend: return "Spending Analysis"
        case .dailyAverage: return "Average & Pacing"
        case .fundedToGoals: return "Goal Allocation"
        }
    }
}

struct InsightsDetailView: View {
    let type: InsightDetailType
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var selectedPeriod: TimePeriod = .month
    
    @Environment(InsightsViewModel.self) private var insightsViewModel
    @Environment(AppStateViewModel.self) private var appStateViewModel
    @Environment(TransactionViewModel.self) private var transactionViewModel
    @Environment(\.modelContext) private var modelContext
    @Query private var allTransactions: [Transaction]
    @Query private var allGoals: [Goal]
    
    init(type: InsightDetailType, startDate: Date, endDate: Date) {
        self.type = type
        _startDate = State(initialValue: startDate)
        _endDate = State(initialValue: endDate)
    }

    private var filteredExpenses: [Transaction] {
        allTransactions.filter { 
            $0.type == .expense && 
            $0.date >= startDate && 
            $0.date <= endDate 
        }
    }
    
    private var filteredTransfers: [Transaction] {
        allTransactions.filter { 
            $0.type == .transfer && 
            $0.linkedGoal != nil &&
            $0.date >= startDate && 
            $0.date <= endDate 
        }
    }
    
    private var dailyData: [TrendTotal] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: filteredExpenses) { calendar.startOfDay(for: $0.date) }
        
        var result: [TrendTotal] = []
        var current = calendar.startOfDay(for: startDate)
        let final = calendar.startOfDay(for: endDate)
        
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        
        while current <= final {
            let txns = grouped[current] ?? []
            let total = txns.reduce(Money.zero) { $0 + $1.money }
            result.append(TrendTotal(label: formatter.string(from: current), total: total, date: current))
            guard let next = calendar.date(byAdding: .day, value: 1, to: current) else { break }
            current = next
        }
        return result
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerSummary
                
                switch type {
                case .totalSpend:
                    spendingDeepDive
                case .dailyAverage:
                    pacingDeepDive
                case .fundedToGoals:
                    goalsDeepDive
                }
            }
            .padding()
        }
        .navigationTitle(type.title)
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(uiColor: .systemGroupedBackground))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker("Period", selection: $selectedPeriod) {
                        ForEach(TimePeriod.allCases) { period in
                            Text(period.label).tag(period)
                        }
                    }
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                }
            }
        }
        .onChange(of: selectedPeriod) { _, newPeriod in
            let (start, end) = newPeriod.dateRange
            startDate = start
            endDate = end
        }
        .sheet(isPresented: .init(
            get: { transactionViewModel.isAddEditSheetPresented },
            set: { transactionViewModel.isAddEditSheetPresented = $0 }
        )) {
            AddEditTransactionView(
                mode: transactionViewModel.transactionToEdit.map { .edit($0) } ?? .add
            )
        }
    }
    
    private var headerSummary: some View {
        VStack(spacing: 8) {
            Text(type == .totalSpend ? "Total Period Spend" : (type == .dailyAverage ? "Daily Average" : "Total Goal Funding"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            let amount = computeHeaderAmount()
            Text("\(appStateViewModel.userCurrency)\(amount.formattedPlain)")
                .font(.system(size: 34, weight: .black, design: .rounded))
            
            Text("\(startDate.formatted(.dateTime.day().month())) - \(endDate.formatted(.dateTime.day().month().year()))")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
                .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 5)
        )
    }
    
    private func computeHeaderAmount() -> Money {
        switch type {
        case .totalSpend: return filteredExpenses.reduce(.zero) { $0 + $1.money }
        case .dailyAverage:
            let total = filteredExpenses.reduce(.zero) { $0 + $1.money }
            let days = max(1, Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 1)
            return Money(total.amount / Decimal(days))
        case .fundedToGoals: return filteredTransfers.reduce(.zero) { $0 + $1.money }
        }
    }
    
    private var spendingDeepDive: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Day-by-Day impact")
                .font(.headline)
            
            Chart(dailyData) { trend in
                BarMark(
                    x: .value("Day", trend.label),
                    y: .value("Spent", trend.total.amount)
                )
                .foregroundStyle(.red.gradient)
                .cornerRadius(4)
            }
            .frame(height: 200)
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Most Expensive Purchases")
                    .font(.headline)
                    .padding(.top, 12)
                
                let topTxns = filteredExpenses.sorted { $0.money.amount > $1.money.amount }.prefix(5)
                ForEach(topTxns) { txn in
                    Button {
                        transactionViewModel.presentEdit(txn)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(txn.title.isEmpty ? (txn.category?.name ?? "Miscellaneous") : txn.title)
                                    .font(.subheadline).bold()
                                Text(txn.date.formatted(.dateTime.day().month()))
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("\(appStateViewModel.userCurrency)\(txn.money.formattedPlain)")
                                .font(.subheadline).bold()
                                .foregroundStyle(.primary)
                            
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        .padding()
                        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    private var pacingDeepDive: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Daily Pacing")
                .font(.headline)
            
            let avgValue = computeHeaderAmount().amount
            Chart(dailyData) { trend in
                LineMark(
                    x: .value("Day", trend.label),
                    y: .value("Spent", trend.total.amount)
                )
                .foregroundStyle(.blue.gradient)
                .interpolationMethod(.catmullRom)
                
                RuleMark(y: .value("Average", avgValue))
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
                    .foregroundStyle(.gray.opacity(0.5))
                    .annotation(position: .top, alignment: .trailing) {
                        Text("Avg")
                            .font(.caption2).bold()
                            .foregroundStyle(.secondary)
                            .padding(4)
                            .background(.ultraThinMaterial, in: Capsule())
                    }
            }
            .frame(height: 200)
            
            HStack(spacing: 16) {
                let calendar = Calendar.current
                let weekdayTxns = filteredExpenses.filter { !calendar.isDateInWeekend($0.date) }
                let weekendTxns = filteredExpenses.filter { calendar.isDateInWeekend($0.date) }
                
                StatBox(title: "Weekday Avg", value: calculateAvg(txns: weekdayTxns), color: .blue)
                StatBox(title: "Weekend Avg", value: calculateAvg(txns: weekendTxns), color: .orange)
            }
        }
    }
    
    private func calculateAvg(txns: [Transaction]) -> String {
        let total = txns.reduce(Decimal(0)) { $0 + $1.money.amount }
        let uniqueDays = Set(txns.map { Calendar.current.startOfDay(for: $0.date) }).count
        let avg = uniqueDays > 0 ? total / Decimal(uniqueDays) : 0
        return "\(appStateViewModel.userCurrency)\(Money(avg).formattedPlain)"
    }
    
    private var goalsDeepDive: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Goal Allocation")
                .font(.headline)
            
            let grouped = Dictionary(grouping: filteredTransfers) { $0.linkedGoal?.id }
            let goalStats = grouped.compactMap { id, txns -> (String, Decimal, Color) in
                guard let goal = txns.first?.linkedGoal else { return ("", 0, .gray) }
                return (goal.title, txns.reduce(0) { $0 + $1.money.amount }, .blue)
            }
            
            Chart(goalStats, id: \.0) { item in
                SectorMark(
                    angle: .value("Amount", item.1),
                    innerRadius: .ratio(0.6),
                    angularInset: 2
                )
                .cornerRadius(6)
                .foregroundStyle(by: .value("Goal", item.0))
            }
            .frame(height: 220)
            
            VStack(spacing: 12) {
                ForEach(goalStats.sorted { $0.1 > $1.1 }, id: \.0) { item in
                    HStack {
                        Text(item.0)
                            .font(.subheadline).bold()
                        Spacer()
                        Text("\(appStateViewModel.userCurrency)\(Money(item.1).formattedPlain)")
                            .font(.subheadline).bold()
                            .foregroundStyle(.green)
                    }
                    .padding()
                    .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
                }
            }
        }
    }
}

struct StatBox: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.headline).foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))
    }
}
