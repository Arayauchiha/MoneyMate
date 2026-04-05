import SwiftUI
import Charts

struct InsightsView: View {
    @Environment(InsightsViewModel.self) private var insightsViewModel
    @Environment(TransactionViewModel.self) private var transactionViewModel

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
            .onChange(of: transactionViewModel.dataVersion) { _, _ in
                Task { await insightsViewModel.load() }
            }
        }
    }
    
    private var periodPicker: some View {
        @Bindable var viewModel = insightsViewModel
        // If user wants custom specific date logic, a standard multi-DatePicker sheet could go here.
        // For simplicity, we keep the segmentation but could extend Custom Date models later.
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
                    Text(comparison.delta.formatted)
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
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Total Spend")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(insightsViewModel.totalForPeriod.formatted)
                    .font(.title3)
                    .fontWeight(.bold)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
            )
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Daily Avg (\(insightsViewModel.daysInPeriod)d)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(insightsViewModel.averagePerDay.formattedCompact)
                    .font(.title3)
                    .fontWeight(.bold)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
            )
        }
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
            .chartForegroundStyleScale(
                domain: insightsViewModel.categoryTotals.map(\.categoryName),
                range: insightsViewModel.categoryTotals.map(\.categoryColor)
            )
            .frame(height: 220)
            
            if let selectedPieAmount, let cat = pieCategory(for: selectedPieAmount) {
                HStack {
                    Spacer()
                    Text("\(cat.categoryName): \(cat.formattedTotal)")
                        .font(.subheadline).bold()
                        .padding(8)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                    Spacer()
                }
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
            Text("Top Categories (Tap for flow)")
                .font(.headline)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .foregroundStyle(.secondary)
            
            Divider()
                .padding(.leading, 64)
            
            ForEach(Array(insightsViewModel.categoryTotals.prefix(4).enumerated()), id: \.element.id) { index, category in
                HStack(spacing: 16) {
                    Circle()
                        .fill(category.categoryColor.opacity(0.2))
                        .frame(width: 40, height: 40)
                        .overlay {
                            Image(systemName: category.categoryIcon)
                                .foregroundStyle(category.categoryColor)
                        }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(category.categoryName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text("\(category.transactionCount) transactions")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    Text(category.formattedTotal)
                        .font(.subheadline)
                        .fontWeight(.bold)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                // In a wider app, we'd add .onTapGesture { navigate to filtered list } here.
                
                if index < min(insightsViewModel.categoryTotals.count, 4) - 1 {
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
        VStack(alignment: .leading, spacing: 16) {
            Text("6-Month Trend")
                .font(.headline)
            
            Chart(insightsViewModel.monthlyTrend) { trend in
                LineMark(
                    x: .value("Month", trend.month),
                    y: .value("Amount", trend.total.amount)
                )
                .symbol(.circle)
                .foregroundStyle(Color.blue)
                
                AreaMark(
                    x: .value("Month", trend.month),
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
            .chartXSelection(value: $selectedMonth)
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .frame(height: 180)

            if let selectedMonth, let trend = insightsViewModel.monthlyTrend.first(where: { $0.month == selectedMonth }) {
                Text("\(trend.month): \(trend.total.formatted)")
                    .font(.subheadline).bold()
                    .padding(8)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
                .shadow(color: .black.opacity(0.03), radius: 8, x: 0, y: 2)
        )
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
