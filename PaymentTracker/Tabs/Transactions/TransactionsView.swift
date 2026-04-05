import SwiftUI

struct TransactionsView: View {
    @Environment(TransactionViewModel.self) private var transactionViewModel
    @Environment(AppStateViewModel.self) private var appStateViewModel
    
    @State private var transactionToDelete: Transaction?

    var groupedTransactions: [(Date, [Transaction])] {
        let grouped = Dictionary(grouping: transactionViewModel.filteredTransactions) { txn in
            Calendar.current.startOfDay(for: txn.date)
        }
        return grouped.sorted { $0.key > $1.key }
    }

    var body: some View {
        @Bindable var tvm = transactionViewModel
        
        NavigationStack {
            ZStack {
                Color(uiColor: .systemGroupedBackground)
                    .ignoresSafeArea()
                
                if transactionViewModel.filteredTransactions.isEmpty {
                    emptyStateView
                } else {
                    List {
                        ForEach(groupedTransactions, id: \.0) { date, txns in
                            Section {
                                ForEach(txns) { transaction in
                                    TransactionCard(transaction: transaction) {
                                        transactionViewModel.presentEdit(transaction)
                                    }
                                    .overlay {
                                        // Invisible button to handle row-level tap more natively in List if needed
                                    }
                                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                        Button(role: .destructive) {
                                            transactionToDelete = transaction
                                        } label: {
                                            Label("Archive", systemImage: "archivebox.fill")
                                        }
                                        .tint(.orange)
                                        
                                        Button {
                                            transactionViewModel.presentEdit(transaction)
                                        } label: {
                                            Label("Edit", systemImage: "pencil")
                                        }
                                        .tint(.blue)
                                    }
                                    .contextMenu {
                                        Button { transactionViewModel.presentEdit(transaction) } label: { Label("Edit", systemImage: "pencil") }
                                        Button(role: .destructive) { transactionToDelete = transaction } label: { Label("Archive", systemImage: "archivebox") }
                                    }
                                    .listRowSeparator(.hidden)
                                    .listRowBackground(Color.clear)
                                    .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                                }
                            } header: {
                                Text(date.formatted(.dateTime.day().month(.wide).year()))
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.secondary)
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 16)
                                    .background(.ultraThinMaterial, in: Capsule())
                                    .padding(.leading, -4)
                            }
                            .textCase(nil) // Prevent default caps
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .animation(.spring(), value: tvm.filteredTransactions)
                }
            }
            .navigationTitle("Transactions")
            .searchable(text: $tvm.searchQuery, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search notes or amounts")
            .alert("Archive Transaction?", isPresented: Binding(
                get: { transactionToDelete != nil },
                set: { if !$0 { transactionToDelete = nil } }
            )) {
                Button("Archive", role: .destructive) {
                    if let toDelete = transactionToDelete {
                        transactionViewModel.archive(toDelete)
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will hide the transaction from your main list but keep its impact on your balance. You can restore it later from the Archive.")
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        transactionViewModel.presentAdd()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    HStack(spacing: 8) {
                        Button {
                            transactionViewModel.isFilterSheetPresented = true
                        } label: {
                            Image(systemName: transactionViewModel.activeFilterCount > 0 ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                                .font(.headline)
                        }
                        
                        NavigationLink(destination: ArchivedTransactionsView()) {
                            Image(systemName: "archivebox")
                                .font(.headline)
                        }
                    }
                }
            }
            .sheet(isPresented: .init(
                get: { transactionViewModel.isAddEditSheetPresented },
                set: { transactionViewModel.isAddEditSheetPresented = $0 }
            )) {
                AddEditTransactionView(
                    mode: transactionViewModel.transactionToEdit.map { .edit($0) } ?? .add
                )
            }
            .sheet(isPresented: .init(
                get: { transactionViewModel.isFilterSheetPresented },
                set: { transactionViewModel.isFilterSheetPresented = $0 }
            )) {
                TransactionFilterView()
            }
        }
    }
    
    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("No Transactions", systemImage: "tray.and.arrow.down.fill")
        } description: {
            Text("Try searching for something else or add a new transaction.")
        } actions: {
            if transactionViewModel.activeFilterCount > 0 {
                Button("Clear Filters") {
                    transactionViewModel.clearFilters()
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
}


