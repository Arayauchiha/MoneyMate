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
                                            Label("Delete", systemImage: "trash.fill")
                                        }
                                        
                                        Button {
                                            transactionViewModel.presentEdit(transaction)
                                        } label: {
                                            Label("Edit", systemImage: "pencil")
                                        }
                                        .tint(.blue)
                                    }
                                    .contextMenu {
                                        Button { transactionViewModel.presentEdit(transaction) } label: { Label("Edit", systemImage: "pencil") }
                                        Button(role: .destructive) { transactionToDelete = transaction } label: { Label("Delete", systemImage: "trash") }
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
                    Button {
                        transactionViewModel.isFilterSheetPresented = true
                    } label: {
                        Image(systemName: transactionViewModel.activeFilterCount > 0 ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                            .font(.headline)
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

struct TransactionCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let transaction: Transaction
    let action: () -> Void
    @State private var isPressed = false
    
    var body: some View {
        HStack(spacing: 16) {
            Circle()
                .fill(transaction.type.color.gradient)
                .frame(width: 48, height: 48)
                .overlay {
                    Image(systemName: transaction.type.systemImage)
                        .foregroundStyle(.white)
                        .font(.headline)
                }
            
            VStack(alignment: .leading, spacing: 4) {
                if transaction.type == .transfer, let goal = transaction.linkedGoal {
                    Text("Funded: \(goal.title)")
                        .font(.headline)
                        .foregroundStyle(.primary)
                } else {
                    Text(transaction.note.isEmpty ? transaction.category?.name ?? transaction.type.label : transaction.note)
                        .font(.headline)
                        .foregroundStyle(.primary)
                }
                
                if let category = transaction.category {
                    let tagColor = category.color
                    Text(category.name)
                        .font(.caption2)
                        .fontWeight(.black)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(tagColor.opacity(0.12), in: Capsule())
                        .foregroundStyle(colorScheme == .light ? tagColor.opacity(0.9) : tagColor)
                        .colorMultiply(colorScheme == .light ? Color(white: 0.6) : .white)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(transaction.formattedAmount)
                    .font(.headline)
                    .bold()
                    .foregroundStyle(transaction.type == .expense ? AnyShapeStyle(.primary) : AnyShapeStyle(Color.green))
                Text(transaction.date.formatted(.dateTime.hour().minute()))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
                .shadow(color: .black.opacity(isPressed ? 0.01 : 0.03), radius: isPressed ? 2 : 10, x: 0, y: isPressed ? 1 : 5)
        )
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .onTapGesture {
            action()
        }
        .onLongPressGesture(minimumDuration: .infinity, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }
}
