import SwiftUI

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
            .navigationTitle("Overview")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        appStateViewModel.presentAddTransaction()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.blue)
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
    
    // MARK: - Balance Card
    private var balanceCard: some View {
        VStack(spacing: 16) {
            Text("Total Balance")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Text(homeViewModel.totalBalance.formatted)
                .font(.system(size: 40, weight: .bold, design: .rounded))
            
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
                .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
        )
    }
    
    // MARK: - Weekly Chart
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
                    .shadow(color: .black.opacity(0.03), radius: 8, x: 0, y: 2)
            )
        }
    }
    
    // MARK: - Recent Transactions
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
                    ForEach(Array(homeViewModel.recentTransactions.enumerated()), id: \.element.id) { index, txn in
                        Button {
                            // If they tap a transaction, pop the view or present edit sheet
                            transactionViewModel.presentEdit(txn)
                        } label: {
                            TransactionRow(transaction: txn)
                        }
                        .buttonStyle(.plain)
                        
                        if index < homeViewModel.recentTransactions.count - 1 {
                            Divider()
                                .padding(.leading, 56)
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color(uiColor: .secondarySystemGroupedBackground))
                        .shadow(color: .black.opacity(0.03), radius: 8, x: 0, y: 2)
                )
            }
        }
    }
}

// MARK: - Transaction Row Component
struct TransactionRow: View {
    let transaction: Transaction
    
    var body: some View {
        HStack(spacing: 16) {
            Circle()
                .fill(transaction.type.color.opacity(0.2))
                .frame(width: 44, height: 44)
                .overlay {
                    Image(systemName: transaction.type.systemImage)
                        .foregroundStyle(transaction.type.color)
                        .font(.title3)
                }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.note.isEmpty ? transaction.category?.name ?? transaction.type.label : transaction.note)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                
                Text(transaction.date, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Text(transaction.formattedAmount)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundStyle(transaction.type.color)
        }
        .padding(16)
        .contentShape(Rectangle()) // makes the entire row tappable
    }
}
