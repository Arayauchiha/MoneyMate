import Charts
import SwiftData
import SwiftUI

struct InsightsView: View {
    @Environment(InsightsViewModel.self) private var insightsViewModel
    @Environment(AppStateViewModel.self) private var appStateViewModel
    @Environment(TransactionViewModel.self) private var transactionViewModel
    @Environment(GoalsViewModel.self) private var goalsViewModel
    @Query private var allTransactions: [Transaction]

    @State private var selectedPieAmount: Decimal?
    @State private var chartProgress: Double = 0

    var body: some View {
        @Bindable var insightsViewModel = insightsViewModel

        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    summarySection
                    spendingAnalysisCard
                    monthlyTrendChart
                }
                .padding()
            }
            .navigationTitle("Insights")
            .navigationBarTitleDisplayMode(.large)
            .background(Color(uiColor: .systemGroupedBackground))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    filterMenu
                }
            }
            .task {
                chartProgress = 0
                await insightsViewModel.load()
                withAnimation(.easeInOut(duration: 1.2)) {
                    chartProgress = 1.0
                }
            }
            .refreshable {
                chartProgress = 0
                await insightsViewModel.load()
                withAnimation(.easeInOut(duration: 1.2)) {
                    chartProgress = 1.0
                }
            }
            .onChange(of: allTransactions) { _, _ in
                Task {
                    chartProgress = 0
                    await insightsViewModel.load()
                    withAnimation(.easeInOut(duration: 1.2)) {
                        chartProgress = 1.0
                    }
                }
            }
            .onChange(of: insightsViewModel.selectedPeriod) { _, _ in
                chartProgress = 0
                withAnimation(.easeInOut(duration: 1.2)) {
                    chartProgress = 1.0
                }
            }
        }
    }

    private var periodPicker: some View {
        @Bindable var insightsViewModel = insightsViewModel
        return Picker("Period", selection: $insightsViewModel.selectedPeriod) {
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
        VStack(spacing: 16) {
            // Native month subtitle
            HStack {
                Text(insightsViewModel.currentMonthYearDisplay)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.leading, 4)

            if insightsViewModel.selectedPeriod == .week, let comp = insightsViewModel.weekComparison {
                weekComparisonSection(comparison: comp)
            }

            // Prominent Current Balance (not a card, not tappable)
            currentBalanceDisplay

            HStack(spacing: 16) {
                totalSpentCard
                monthFundedCard
            }

            HStack(spacing: 16) {
                netSavingsCard
                dailyAverageCard
            }
        }
    }

    @ViewBuilder
    private var filterMenu: some View {
        @Bindable var insightsViewModel = insightsViewModel
        Menu {
            Section("Standard Periods") {
                Picker("Period", selection: $insightsViewModel.selectedPeriod) {
                    ForEach(TimePeriod.allCases) { period in
                        Text(period.label).tag(period)
                    }
                }
            }

            Section("Historical Months") {
                ForEach(insightsViewModel.lastTwelveMonths, id: \.self) { date in
                    Button {
                        insightsViewModel.selectMonth(date)
                    } label: {
                        HStack {
                            Text(monthLabel(for: date))
                            if insightsViewModel.customMonth == date {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }
        } label: {
            Label(insightsViewModel.selectedPeriod.label, systemImage: "line.3.horizontal.decrease.circle")
                .font(.system(size: 14, weight: .bold))
        }
    }

    private func monthLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }

    /// Prominent balance display — not a card, not tappable
    private var currentBalanceDisplay: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Current Balance")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)
            Text(goalsViewModel.totalBalance.formatted(with: appStateViewModel.userCurrency))
                .font(.system(size: 38, weight: .black, design: .rounded))
                .foregroundStyle(Color(hex: "10B981"))
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
    }

    private var totalSpentCard: some View {
        let (start, end) = insightsViewModel.selectedPeriod.dateRange
        return NavigationLink {
            InsightsDetailView(type: .totalSpend, startDate: start, endDate: end)
        } label: {
            summaryCard(title: "Total Spent", value: insightsViewModel.totalForPeriod.formatted(with: appStateViewModel.userCurrency), color: .red)
        }
        .buttonStyle(.plain)
    }

    private var monthFundedCard: some View {
        let (start, end) = insightsViewModel.selectedPeriod.dateRange
        return NavigationLink {
            InsightsDetailView(type: .fundedToGoals, startDate: start, endDate: end)
        } label: {
            summaryCard(title: "Month Funded", value: insightsViewModel.totalFundedToGoals.formatted(with: appStateViewModel.userCurrency), color: .white)
        }
        .buttonStyle(.plain)
    }

    private var netSavingsCard: some View {
        let savings = insightsViewModel.totalIncomeForPeriod - insightsViewModel.totalForPeriod
        return NavigationLink {
            SavingsBreakdownView()
        } label: {
            summaryCard(title: "Net Savings", value: savings.formatted(with: appStateViewModel.userCurrency), color: .white)
        }
        .buttonStyle(.plain)
    }

    private var dailyAverageCard: some View {
        let (start, end) = insightsViewModel.selectedPeriod.dateRange
        return NavigationLink {
            InsightsDetailView(type: .dailyAverage, startDate: start, endDate: end)
        } label: {
            summaryCard(title: "Daily Avg Spend", value: insightsViewModel.averagePerDay.formatted(with: appStateViewModel.userCurrency), color: .white)
        }
        .buttonStyle(.plain)
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

    @ViewBuilder
    private var spendingAnalysisCard: some View {
        if !insightsViewModel.categoryTotals.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                // New Unified Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Spending Analysis")
                            .font(.headline)
                            .foregroundStyle(FintechDesign.primaryText)
                        Text(insightsViewModel.selectedPeriod.label)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()

                    // Unified "View Details" Navigation
                    let range = insightsViewModel.selectedPeriod.dateRange
                    NavigationLink(destination: AllCategoriesView(startDate: range.start, endDate: range.end)) {
                        HStack(spacing: 4) {
                            Text("View Details")
                                .font(.caption.bold())
                                .foregroundStyle(.blue)
                            Image(systemName: "chevron.right")
                                .font(.caption.bold())
                                .foregroundStyle(.blue)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.blue.opacity(0.1), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 16)

                // 1. Donut Chart Component
                ZStack {
                    Chart(insightsViewModel.categoryTotals, id: \.id) { total in
                        SectorMark(
                            angle: .value("Amount", total.total.amount),
                            innerRadius: .ratio(0.65),
                            angularInset: 2.0
                        )
                        .cornerRadius(8)
                        .foregroundStyle(total.categoryColor)
                        .opacity(selectedPieAmount == nil ? 1.0 : (pieIsSelected(total) ? 1.0 : 0.4))
                    }
                    .chartAngleSelection(value: $selectedPieAmount)
                    .frame(height: 220)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8), value: insightsViewModel.categoryTotals)
                    .mask {
                        Circle()
                            .trim(from: 0, to: chartProgress)
                            .stroke(lineWidth: 220)
                            .rotationEffect(.degrees(-90))
                    }

                    // Center Overlay
                    VStack(spacing: 2) {
                        if let selectedPieAmount, let cat = pieCategory(for: selectedPieAmount) {
                            Text(cat.categoryName)
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                            Text(cat.total.formatted(with: appStateViewModel.userCurrency))
                                .font(.system(.title2, design: .rounded))
                                .fontWeight(.heavy)
                                .foregroundStyle(cat.categoryColor)
                        } else {
                            Text("Total Spend")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                            Text(insightsViewModel.totalForPeriod.formatted(with: appStateViewModel.userCurrency))
                                .font(.system(.title2, design: .rounded))
                                .fontWeight(.heavy)
                                .foregroundStyle(FintechDesign.primaryText)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)

                Divider()
                    .padding(.horizontal, 24)

                // Sub-header for the list
                Text("Top Categories")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                    .padding(.bottom, 4)

                // 2. Unified Category List (Strict Mirror from Home)
                let range = insightsViewModel.selectedPeriod.dateRange
                SpendingCategoryList(
                    categories: insightsViewModel.categoryTotals.prefix(3).map {
                        SpendingCategoryItem(category: $0.category, amount: $0.total, transactionCount: $0.transactionCount)
                    },
                    appStateViewModel: appStateViewModel,
                    startDate: range.start,
                    endDate: range.end
                )
                .padding(.vertical, 8)
            }
            .background(
                FintechDesign.CardBackground()
                    .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 32)
                            .stroke(FintechDesign.adaptiveColor("E0E0E0", "FFFFFF").opacity(0.1), lineWidth: 1)
                    )
            )
        }
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

    @State private var selectedComparisonDate: String?

    @ViewBuilder
    private var monthlyTrendChart: some View {
        if !insightsViewModel.monthlyTrend.isEmpty {
            VStack(alignment: .leading, spacing: 16) {
                // Header Zone (Dedicated Navigation)
                NavigationLink {
                    TrendDetailView(
                        daily: insightsViewModel.dailyTrend,
                        weekly: insightsViewModel.weeklyTrend,
                        monthly: insightsViewModel.monthlyTrend
                    )
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Historical Trends")
                                .font(.headline)
                                .foregroundStyle(FintechDesign.primaryText)
                            Text("Monthly spending overview")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()

                        // Simple, clean See Detail/Chevron
                        HStack(spacing: 4) {
                            Text("View Details")
                                .font(.caption.bold())
                                .foregroundStyle(.blue)
                            Image(systemName: "chevron.right")
                                .font(.caption.bold())
                                .foregroundStyle(.blue)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.blue.opacity(0.1), in: Capsule())
                    }
                    .padding(.horizontal, 4)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                // Chart Zone (Dedicated Interaction, No Navigation Lag)
                Chart {
                    ForEach(insightsViewModel.monthlyTrend) { trend in
                        // Pulse Pillar for solo month visibility
                        BarMark(
                            x: .value("Month", trend.label),
                            y: .value("Amount", trend.total.amount)
                        )
                        .foregroundStyle(FintechDesign.brandGradient.opacity(0.1))
                        .cornerRadius(20)

                        AreaMark(
                            x: .value("Month", trend.label),
                            y: .value("Amount", trend.total.amount)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(hex: "06B6D4").opacity(0.3), Color(hex: "06B6D4").opacity(0.0)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .interpolationMethod(.monotone)

                        LineMark(
                            x: .value("Month", trend.label),
                            y: .value("Amount", trend.total.amount)
                        )
                        .foregroundStyle(FintechDesign.brandGradient)
                        .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                        .interpolationMethod(.monotone)

                        PointMark(
                            x: .value("Month", trend.label),
                            y: .value("Amount", trend.total.amount)
                        )
                        .foregroundStyle(Color(hex: "06B6D4"))
                        .symbolSize(80)
                        .annotation(position: .top) {
                            if insightsViewModel.monthlyTrend.count == 1 {
                                Text(trend.total.formatted(with: appStateViewModel.userCurrency))
                                    .font(.system(.caption, design: .rounded).bold())
                                    .foregroundStyle(FintechDesign.primaryText)
                                    .padding(.bottom, 8)
                            }
                        }
                    }

                    if let selectedComparisonDate, let selectedTrend = insightsViewModel.monthlyTrend.first(where: { $0.label == selectedComparisonDate }) {
                        RuleMark(x: .value("Selected", selectedComparisonDate))
                            .foregroundStyle(FintechDesign.adaptiveColor("1A1A1A", "FFFFFF").opacity(0.1))
                            .zIndex(-1)
                            .annotation(position: .top, spacing: 10) {
                                VStack(spacing: 4) {
                                    Text(selectedTrend.label)
                                        .font(.system(size: 8, weight: .black))
                                        .textCase(.uppercase)
                                        .foregroundStyle(.secondary)

                                    Text(selectedTrend.total.formatted(with: appStateViewModel.userCurrency))
                                        .font(.system(.caption, design: .rounded))
                                        .fontWeight(.bold)
                                        .foregroundStyle(FintechDesign.primaryText)
                                }
                                .padding(8)
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(FintechDesign.adaptiveColor("E0E0E0", "FFFFFF").opacity(0.1), lineWidth: 1)
                                )
                            }
                    }
                }
                .chartXSelection(value: $selectedComparisonDate)
                .chartYAxis(.hidden)
                .chartXAxis {
                    AxisMarks { _ in
                        AxisValueLabel()
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(height: 200)
            }
            .padding(24)
            .background(
                FintechDesign.CardBackground()
                    .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 32)
                            .stroke(FintechDesign.adaptiveColor("E0E0E0", "FFFFFF").opacity(0.1), lineWidth: 1)
                    )
            )
        }
    }

    private struct LegendItem: View {
        let label: String
        let color: Color
        var body: some View {
            HStack(spacing: 4) {
                Circle().fill(color).frame(width: 8, height: 8)
                Text(label).font(.system(size: 10, weight: .bold)).foregroundStyle(.secondary)
            }
        }
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
