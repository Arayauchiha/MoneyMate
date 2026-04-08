import SwiftUI
import SwiftData
import Charts

struct WeeklySpendingDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(HomeViewModel.self) private var homeViewModel
    @Environment(AppStateViewModel.self) private var appStateViewModel

    @Query private var allTransactions: [Transaction]
    @State private var selectedDay: String? = nil
    
    init() {
        let descriptor = FetchDescriptor<Transaction>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        _allTransactions = Query(descriptor)
    }

    var weeklyTransactions: [Transaction] {
        let today = Date()
        let start = Calendar.current.date(byAdding: .day, value: -6, to: today) ?? today
        return allTransactions.filter { $0.date >= start && !$0.isArchived && $0.type == .expense }
    }
    
    var categoriesInWeek: [(category: Category?, amount: Money)] {
        let grouped = Dictionary(grouping: weeklyTransactions, by: { $0.category })
        return grouped.map { ($0.key, $0.value.reduce(Money.zero) { $0 + $1.money }) }
            .sorted { $0.amount.amount > $1.amount.amount }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                dailyBreakdownChart
                categorySplitSection
            }
            .padding()
        }
        .navigationTitle("This Week")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(uiColor: .systemGroupedBackground))
    }

    private var dailyBreakdownChart: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                if let selectedDay, let data = homeViewModel.weeklyChartData.first(where: { $0.dayLabel == selectedDay }) {
                    Text(data.total.formatted(with: appStateViewModel.userCurrency))
                        .font(.system(.title2, design: .rounded).bold())
                    Text(selectedDay)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text(homeViewModel.totalExpenses.formatted(with: appStateViewModel.userCurrency))
                        .font(.system(.title2, design: .rounded).bold())
                    Text("Total this week")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 4)
            
            Chart {
                ForEach(homeViewModel.weeklyChartData) { dataPoint in
                    let isSelected = selectedDay == nil || selectedDay == dataPoint.dayLabel
                    BarMark(
                        x: .value("Day", dataPoint.dayLabel),
                        y: .value("Amount", dataPoint.total.amount)
                    )
                    .foregroundStyle(FintechDesign.brandGradient.opacity(isSelected ? 1.0 : 0.3))
                    .cornerRadius(6)
                }
                
                if let selectedDay {
                    RuleMark(x: .value("Day", selectedDay))
                        .foregroundStyle(FintechDesign.adaptiveColor("1A1A1A", "FFFFFF").opacity(0.1))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
                }
            }
            .chartYAxis { AxisMarks(position: .leading) }
            .chartXSelection(value: $selectedDay)
            .frame(height: 250)
            .padding(24)
            .background(
                FintechDesign.CardBackground()
                    .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 32)
                            .stroke(FintechDesign.adaptiveColor("E0E0E0", "FFFFFF").opacity(0.1), lineWidth: 1)
                    )
            )
            .sensoryFeedback(.selection, trigger: selectedDay)
            
            Text("Tap or hold on a bar to see daily amount")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private var categorySplitSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Category Split")
                .font(.headline)
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 16)
            
            if categoriesInWeek.isEmpty {
                Text("No spending this week.")
                    .padding(24)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(0..<categoriesInWeek.count, id: \.self) { index in
                    let item = categoriesInWeek[index]
                    let calendar = Calendar.current
                    let today = Date()
                    let start = calendar.date(byAdding: .day, value: -6, to: today) ?? today
                    
                    NavigationLink {
                        CategoryDetailView(category: item.category, startDate: start, endDate: today)
                    } label: {
                        categoryRow(item: item)
                    }
                    .buttonStyle(.plain)
                    
                    if index < categoriesInWeek.count - 1 {
                        Divider()
                            .padding(.leading, 80)
                            .padding(.trailing, 24)
                    }
                }
            }
        }
        .padding(.bottom, 12)
        .background(
            FintechDesign.CardBackground()
                .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 32)
                        .stroke(FintechDesign.adaptiveColor("E0E0E0", "FFFFFF").opacity(0.1), lineWidth: 1)
                )
        )
    }

    @ViewBuilder
    private func categoryRow(item: (category: Category?, amount: Money)) -> some View {
        HStack(spacing: 16) {
            Circle()
                .fill((item.category?.color ?? .gray).opacity(0.2))
                .frame(width: 40, height: 40)
                .overlay {
                    Image(systemName: item.category?.iconName ?? "questionmark.circle")
                        .foregroundStyle(item.category?.color ?? .gray)
                }
            
            Text(item.category?.name ?? "Miscellaneous")
                .font(.subheadline)
                .fontWeight(.medium)
            
            Spacer()
            
            Text(item.amount.formatted(with: appStateViewModel.userCurrency))
                .font(.subheadline)
                .fontWeight(.bold)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}
