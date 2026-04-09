import Charts
import SwiftData
import SwiftUI

enum TrendUnit: String, CaseIterable, Identifiable {
    case day = "Daily"
    case week = "Weekly"
    case month = "Monthly"
    var id: String {
        rawValue
    }

    var descriptor: String {
        switch self {
        case .day: "Last 14 days of spending activity"
        case .week: "Week-by-week trends"
        case .month: "Month-by-month historical data"
        }
    }
}

struct TrendDetailView: View {
    @Environment(AppStateViewModel.self) private var appStateViewModel
    @Environment(InsightsViewModel.self) private var insightsViewModel
    @Query private var allTransactions: [Transaction]

    let dailyData: [TrendTotal]
    let weeklyData: [TrendTotal]
    let monthlyData: [TrendTotal]

    @State private var selectedUnit: TrendUnit = .month
    @State private var selectedTrend: TrendTotal?

    init(daily: [TrendTotal], weekly: [TrendTotal], monthly: [TrendTotal]) {
        dailyData = daily
        weeklyData = weekly
        monthlyData = monthly
    }

    var currentData: [TrendTotal] {
        switch selectedUnit {
        case .day: dailyData
        case .week: weeklyData
        case .month: monthlyData
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                Picker("Unit", selection: $selectedUnit) {
                    ForEach(TrendUnit.allCases) { unit in
                        Text(unit.rawValue).tag(unit)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                Text(selectedUnit.descriptor)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 12)
            .background(Color(uiColor: .systemGroupedBackground))
            .zIndex(1)

            List {
                Section {
                    Chart(currentData) { trend in
                        BarMark(
                            x: .value("Period", trend.label),
                            y: .value("Amount", trend.total.amount)
                        )
                        .foregroundStyle(Color.blue.gradient)
                        .cornerRadius(6)
                    }
                    .frame(height: 240)
                    .padding(.vertical)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())

                Section("Historical Breakdown") {
                    if currentData.isEmpty {
                        Text("No data available for this view.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(currentData.reversed()) { trend in
                            let (start, end) = rangeFor(trend: trend)

                            NavigationLink {
                                TrendBreakdownView(title: trend.label, startDate: start, endDate: end, total: trend.total)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(trend.label)
                                            .font(.headline)
                                        Text(subLabel)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text(trend.total.formatted(with: appStateViewModel.userCurrency))
                                        .font(.subheadline.bold())
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 8)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Spending Trends")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var subLabel: String {
        switch selectedUnit {
        case .day: "Day Summary"
        case .week: "Week Summary"
        case .month: "Month Summary"
        }
    }

    private func rangeFor(trend: TrendTotal) -> (Date, Date) {
        let calendar = Calendar.current
        let start: Date
        let end: Date

        switch selectedUnit {
        case .day:
            start = calendar.startOfDay(for: trend.date)
            end = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: start)!
        case .week:
            start = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: trend.date))!
            end = calendar.date(byAdding: DateComponents(day: 6), to: start)!
        case .month:
            start = calendar.date(from: calendar.dateComponents([.year, .month], from: trend.date))!
            end = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: start)!
        }
        return (start, end)
    }

    private func computeBreakdown(start: Date, end: Date) -> [CategoryTotal] {
        let txns = allTransactions.filter {
            !$0.isArchived &&
                $0.type == .expense &&
                $0.date >= start &&
                $0.date <= end
        }

        // Manual grouping
        let uncategorisedID = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
        let grouped = Dictionary(grouping: txns, by: { $0.category?.id ?? uncategorisedID })
        return grouped.map { _, tList -> CategoryTotal in
            let total = tList.reduce(Money.zero) { $0 + $1.money }
            let category = tList.first { $0.category != nil }?.category
            return CategoryTotal(category: category, total: total, transactionCount: tList.count)
        }.sorted { $0.total.amount > $1.total.amount }
    }
}
