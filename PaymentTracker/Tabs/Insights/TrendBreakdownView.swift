import Charts
import SwiftData
import SwiftUI

/// Vivid palette to override dull category colors in the chart
private let vividPalette: [Color] = [
    Color(hex: "FF6B6B"), // Coral red
    Color(hex: "4ECDC4"), // Teal
    Color(hex: "FFE66D"), // Sunshine yellow
    Color(hex: "A29BFE"), // Soft purple
    Color(hex: "FD79A8"), // Pink
    Color(hex: "55EFC4"), // Mint green
    Color(hex: "FDCB6E"), // Amber
    Color(hex: "74B9FF"), // Sky blue
    Color(hex: "E17055"), // Burnt orange
    Color(hex: "6C5CE7") // Deep purple
]

struct TrendBreakdownView: View {
    @Environment(AppStateViewModel.self) private var appStateViewModel
    @Query private var allTransactions: [Transaction]

    let title: String
    let startDate: Date
    let endDate: Date
    let total: Money

    @State private var animateChart = false

    private var filteredTransactions: [Transaction] {
        allTransactions.filter {
            !$0.isArchived &&
                $0.type == .expense &&
                $0.date >= startDate &&
                $0.date <= endDate
        }
    }

    private var breakdown: [CategoryTotal] {
        let uncategorisedID = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
        let grouped = Dictionary(grouping: filteredTransactions, by: { $0.category?.id ?? uncategorisedID })
        return grouped.map { _, tList -> CategoryTotal in
            let total = tList.reduce(Money.zero) { $0 + $1.money }
            let category = tList.first { $0.category != nil }?.category
            return CategoryTotal(category: category, total: total, transactionCount: tList.count)
        }.sorted { $0.total.amount > $1.total.amount }
    }

    private func vividColor(for index: Int) -> Color {
        vividPalette[index % vividPalette.count]
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Summary Header
                VStack(spacing: 8) {
                    Text("Total Spent")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)

                    Text(total.formatted(with: appStateViewModel.userCurrency))
                        .font(.system(size: 34, weight: .black, design: .rounded))
                        .foregroundStyle(.red)

                    Text("\(startDate.formatted(.dateTime.day().month())) – \(endDate.formatted(.dateTime.day().month().year()))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 8)

                // Category Bar Chart
                if !breakdown.isEmpty {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Category Breakdown")
                            .font(.headline)

                        let maxAmount = breakdown.map(\.total.amount).max() ?? 1

                        Chart(Array(breakdown.enumerated()), id: \.element.id) { index, item in
                            BarMark(
                                x: .value("Amount", animateChart ? item.total.amount : 0),
                                y: .value("Category", item.categoryName)
                            )
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [vividColor(for: index), vividColor(for: index).opacity(0.6)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(8)
                            .annotation(position: .trailing, alignment: .leading, spacing: 8) {
                                Text(item.total.formatted(with: appStateViewModel.userCurrency))
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(vividColor(for: index))
                            }
                        }
                        .chartXScale(domain: 0 ... (maxAmount * 1.3))
                        .chartXAxis(.hidden)
                        .chartYAxis {
                            AxisMarks { _ in
                                AxisValueLabel()
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(height: CGFloat(max(120, breakdown.count * 52)))
                        .animation(.spring(response: 0.7, dampingFraction: 0.8), value: animateChart)

                        // Color legend
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                            ForEach(Array(breakdown.enumerated()), id: \.element.id) { index, item in
                                HStack(spacing: 8) {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(vividColor(for: index))
                                        .frame(width: 12, height: 12)
                                    Text(item.categoryName)
                                        .font(.caption.bold())
                                        .foregroundStyle(FintechDesign.primaryText)
                                        .lineLimit(1)
                                    Spacer()
                                }
                            }
                        }
                        .padding(.top, 4)
                    }
                    .padding(24)
                    .background(
                        FintechDesign.CardBackground()
                            .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                    )
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            animateChart = true
                        }
                    }
                }

                // Transaction List
                if !filteredTransactions.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Transactions (\(filteredTransactions.count))")
                            .font(.headline)

                        VStack(spacing: 0) {
                            ForEach(Array(filteredTransactions.sorted { $0.date > $1.date }.enumerated()), id: \.element.id) { index, txn in
                                let catIndex = breakdown.firstIndex(where: { $0.category?.id == txn.category?.id }) ?? index
                                let iconColor = vividColor(for: catIndex)

                                HStack(spacing: 14) {
                                    Circle()
                                        .fill(iconColor.opacity(0.15))
                                        .frame(width: 42, height: 42)
                                        .overlay {
                                            Image(systemName: txn.category?.iconName ?? "questionmark")
                                                .font(.system(size: 15, weight: .bold))
                                                .foregroundStyle(iconColor)
                                        }

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
                                }
                                .padding(.vertical, 14)

                                if index < filteredTransactions.count - 1 {
                                    Divider()
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
            .padding()
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.large)
        .background(FintechDesign.Background())
    }
}
