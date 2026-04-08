import SwiftUI
import SwiftData
import Charts

struct HomeView: View {
    @Environment(HomeViewModel.self) private var homeViewModel
    @Environment(AppStateViewModel.self) private var appStateViewModel
    @Environment(TransactionViewModel.self) private var transactionViewModel
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Transaction.date, order: .reverse) private var allTransactions: [Transaction]

    @State private var animateItems = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    // MARK: - Hero Wallet Card
                    Button {
                        appStateViewModel.selectedTab = .insights
                    } label: {
                        FintechDesign.WalletCard(
                            balance: homeViewModel.totalBalance.formatted(with: appStateViewModel.userCurrency),
                            safeToSpend: homeViewModel.expendableAmount.formatted(with: appStateViewModel.userCurrency),
                            income: homeViewModel.totalIncome.formatted(with: appStateViewModel.userCurrency),
                            expenses: homeViewModel.totalExpenses.formatted(with: appStateViewModel.userCurrency),
                            goals: homeViewModel.totalFundedToGoals.formatted(with: appStateViewModel.userCurrency),
                            cardHolder: appStateViewModel.userName
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.horizontal)
                    .offset(y: animateItems ? 0 : 20)
                    .opacity(animateItems ? 1 : 0)

                    // MARK: - Spending This Week
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Spending This Week")
                                .font(.headline)
                                .foregroundStyle(FintechDesign.adaptiveColor("1A1A1A", "FFFFFF"))
                            Spacer()
                            NavigationLink {
                                WeeklySpendingDetailView()
                            } label: {
                                Text("View Detail")
                                    .font(.subheadline)
                                    .foregroundStyle(FintechDesign.adaptiveColor("666666", "999999"))
                            }
                        }
                        .padding(.horizontal)

                        NavigationLink {
                            WeeklySpendingDetailView()
                        } label: {
                            WeeklyTrendChart()
                                .frame(height: 180)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal)
                    }
                    .offset(y: animateItems ? 0 : 30)
                    .opacity(animateItems ? 1 : 0)

                    // MARK: - Recent Activity
                    VStack(alignment: .leading, spacing: 18) {
                        HStack {
                            Text("Recent Transactions")
                                .font(.headline)
                                .foregroundStyle(FintechDesign.adaptiveColor("1A1A1A", "FFFFFF"))
                            Spacer()
                            Button("See All") {
                                appStateViewModel.selectedTab = .transactions
                            }
                            .font(.subheadline)
                            .foregroundStyle(FintechDesign.adaptiveColor("666666", "999999"))
                        }
                        .padding(.horizontal)

                        RecentTransactionsList()
                    }
                    .offset(y: animateItems ? 0 : 40)
                    .opacity(animateItems ? 1 : 0)
                }
                .padding(.bottom, 120)
            }
            .background(FintechDesign.Background())
            .navigationTitle("Hey, \(appStateViewModel.userName)")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        appStateViewModel.isSettingsPresented = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.title3)
                            .fontWeight(.semibold)
                    }
                }
            }
            .onAppear {
                homeViewModel.refresh()
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    animateItems = true
                }
            }
            .refreshable {
                homeViewModel.refresh()
            }
            .onChange(of: allTransactions) { _, _ in
                homeViewModel.refresh()
            }
        }
    }
}

// MARK: - Subviews

struct WeeklyTrendChart: View {
    @Environment(HomeViewModel.self) private var homeViewModel
    @Environment(AppStateViewModel.self) private var appStateViewModel
    @State private var isAnimated = false

    var body: some View {
        VStack {
            if homeViewModel.weeklyChartData.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "chart.bar.fill")
                        .font(.largeTitle)
                        .foregroundStyle(.white.opacity(0.1))
                    Text("No spending data this week")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.4))
                }
                .frame(maxWidth: .infinity, minHeight: 140)
            } else {
                Chart {
                    ForEach(homeViewModel.weeklyChartData) { data in
                        BarMark(
                            x: .value("Day", data.dayLabel),
                            y: .value("Amount", isAnimated ? data.total.amount : 0)
                        )
                        .foregroundStyle(FintechDesign.brandGradient)
                        .cornerRadius(6)
                    }
                }
                .chartYScale(domain: 0...(homeViewModel.weeklyChartData.map { $0.total.amount }.max() ?? 100))
                .chartYAxis(.hidden)
                .chartXAxis {
                    AxisMarks { _ in
                        AxisGridLine()
                            .foregroundStyle(Color.gray.opacity(0.1))
                        AxisValueLabel()
                            .font(.caption2)
                            .foregroundStyle(Color.gray)
                    }
                }
                .tint(Color.gray)
            }
        }
        .padding(24)
        .background(
            FintechDesign.CardBackground()
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 28)
                        .stroke(FintechDesign.adaptiveColor("E0E0E0", "FFFFFF").opacity(0.1), lineWidth: 1)
                )
        )
        .onAppear {
            isAnimated = false
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                isAnimated = true
            }
        }
        .onChange(of: homeViewModel.weeklyChartData) { _, _ in
            isAnimated = false
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                isAnimated = true
            }
        }
    }
}

struct RecentTransactionsList: View {
    @Environment(HomeViewModel.self) private var homeViewModel
    @Environment(TransactionViewModel.self) private var transactionViewModel

    var body: some View {
        VStack(spacing: 16) {
            if homeViewModel.recentTransactions.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "tray.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(.white.opacity(0.1))
                    Text("Your transaction history will appear here")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.4))
                        .multilineTextAlignment(.center)
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
