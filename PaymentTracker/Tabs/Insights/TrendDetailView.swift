import SwiftUI
import Charts

enum TrendUnit: String, CaseIterable, Identifiable {
    case day = "Daily"
    case week = "Weekly"
    case month = "Monthly"
    var id: String { self.rawValue }
    
    var descriptor: String {
        switch self {
        case .day: return "Last 14 days of spending activity"
        case .week: return "Week-by-week trends"
        case .month: return "Month-by-month historical data"
        }
    }
}

struct TrendDetailView: View {
    let dailyData: [TrendTotal]
    let weeklyData: [TrendTotal]
    let monthlyData: [TrendTotal]
    
    @State private var selectedUnit: TrendUnit = .month
    
    init(daily: [TrendTotal], weekly: [TrendTotal], monthly: [TrendTotal]) {
        self.dailyData = daily
        self.weeklyData = weekly
        self.monthlyData = monthly
    }

    var currentData: [TrendTotal] {
        switch selectedUnit {
        case .day: return dailyData
        case .week: return weeklyData
        case .month: return monthlyData
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
                            
                            NavigationLink(destination: CategoryDetailView(category: nil, startDate: start, endDate: end, isDateSummary: true)) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(trend.label)
                                            .font(.headline)
                                        Text(subLabel)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text(trend.total.formatted)
                                        .font(.subheadline).bold()
                                }
                                .padding(.vertical, 4)
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
        case .day: return "Day Summary"
        case .week: return "Week Summary"
        case .month: return "Month Summary"
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
}
