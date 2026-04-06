import SwiftUI
import SwiftData
import Charts

struct HomeView: View {
    @Environment(HomeViewModel.self) private var homeViewModel
    @Environment(AppStateViewModel.self) private var appStateViewModel
    @Environment(TransactionViewModel.self) private var transactionViewModel
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Transaction.date, order: .reverse) private var allTransactions: [Transaction]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // MARK: - Balance Hero Card
                    Button {
                        appStateViewModel.selectedTab = .insights
                    } label: {
                        HomeHeroCard()
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal)
                    .padding(.top, 16)

                    // MARK: - Weekly Trend
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Spending This Week")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        NavigationLink {
                            WeeklySpendingDetailView()
                        } label: {
                            WeeklyTrendChart()
                                .frame(height: 200)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal)
                    }

                    // MARK: - Recent Activity
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Recent Transactions")
                                .font(.headline)
                            Spacer()
                            Button("See All") {
                                appStateViewModel.selectedTab = .transactions
                            }
                            .font(.subheadline)
                        }
                        .padding(.horizontal)

                        RecentTransactionsList()
                    }
                }
                .padding(.bottom, 100)
            }
            .navigationTitle("Home")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 16) {
                        Button {
                            appStateViewModel.isAddTransactionPresented = true
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                        }
                        
                        Button {
                            appStateViewModel.isSettingsPresented = true
                        } label: {
                            Image(systemName: "gearshape.fill")
                                .foregroundStyle(.primary)
                        }
                    }
                }
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .onAppear {
                homeViewModel.refresh()
            }
            .refreshable {
                homeViewModel.refresh()
            }
            .onChange(of: allTransactions) { _, newValue in
                homeViewModel.refresh()
            }
        }
    }
}

// MARK: - Subviews

struct HomeHeroCard: View {
    @Environment(HomeViewModel.self) private var homeViewModel
    @Environment(AppStateViewModel.self) private var appStateViewModel

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Text("Total Balance")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(homeViewModel.totalBalance.formatted(with: appStateViewModel.userCurrency))
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                
                if !homeViewModel.expendableAmount.isZero {
                    HStack(spacing: 4) {
                        Text(homeViewModel.expendableAmount.formatted(with: appStateViewModel.userCurrency))
                            .fontWeight(.semibold)
                        Text("safe to spend")
                    }
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.blue.opacity(0.1), in: Capsule())
                    .foregroundStyle(.blue)
                }
            }
            
            HStack(spacing: 40) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.down.circle.fill")
                        .foregroundStyle(.green)
                    VStack(alignment: .leading) {
                        Text("Income")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(homeViewModel.totalIncome.formatted(with: appStateViewModel.userCurrency))
                            .font(.subheadline.bold())
                    }
                }
                
                HStack(spacing: 8) {
                    Image(systemName: "arrow.up.circle.fill")
                        .foregroundStyle(.red)
                    VStack(alignment: .leading) {
                        Text("Expenses")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(homeViewModel.totalExpenses.formatted(with: appStateViewModel.userCurrency))
                            .font(.subheadline.bold())
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
                .shadow(color: .black.opacity(0.04), radius: 15, x: 0, y: 10)
        )
    }
}

struct WeeklyTrendChart: View {
    @Environment(HomeViewModel.self) private var homeViewModel
    @Environment(AppStateViewModel.self) private var appStateViewModel

    var body: some View {
        VStack {
            if homeViewModel.weeklyChartData.isEmpty {
                ContentUnavailableView("No Data Yet", systemImage: "chart.bar", description: Text("Add transactions to see trends."))
            } else {
                Chart {
                    ForEach(homeViewModel.weeklyChartData) { data in
                        BarMark(
                            x: .value("Day", data.dayLabel),
                            y: .value("Amount", data.total.amount)
                        )
                        .foregroundStyle(Color.red.gradient)
                        .cornerRadius(6)
                    }
                }
                .chartYAxis(.hidden)
                .chartXAxis {
                    AxisMarks { value in
                        AxisValueLabel()
                            .font(.caption2)
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
                .shadow(color: .black.opacity(0.02), radius: 10, x: 0, y: 4)
        )
    }
}

struct RecentTransactionsList: View {
    @Environment(HomeViewModel.self) private var homeViewModel
    @Environment(TransactionViewModel.self) private var transactionViewModel

    var body: some View {
        VStack(spacing: 12) {
            if homeViewModel.recentTransactions.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.largeTitle)
                        .foregroundStyle(.quaternary)
                    Text("No recent transactions")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                ForEach(homeViewModel.recentTransactions) { transaction in
                    TransactionCard(transaction: transaction) {
                        transactionViewModel.presentEdit(transaction)
                    }
                }
            }
        }
        .padding(.horizontal)
    }
}
