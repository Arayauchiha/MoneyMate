import SwiftUI
import SwiftData

struct ArchivedTransactionsView: View {
    @Environment(TransactionViewModel.self) private var transactionViewModel
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Transaction> { $0.isArchived == true }, sort: \.date, order: .reverse) private var archivedTransactions: [Transaction]
    
    @State private var transactionToDelete: Transaction?
    
    var body: some View {
        List {
            Section {
                if archivedTransactions.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "archivebox")
                            .font(.system(size: 48))
                            .foregroundStyle(.quaternary)
                        Text("No archived transactions.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 60)
                } else {
                    ForEach(archivedTransactions) { txn in
                        TransactionCard(transaction: txn)
                            .swipeActions(edge: .leading) {
                                Button {
                                    transactionViewModel.restore(txn)
                                } label: {
                                    Label("Restore", systemImage: "arrow.uturn.backward")
                                }
                                .tint(.green)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    transactionToDelete = txn
                                } label: {
                                    Label("Delete Forever", systemImage: "trash.fill")
                                }
                            }
                    }
                }
            } header: {
                Text("Recently Deleted")
            } footer: {
                if !archivedTransactions.isEmpty {
                    Text("These transactions still count towards your balance to match your bank history. Restore them to see them in the main list, or delete forever to remove their impact.")
                }
            }
        }
        .navigationTitle("Archive")
        .alert("Permanent Delete", isPresented: Binding(
            get: { transactionToDelete != nil },
            set: { if !$0 { transactionToDelete = nil } }
        )) {
            Button("Delete Forever", role: .destructive) {
                if let toDelete = transactionToDelete {
                    transactionViewModel.deletePermanently(toDelete)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will permanently remove the record and restore the amount to your balance. This action cannot be undone.")
        }
    }
}
