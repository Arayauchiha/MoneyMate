import SwiftUI

struct TransactionsView: View {
    @Environment(TransactionViewModel.self) private var transactionViewModel
    @Environment(AppStateViewModel.self) private var appStateViewModel
    
    @State private var transactionToDelete: Transaction?

    var body: some View {
        @Bindable var tvm = transactionViewModel
        
        NavigationStack {
            VStack(spacing: 0) {
                if transactionViewModel.filteredTransactions.isEmpty {
                    emptyStateView
                } else {
                    List {
                        ForEach(transactionViewModel.filteredTransactions) { transaction in
                            Button {
                                transactionViewModel.presentEdit(transaction)
                            } label: {
                                TransactionRow(transaction: transaction)
                            }
                            .buttonStyle(.plain)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    transactionToDelete = transaction
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .leading) {
                                Button {
                                    transactionViewModel.presentEdit(transaction)
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(.blue)
                            }
                            .contextMenu {
                                Button { transactionViewModel.presentEdit(transaction) } label: { Label("Edit details", systemImage: "pencil") }
                                Button(role: .destructive) { transactionToDelete = transaction } label: { Label("Delete", systemImage: "trash") }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Transactions")
            .searchable(text: $tvm.searchQuery, prompt: "Search notes or amount")
            .alert("Delete Transaction", isPresented: Binding(
                get: { transactionToDelete != nil },
                set: { if !$0 { transactionToDelete = nil } }
            )) {
                Button("Delete", role: .destructive) {
                    if let toDelete = transactionToDelete {
                        transactionViewModel.delete(toDelete)
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Are you sure you want to delete this transaction? This action cannot be undone.")
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        transactionViewModel.presentAdd()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        transactionViewModel.isFilterSheetPresented = true
                    } label: {
                        Image(systemName: transactionViewModel.activeFilterCount > 0 ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                            .font(.title3)
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
        VStack(spacing: 16) {
            Image(systemName: "tray")
                .font(.system(size: 64))
                .foregroundStyle(.tertiary)
            
            Text("No Transactions")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("You haven't added any transactions yet. Tap the + button to add one.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            if transactionViewModel.activeFilterCount > 0 {
                Button("Clear Filters") {
                    transactionViewModel.clearFilters()
                }
                .buttonStyle(.bordered)
                .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemGroupedBackground))
    }
}
