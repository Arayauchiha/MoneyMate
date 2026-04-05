import SwiftUI
import SwiftData
import Charts

struct WeeklySpendingDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(HomeViewModel.self) private var homeViewModel

    @Query private var allTransactions: [Transaction]
    
    init() {
        let descriptor = FetchDescriptor<Transaction>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        _allTransactions = Query(descriptor)
    }

    private var weeklyTransactions: [Transaction] {
        let calendar = Calendar.current
        let today = Date()
        guard let start = calendar.date(byAdding: .day, value: -6, to: today) else { return [] }
        return allTransactions.filter { $0.date >= start && $0.date <= today && $0.type == .expense }
    }
    
    private var categoriesInWeek: [(category: Category?, amount: Money)] {
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
        VStack(alignment: .leading, spacing: 12) {
            Text("Daily Breakdown")
                .font(.headline)
                .padding(.horizontal, 4)
            
            Chart {
                ForEach(homeViewModel.weeklyChartData) { dataPoint in
                    BarMark(
                        x: .value("Day", dataPoint.dayLabel),
                        y: .value("Amount", dataPoint.total.amount)
                    )
                    .foregroundStyle(Color.red.gradient)
                    .cornerRadius(4)
                }
            }
            .chartYAxis { AxisMarks(position: .leading) }
            .frame(height: 250)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
                    .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 2)
            )
        }
    }

    private var categorySplitSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Category Split")
                .font(.headline)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            
            Divider().padding(.leading, 64)
            
            if categoriesInWeek.isEmpty {
                Text("No spending this week.")
                    .padding()
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
                                Divider().padding(.leading, 64)
                            }
                        }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
                .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 2)
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
            
            Text(item.category?.name ?? "Other")
                .font(.subheadline)
                .fontWeight(.medium)
            
            Spacer()
            
            Text(item.amount.formatted)
                .font(.subheadline)
                .fontWeight(.bold)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}
