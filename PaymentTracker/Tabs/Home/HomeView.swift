import SwiftUI
import Charts

struct HomeView: View {
    @Environment(HomeViewModel.self) private var homeViewModel
    @Environment(AppStateViewModel.self) private var appStateViewModel
    @Environment(TransactionViewModel.self) private var transactionViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    balanceCard
                        .onTapGesture { appStateViewModel.navigate(to: .insights) }
                    
                    if !homeViewModel.weeklyChartData.isEmpty {
                        NavigationLink {
                            WeeklySpendingDetailView()
                        } label: {
                            weeklyChartSection
                        }
                        .buttonStyle(.plain)
                    }
                    
                    recentTransactionsSection
                }
                .padding()
            }
            .navigationTitle("Home")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        appStateViewModel.presentAddTransaction()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                    }
                }
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .task { await homeViewModel.load() }
            .refreshable { await homeViewModel.load() }
            .onChange(of: transactionViewModel.dataVersion) { _, _ in
                Task { await homeViewModel.load() }
            }
            .sheet(isPresented: .init(
                get: { transactionViewModel.isAddEditSheetPresented },
                set: { transactionViewModel.isAddEditSheetPresented = $0 }
            )) {
                AddEditTransactionView(
                    mode: transactionViewModel.transactionToEdit.map { .edit($0) } ?? .add
                )
            }
        }
    }
    
    private var balanceCard: some View {
        VStack(spacing: 16) {
            Text("Total Balance")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Text(homeViewModel.totalBalance.formatted)
                .font(.system(size: 40, weight: .bold, design: .rounded))
            
            if homeViewModel.totalBalance.amount != homeViewModel.expendableAmount.amount {
                let amounts = homeViewModel.expendableAmount
                if amounts.amount >= 0 {
                    Text("\(amounts.formatted) safe to spend after savings")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, -8)
                } else {
                    Text("Overspent by \(amounts.absolute.formatted) after savings goals")
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.top, -8)
                }
            }
            
            HStack(spacing: 40) {
                VStack(spacing: 4) {
                    HStack {
                        Image(systemName: "arrow.down.circle.fill")
                            .foregroundStyle(.green)
                        Text("Income")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text(homeViewModel.totalIncome.formattedCompact)
                        .font(.headline)
                }
                
                VStack(spacing: 4) {
                    HStack {
                        Image(systemName: "arrow.up.circle.fill")
                            .foregroundStyle(.red)
                        Text("Expenses")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text(homeViewModel.totalExpenses.formattedCompact)
                        .font(.headline)
                }
            }
            .padding(.top, 8)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
        )
    }
    
    private var weeklyChartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Spending This Week")
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
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .frame(height: 180)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
                    .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 2)
            )
        }
    }
    
    private var recentTransactionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Transactions")
                    .font(.headline)
                Spacer()
                Button("See All") {
                    appStateViewModel.navigate(to: .transactions)
                }
                .font(.subheadline)
            }
            .padding(.horizontal, 4)
            
            if homeViewModel.recentTransactions.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.largeTitle)
                        .foregroundStyle(.tertiary)
                    Text("No recent transactions")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color(uiColor: .secondarySystemGroupedBackground))
                )
            } else {
                VStack(spacing: 0) {
                    let txns = homeViewModel.recentTransactions
                    ForEach(0..<txns.count, id: \.self) { index in
                        let txn = txns[index]
                        Button {
                            transactionViewModel.presentEdit(txn)
                        } label: {
                            TransactionRow(transaction: txn)
                        }
                        .buttonStyle(.plain)
                        
                        if index < txns.count - 1 {
                            Divider()
                                .padding(.leading, 56)
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color(uiColor: .secondarySystemGroupedBackground))
                        .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 2)
                )
            }
        }
    }
}


