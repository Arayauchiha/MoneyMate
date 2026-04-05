import SwiftUI
import Charts

enum TrendUnit: String, CaseIterable, Identifiable {
    case month = "Monthly"
    case week = "Weekly"
    var id: String { self.rawValue }
    
    var descriptor: String {
        self == .month ? "Show month-by-month historical data" : "Show week-by-week trends"
    }
}

struct TrendDetailView: View {
    let monthlyData: [TrendTotal]
    let weeklyData: [TrendTotal]
    
    @State private var selectedUnit: TrendUnit = .month
    
    init(monthly: [TrendTotal], weekly: [TrendTotal]) {
        self.monthlyData = monthly
        self.weeklyData = weekly
    }

    var currentData: [TrendTotal] {
        selectedUnit == .month ? monthlyData : weeklyData
    }

    var body: some View {
        VStack(spacing: 0) {
            // Native Sticky-style Header
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
            .zIndex(1) // Ensure it stays on top during scroll if needed
            
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
                            let start = startOf(trend: trend)
                            let end = endOf(trend: trend, from: start)
                            
                            NavigationLink(destination: CategoryDetailView(category: nil, startDate: start, endDate: end)) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(trend.label)
                                            .font(.headline)
                                        Text(selectedUnit == .month ? "Month Summary" : "Week Summary")
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
    
    private func startOf(trend: TrendTotal) -> Date {
        let calendar = Calendar.current
        if selectedUnit == .month {
            return calendar.date(from: calendar.dateComponents([.year, .month], from: trend.date))!
        } else {
            return calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: trend.date))!
        }
    }
    
    private func endOf(trend: TrendTotal, from start: Date) -> Date {
        let calendar = Calendar.current
        if selectedUnit == .month {
            return calendar.date(byAdding: DateComponents(month: 1, day: -1), to: start)!
        } else {
            return calendar.date(byAdding: DateComponents(day: 6), to: start)!
        }
    }
}
