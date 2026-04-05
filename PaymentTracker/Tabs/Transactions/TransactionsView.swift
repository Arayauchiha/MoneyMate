import SwiftUI

struct TransactionsView: View {
    @Environment(TransactionViewModel.self) private var transactionViewModel
    @Environment(AppStateViewModel.self) private var appStateViewModel

    var body: some View {
        NavigationStack {
            Text("Transactions — \(transactionViewModel.filteredTransactions.count) items")
                .navigationTitle("Transactions")
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            transactionViewModel.presentAdd()
                        } label: {
                            Label("Add", systemImage: "plus")
                        }
                    }
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            transactionViewModel.isFilterSheetPresented = true
                        } label: {
                            Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
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
}
