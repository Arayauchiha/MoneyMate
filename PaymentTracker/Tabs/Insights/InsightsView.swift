import SwiftUI
import SwiftData
import Charts

struct InsightsView: View {
    @Environment(InsightsViewModel.self) private var insightsViewModel
    @Environment(AppStateViewModel.self) private var appStateViewModel
    @Environment(TransactionViewModel.self) private var transactionViewModel

    @Query private var allTransactions: [Transaction]
    @State private var selectedPieAmount: Decimal?
    @State private var selectedMonth: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    periodPicker
                    
                    if insightsViewModel.selectedPeriod == .week, let comp = insightsViewModel.weekComparison {
                        weekComparisonSection(comparison: comp)
                    }
                    
                    summarySection
                    
                    if !insightsViewModel.categoryTotals.isEmpty {
                        categoryBreakdownChart
                        topCategoriesList
                    } else {
                        emptyState
                    }
                    
                    if !insightsViewModel.monthlyTrend.isEmpty {
                        monthlyTrendChart
                    }
                }
                .padding()
            }
            .navigationTitle("Insights")
            .background(Color(uiColor: .systemGroupedBackground))
            .task { await insightsViewModel.load() }
            .refreshable { await insightsViewModel.load() }
            .onChange(of: allTransactions) { _, _ in
                Task { await insightsViewModel.load() }
            }
        }
    }
    
    private var periodPicker: some View {
        @Bindable var viewModel = insightsViewModel
        return Picker("Period", selection: $viewModel.selectedPeriod) {
            ForEach(TimePeriod.allCases) { period in
                Text(period.label).tag(period)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
    }

    private func weekComparisonSection(comparison: WeekComparison) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Compared to last week")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                HStack {
                    Image(systemName: comparison.isImproved ? "arrow.down.right" : "arrow.up.right")
                        .foregroundStyle(comparison.isImproved ? .green : .red)
                    Text(comparison.delta.formatted(with: appStateViewModel.userCurrency))
                        .fontWeight(.semibold)
                        .foregroundStyle(comparison.isImproved ? .green : .red)
                }
            }
            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
    }
    
    private var summarySection: some View {
        let (start, end) = insightsViewModel.selectedPeriod.dateRange
        return VStack(spacing: 16) {
            HStack(spacing: 16) {
                NavigationLink(destination: InsightsDetailView(type: .totalSpend, startDate: start, endDate: end)) {
                    summaryCard(title: "Total Spend", value: insightsViewModel.totalForPeriod.formatted(with: appStateViewModel.userCurrency), color: .primary)
                }
                .buttonStyle(.plain)
                
                NavigationLink(destination: InsightsDetailView(type: .dailyAverage, startDate: start, endDate: end)) {
                    summaryCard(title: "Daily Avg", value: insightsViewModel.averagePerDay.formatted(with: appStateViewModel.userCurrency), color: .primary)
                }
                .buttonStyle(.plain)
            }
            
            HStack(spacing: 16) {
                NavigationLink(destination: InsightsDetailView(type: .fundedToGoals, startDate: start, endDate: end)) {
                    summaryCard(title: "Funded to Goals", value: insightsViewModel.totalFundedToGoals.formatted(with: appStateViewModel.userCurrency), color: .green)
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    private func summaryCard(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
                .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 4)
        )
    }
    
    private var categoryBreakdownChart: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Spending Breakdown")
                .font(.headline)
            
            Chart(insightsViewModel.categoryTotals) { total in
                SectorMark(
                    angle: .value("Amount", total.total.amount),
                    innerRadius: .ratio(0.6),
                    angularInset: 1.5
                )
                .cornerRadius(4)
                .foregroundStyle(by: .value("Category", total.categoryName))
                .opacity(selectedPieAmount == nil ? 1.0 : (pieIsSelected(total) ? 1.0 : 0.5))
            }
            .chartAngleSelection(value: $selectedPieAmount)
            .chartOverlay { proxy in
                GeometryReader { _ in
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture { location in
                            let angle = proxy.angle(at: location)
                            if let amount = proxy.value(atAngle: angle, as: Decimal.self) {
                                selectedPieAmount = amount
                            }
                        }
                }
            }
            .chartForegroundStyleScale(
                domain: insightsViewModel.categoryTotals.map(\.categoryName),
                range: insightsViewModel.categoryTotals.map(\.categoryColor)
            )
            .frame(height: 220)
            
            if let selectedPieAmount, let cat = pieCategory(for: selectedPieAmount) {
                let (start, end) = insightsViewModel.selectedPeriod.dateRange
                NavigationLink(destination: CategoryDetailView(category: cat.category, startDate: start, endDate: end)) {
                    HStack {
                        Spacer()
                        HStack(spacing: 8) {
                            Text("\(cat.categoryName): \(cat.total.formatted(with: appStateViewModel.userCurrency))")
                                .font(.subheadline).bold()
                            Image(systemName: "chevron.right")
                                .font(.caption2).bold()
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 16)
                        .background(Color.blue.opacity(0.1), in: Capsule())
                        .foregroundStyle(.blue)
                        Spacer()
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
                .shadow(color: .black.opacity(0.03), radius: 8, x: 0, y: 2)
        )
    }

    private func pieIsSelected(_ total: CategoryTotal) -> Bool {
        guard let selected = selectedPieAmount else { return false }
        return pieCategory(for: selected)?.id == total.id
    }

    private func pieCategory(for amount: Decimal) -> CategoryTotal? {
        var cumulative: Decimal = 0
        for cat in insightsViewModel.categoryTotals {
            cumulative += cat.total.amount
            if amount <= cumulative { return cat }
        }
        return nil
    }
    
    private var topCategoriesList: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Top Categories")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Spacer()
                if !insightsViewModel.categoryTotals.isEmpty {
                    NavigationLink {
                        AllCategoriesView()
                    } label: {
                        Text("See All")
                            .font(.subheadline).bold()
                            .foregroundStyle(.blue)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            
            Divider()
                .padding(.leading, 64)
            
            let topThree = insightsViewModel.categoryTotals.prefix(3)
            ForEach(Array(topThree.enumerated()), id: \.element.id) { index, categoryTotal in
                let (start, end) = insightsViewModel.selectedPeriod.dateRange
                NavigationLink(destination: CategoryDetailView(category: categoryTotal.category, startDate: start, endDate: end)) {
                    HStack(spacing: 16) {
                        Circle()
                            .fill(categoryTotal.categoryColor.opacity(0.2))
                            .frame(width: 40, height: 40)
                            .overlay {
                                Image(systemName: categoryTotal.categoryIcon)
                                    .foregroundStyle(categoryTotal.categoryColor)
                            }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(categoryTotal.categoryName)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text("\(categoryTotal.transactionCount) transactions")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        Text(categoryTotal.total.formatted(with: appStateViewModel.userCurrency))
                            .font(.subheadline)
                            .fontWeight(.bold)
                        
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(.quaternary)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                
                if index < topThree.count - 1 {
                    Divider()
                        .padding(.leading, 64)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
                .shadow(color: .black.opacity(0.03), radius: 8, x: 0, y: 2)
        )
    }
    
    private var monthlyTrendChart: some View {
        NavigationLink(destination: TrendDetailView(daily: insightsViewModel.dailyTrend, weekly: insightsViewModel.weeklyTrend, monthly: insightsViewModel.monthlyTrend)) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Historical Trends")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                
                Chart(insightsViewModel.monthlyTrend) { trend in
                    LineMark(
                        x: .value("Month", trend.label),
                        y: .value("Amount", trend.total.amount)
                    )
                    .symbol(.circle)
                    .foregroundStyle(Color.blue)
                    
                    AreaMark(
                        x: .value("Month", trend.label),
                        y: .value("Amount", trend.total.amount)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue.opacity(0.3), .blue.opacity(0.0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .frame(height: 180)
                
                Text("Tap for monthly & weekly breakdown")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
                    .shadow(color: .black.opacity(0.03), radius: 8, x: 0, y: 2)
            )
        }
        .buttonStyle(.plain)
    }
    
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.pie")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            Text("No data to show for this period.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
    }
}
