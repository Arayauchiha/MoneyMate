import SwiftUI
import SwiftData
import Charts

struct SavingsBreakdownView: View {
    @Environment(AppStateViewModel.self) private var appStateViewModel
    @Query private var allTransactions: [Transaction]

    private var monthlySavings: [(label: String, income: Money, expense: Money, savings: Money, date: Date)] {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"

        let active = allTransactions.filter { !$0.isArchived }

        let grouped = Dictionary(
            grouping: active,
            by: { calendar.dateComponents([.year, .month], from: $0.date) }
        )

        return grouped.compactMap { components, txns -> (String, Money, Money, Money, Date)? in
            guard let date = calendar.date(from: components) else { return nil }
            let income = txns.filter { $0.type == .income }.reduce(Money.zero) { $0 + $1.money }
            let expense = txns.filter { $0.type == .expense }.reduce(Money.zero) { $0 + $1.money }
            let savings = income - expense
            return (formatter.string(from: date), income, expense, savings, date)
        }
        .sorted { $0.4 < $1.4 }
        .map { ($0.0, $0.1, $0.2, $0.3, $0.4) }
    }

    private var totalSavings: Money {
        monthlySavings.reduce(Money.zero) { $0 + $1.savings }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {

                // Hero total
                VStack(spacing: 6) {
                    Text("Accumulated Net Savings")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.5)
                    Text(totalSavings.formatted(with: appStateViewModel.userCurrency))
                        .font(.system(size: 38, weight: .black, design: .rounded))
                        .foregroundStyle(totalSavings.amount >= 0 ? Color(hex: "10B981") : .red)
                        .minimumScaleFactor(0.7)
                    Text("income minus expenses, month by month")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(24)
                .background(
                    FintechDesign.CardBackground()
                        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                )

                // Bar chart
                if !monthlySavings.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Month-by-Month")
                            .font(.headline)

                        Chart(monthlySavings, id: \.label) { item in
                            BarMark(
                                x: .value("Month", item.label),
                                y: .value("Savings", item.savings.amount)
                            )
                            .foregroundStyle(item.savings.amount >= 0 ? Color(hex: "10B981").gradient : Color.red.gradient)
                            .cornerRadius(6)
                        }
                        .chartYAxis {
                            AxisMarks { _ in
                                AxisValueLabel()
                                    .font(.caption2)
                            }
                        }
                        .chartXAxis {
                            AxisMarks { _ in
                                AxisValueLabel()
                                    .font(.caption2)
                            }
                        }
                        .frame(height: 200)
                    }
                    .padding(24)
                    .background(
                        FintechDesign.CardBackground()
                            .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                    )
                }

                // Monthly breakdown list
                VStack(alignment: .leading, spacing: 16) {
                    Text("Breakdown")
                        .font(.headline)

                    VStack(spacing: 0) {
                        ForEach(monthlySavings.reversed(), id: \.label) { item in
                            VStack(spacing: 0) {
                                HStack(spacing: 14) {
                                    // Indicator dot
                                    Circle()
                                        .fill(item.savings.amount >= 0 ? Color(hex: "10B981") : .red)
                                        .frame(width: 10, height: 10)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.label)
                                            .font(.subheadline.bold())
                                        HStack(spacing: 8) {
                                            Label(item.income.formatted(with: appStateViewModel.userCurrency), systemImage: "arrow.down")
                                                .font(.caption)
                                                .foregroundStyle(Color(hex: "10B981"))
                                            Label(item.expense.formatted(with: appStateViewModel.userCurrency), systemImage: "arrow.up")
                                                .font(.caption)
                                                .foregroundStyle(.red)
                                        }
                                    }

                                    Spacer()

                                    Text(item.savings.formatted(with: appStateViewModel.userCurrency))
                                        .font(.subheadline.bold())
                                        .foregroundStyle(item.savings.amount >= 0 ? Color(hex: "10B981") : .red)
                                }
                                .padding(.vertical, 14)

                                if item.label != monthlySavings.first?.label {
                                    Divider()
                                }
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
            .padding()
        }
        .navigationTitle("Net Savings")
        .navigationBarTitleDisplayMode(.large)
        .background(FintechDesign.Background())
    }
}
