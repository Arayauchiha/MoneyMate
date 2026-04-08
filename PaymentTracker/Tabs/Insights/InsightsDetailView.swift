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

    var icon: String {
        switch self {
        case .totalSpend: return "arrow.down.circle.fill"
        case .dailyAverage: return "chart.line.uptrend.xyaxis.circle.fill"
        case .fundedToGoals: return "target"
        }
    }

    var accentColor: Color {
        switch self {
        case .totalSpend: return .red
        case .dailyAverage: return .blue
        case .fundedToGoals: return .green
        }
    }
}

struct InsightsDetailView: View {
    let type: InsightDetailType
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var selectedPeriod: TimePeriod = .week
    @State private var weekdayDrillShown = false
    @State private var weekendDrillShown = false

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
        // Infer the initial period from the date range length
        let days = Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 0
        if days <= 7 { _selectedPeriod = State(initialValue: .week) }
        else if days <= 31 { _selectedPeriod = State(initialValue: .month) }
        else { _selectedPeriod = State(initialValue: .year) }
    }

    private var filteredExpenses: [Transaction] {
        allTransactions.filter {
            !$0.isArchived &&
            $0.type == .expense &&
            $0.date >= startDate &&
            $0.date <= endDate
        }
    }

    private var filteredTransfers: [Transaction] {
        allTransactions.filter {
            !$0.isArchived &&
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

    private var headerAmount: Money {
        switch type {
        case .totalSpend: return filteredExpenses.reduce(.zero) { $0 + $1.money }
        case .dailyAverage:
            let total = filteredExpenses.reduce(.zero) { $0 + $1.money }
            let days = max(1, Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 1)
            return Money(total.amount / Decimal(days))
        case .fundedToGoals: return filteredTransfers.reduce(.zero) { $0 + $1.money }
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Hero Header Card
                heroHeader

                // Type-specific content
                switch type {
                case .totalSpend:   spendingDeepDive
                case .dailyAverage: pacingDeepDive
                case .fundedToGoals: goalsDeepDive
                }
            }
            .padding()
        }
        .navigationTitle(type.title)
        .navigationBarTitleDisplayMode(.inline)
        .background(FintechDesign.Background())
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker("Period", selection: $selectedPeriod) {
                        ForEach(TimePeriod.allCases) { period in
                            Text(period.label).tag(period)
                        }
                    }
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.headline)
                }
            }
        }
        .onChange(of: selectedPeriod) { _, newPeriod in
            let (start, end) = newPeriod.dateRange
            startDate = start
            endDate = end
        }
    }

    // MARK: - Hero Header

    private var heroHeader: some View {
        VStack(spacing: 0) {
            // Icon + Label row
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(type.accentColor.opacity(0.15))
                        .frame(width: 56, height: 56)
                    Image(systemName: type.icon)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(type.accentColor)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(type == .totalSpend ? "Total Period Spent"
                         : type == .dailyAverage ? "Daily Average"
                         : "Total Goal Funding")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.5)

                    Text(headerAmount.formatted(with: appStateViewModel.userCurrency))
                        .font(.system(size: 30, weight: .black, design: .rounded))
                        .foregroundStyle(FintechDesign.primaryText)
                        .contentTransition(.numericText())
                }

                Spacer()
            }

            Divider().padding(.vertical, 16)

            // Period badge row
            HStack {
                Label(
                    "\(startDate.formatted(.dateTime.day().month())) – \(endDate.formatted(.dateTime.day().month().year()))",
                    systemImage: "calendar"
                )
                .font(.caption.bold())
                .foregroundStyle(.secondary)

                Spacer()

                // Quick stat badge
                let count = type == .fundedToGoals ? filteredTransfers.count : filteredExpenses.count
                Text("\(count) \(count == 1 ? "transaction" : "transactions")")
                    .font(.caption.bold())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(type.accentColor.opacity(0.12), in: Capsule())
                    .foregroundStyle(type.accentColor)
            }
        }
        .padding(24)
        .background(
            FintechDesign.CardBackground()
                .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .strokeBorder(type.accentColor.opacity(0.15), lineWidth: 1)
                )
        )
    }

    // MARK: - Total Spend Deep Dive

    private var spendingDeepDive: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Chart card (untouched as requested)
            VStack(alignment: .leading, spacing: 16) {
                Text("Day-by-Day Impact")
                    .font(.headline)
                    .foregroundStyle(FintechDesign.primaryText)

                Chart(dailyData) { trend in
                    BarMark(
                        x: .value("Day", trend.date, unit: .day),
                        y: .value("Spent", trend.total.amount)
                    )
                    .foregroundStyle(.red.gradient)
                    .cornerRadius(4)
                }
                .frame(height: 200)

            }
            .padding(24)
            .background(
                FintechDesign.CardBackground()
                    .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
            )

            // Top purchases card
            VStack(alignment: .leading, spacing: 16) {
                Text("Most Expensive Purchases")
                    .font(.headline)
                    .foregroundStyle(FintechDesign.primaryText)

                let topTxns = filteredExpenses.sorted { $0.money.amount > $1.money.amount }.prefix(5)

                if topTxns.isEmpty {
                    emptyState(icon: "cart", message: "No purchases in this period")
                } else {
                    VStack(spacing: 10) {
                        ForEach(Array(topTxns.enumerated()), id: \.element.id) { rank, txn in
                            Button {
                                transactionViewModel.presentEdit(txn)
                            } label: {
                                HStack(spacing: 14) {
                                    // Rank badge
                                    Text("#\(rank + 1)")
                                        .font(.caption.bold())
                                        .foregroundStyle(rank == 0 ? .orange : .secondary)
                                        .frame(width: 28)

                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(txn.title.isEmpty ? (txn.category?.name ?? "Miscellaneous") : txn.title)
                                            .font(.subheadline.bold())
                                            .foregroundStyle(FintechDesign.primaryText)
                                        Text(txn.date.formatted(.dateTime.day().month().year()))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    Text(txn.money.formatted(with: appStateViewModel.userCurrency))
                                        .font(.subheadline.bold())
                                        .foregroundStyle(.red)

                                    Image(systemName: "pencil.circle.fill")
                                        .font(.system(size: 18))
                                        .foregroundStyle(.quaternary)
                                }
                                .padding(14)
                                .background(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(Color.red.opacity(0.04))
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(24)
            .background(
                FintechDesign.CardBackground()
                    .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
            )
        }
    }

    // MARK: - Daily Average Deep Dive

    private var pacingDeepDive: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Chart card (untouched as requested)
            VStack(alignment: .leading, spacing: 16) {
                Text("Daily Pacing")
                    .font(.headline)
                    .foregroundStyle(FintechDesign.primaryText)

                let avgValue = headerAmount.amount
                Chart(dailyData) { trend in
                    LineMark(
                        x: .value("Day", trend.date, unit: .day),
                        y: .value("Spent", trend.total.amount)
                    )
                    .foregroundStyle(.blue.gradient)
                    .interpolationMethod(.catmullRom)

                    RuleMark(y: .value("Average", avgValue))
                        .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
                        .foregroundStyle(.gray.opacity(0.5))
                        .annotation(position: .top, alignment: .trailing) {
                            Text("Avg")
                                .font(.caption2.bold())
                                .foregroundStyle(.secondary)
                                .padding(4)
                                .background(.ultraThinMaterial, in: Capsule())
                        }
                }
                .frame(height: 200)

            }
            .padding(24)
            .background(
                FintechDesign.CardBackground()
                    .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
            )

            // Weekday vs Weekend stat cards (tappable drill-down)
            let calendar = Calendar.current
            let weekdayTxns = filteredExpenses.filter { !calendar.isDateInWeekend($0.date) }
            let weekendTxns = filteredExpenses.filter { calendar.isDateInWeekend($0.date) }

            HStack(spacing: 14) {
                // Weekday card
                Button { weekdayDrillShown = true } label: {
                    premiumStatCard(
                        title: "Weekday Avg",
                        value: calculateAvg(txns: weekdayTxns),
                        subtitle: "\(weekdayTxns.count) transactions",
                        color: .blue,
                        icon: "briefcase.fill"
                    )
                }
                .buttonStyle(.plain)
                .sheet(isPresented: $weekdayDrillShown) {
                    txnDrillSheet(title: "Weekday Transactions", txns: weekdayTxns, color: .blue)
                }

                // Weekend card
                Button { weekendDrillShown = true } label: {
                    premiumStatCard(
                        title: "Weekend Avg",
                        value: calculateAvg(txns: weekendTxns),
                        subtitle: "\(weekendTxns.count) transactions",
                        color: .orange,
                        icon: "sun.max.fill"
                    )
                }
                .buttonStyle(.plain)
                .sheet(isPresented: $weekendDrillShown) {
                    txnDrillSheet(title: "Weekend Transactions", txns: weekendTxns, color: .orange)
                }
            }
        }
    }

    private func premiumStatCard(title: String, value: String, subtitle: String, color: Color, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(color)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.quaternary)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.3)
                Text(value)
                    .font(.title3.bold())
                    .foregroundStyle(color)
                    .contentTransition(.numericText())
            }

            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(
            FintechDesign.CardBackground()
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(color.opacity(0.2), lineWidth: 1)
                )
        )
    }

    @ViewBuilder
    private func txnDrillSheet(title: String, txns: [Transaction], color: Color) -> some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    if txns.isEmpty {
                        emptyState(icon: "tray", message: "No transactions")
                            .padding(.top, 60)
                    } else {
                        ForEach(txns.sorted { $0.date > $1.date }) { txn in
                            Button { transactionViewModel.presentEdit(txn) } label: {
                                HStack(spacing: 14) {
                                    Circle()
                                        .fill(color.opacity(0.12))
                                        .frame(width: 40, height: 40)
                                        .overlay {
                                            Image(systemName: txn.category?.iconName ?? "questionmark")
                                                .font(.system(size: 14, weight: .bold))
                                                .foregroundStyle(color)
                                        }

                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(txn.title.isEmpty ? (txn.category?.name ?? "Misc") : txn.title)
                                            .font(.subheadline.bold())
                                            .foregroundStyle(FintechDesign.primaryText)
                                        Text(txn.date.formatted(.dateTime.day().month().year()))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    Text(txn.money.formatted(with: appStateViewModel.userCurrency))
                                        .font(.subheadline.bold())
                                        .foregroundStyle(color)
                                }
                                .padding(14)
                                .background(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(color.opacity(0.04))
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .background(FintechDesign.Background())
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - Goals Deep Dive

    private var goalsDeepDive: some View {
        VStack(alignment: .leading, spacing: 20) {
            let grouped = Dictionary(grouping: filteredTransfers) { $0.linkedGoal?.id }
            let goalStats: [(title: String, amount: Decimal, txnCount: Int)] = grouped.compactMap { _, txns in
                guard let goal = txns.first?.linkedGoal else { return nil }
                return (goal.title, txns.reduce(0) { $0 + $1.money.amount }, txns.count)
            }.sorted { $0.amount > $1.amount }

            if goalStats.isEmpty {
                VStack(spacing: 20) {
                    emptyState(icon: "target", message: "No goal transfers in this period")
                }
                .padding(24)
                .frame(maxWidth: .infinity)
                .background(
                    FintechDesign.CardBackground()
                        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                )
            } else {
                // Donut chart card
                VStack(alignment: .leading, spacing: 16) {
                    Text("Allocation Breakdown")
                        .font(.headline)
                        .foregroundStyle(FintechDesign.primaryText)

                    Chart(goalStats, id: \.title) { item in
                        SectorMark(
                            angle: .value("Amount", item.amount),
                            innerRadius: .ratio(0.62),
                            angularInset: 2.5
                        )
                        .cornerRadius(8)
                        .foregroundStyle(by: .value("Goal", item.title))
                    }
                    .frame(height: 220)
                }
                .padding(24)
                .background(
                    FintechDesign.CardBackground()
                        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                )

                // Goal breakdown rows
                VStack(alignment: .leading, spacing: 16) {
                    Text("Per-Goal Summary")
                        .font(.headline)
                        .foregroundStyle(FintechDesign.primaryText)

                    VStack(spacing: 10) {
                        ForEach(Array(goalStats.enumerated()), id: \.element.title) { rank, item in
                            let totalFunded = goalStats.reduce(0) { $0 + $1.amount }
                            let pct = totalFunded > 0 ? item.amount / totalFunded : 0

                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    // Rank circle
                                    Circle()
                                        .fill(Color.green.opacity(0.15))
                                        .frame(width: 36, height: 36)
                                        .overlay {
                                            Text("\(rank + 1)")
                                                .font(.caption.bold())
                                                .foregroundStyle(.green)
                                        }

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.title)
                                            .font(.subheadline.bold())
                                            .foregroundStyle(FintechDesign.primaryText)
                                        Text("\(item.txnCount) \(item.txnCount == 1 ? "transfer" : "transfers")")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    VStack(alignment: .trailing, spacing: 2) {
                                        Text(Money(item.amount).formatted(with: appStateViewModel.userCurrency))
                                            .font(.subheadline.bold())
                                            .foregroundStyle(.green)
                                        Text("\(Int((pct as NSDecimalNumber).doubleValue * 100))% of total")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }

                                // Progress bar
                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(Color.green.opacity(0.1))
                                            .frame(height: 6)
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(Color.green.gradient)
                                            .frame(width: geo.size.width * CGFloat((pct as NSDecimalNumber).doubleValue), height: 6)
                                    }
                                }
                                .frame(height: 6)
                            }
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .fill(Color.green.opacity(0.04))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                                            .strokeBorder(Color.green.opacity(0.12), lineWidth: 1)
                                    )
                            )
                        }
                    }
                }
                .padding(24)
                .background(
                    FintechDesign.CardBackground()
                        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                )
            }
        }
    }

    // MARK: - Helpers

    private func calculateAvg(txns: [Transaction]) -> String {
        let total = txns.reduce(Decimal(0)) { $0 + $1.money.amount }
        let uniqueDays = Set(txns.map { Calendar.current.startOfDay(for: $0.date) }).count
        let avg = uniqueDays > 0 ? total / Decimal(uniqueDays) : 0
        return Money(avg).formatted(with: appStateViewModel.userCurrency)
    }

    @ViewBuilder
    private func emptyState(icon: String, message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundStyle(.quaternary)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}
