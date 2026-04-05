import SwiftUI
import SwiftData

struct TransactionsView: View {
    @Environment(TransactionViewModel.self) private var transactionViewModel
    @Environment(AppStateViewModel.self) private var appStateViewModel
    
    @State private var transactionToDelete: Transaction?
    @State private var selectedTransactions: Set<Transaction.ID> = []
    @State private var editMode: EditMode = .inactive
    
    // Alert state logic
    enum AlertType { case none, archive, delete }
    @State private var activeAlert: AlertType = .none

    var sortedFilteredTransactions: [Transaction] {
        transactionViewModel.filteredTransactions
    }

    var groupedTransactions: [(Date, [Transaction])] {
        let grouped = Dictionary(grouping: sortedFilteredTransactions) { txn in
            Calendar.current.startOfDay(for: txn.date)
        }
        return grouped.sorted { $0.key > $1.key }
    }

    var body: some View {
        @Bindable var tvm = transactionViewModel
        
        NavigationStack {
            List(selection: $selectedTransactions) {
                if transactionViewModel.filteredTransactions.isEmpty {
                    emptyStateView
                } else {
                    ForEach(groupedTransactions, id: \.0) { date, txns in
                        Section {
                            ForEach(txns) { transaction in
                                TransactionCard(transaction: transaction) {
                                    if editMode == .inactive {
                                        transactionViewModel.presentEdit(transaction)
                                    }
                                }
                                .tag(transaction.id)
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    if editMode == .inactive {
                                        Button {
                                            transactionToDelete = transaction
                                            activeAlert = .archive
                                        } label: {
                                            Label("Archive", systemImage: "archivebox.fill")
                                        }
                                        .tint(.orange)
                                    }
                                }
                                .contextMenu {
                                    if editMode == .inactive {
                                        Button { transactionViewModel.presentEdit(transaction) } label: { Label("Edit", systemImage: "pencil") }
                                        Button(role: .destructive) { transactionToDelete = transaction; activeAlert = .archive } label: { Label("Archive", systemImage: "archivebox") }
                                    }
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
                                .onTapGesture {
                                    if editMode == .inactive && !sortedFilteredTransactions.isEmpty {
                                        withAnimation {
                                            editMode = .active
                                            appStateViewModel.isTabBarHidden = true
                                        }
                                    }
                                }
                        }
                        .textCase(nil)
                    }
                }
            }
            .listStyle(.plain)
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Transactions")
            .searchable(text: $tvm.searchQuery, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search notes or amounts")
            .alert(alertTitle, isPresented: Binding(
                get: { activeAlert != .none },
                set: { if !$0 { activeAlert = .none; transactionToDelete = nil } }
            )) {
                if activeAlert == .archive {
                    let count = transactionToDelete != nil ? 1 : selectedTransactions.count
                    Button("Archive \(count > 1 ? "\(count) Items" : "Item")", role: .destructive) {
                        if let toDelete = transactionToDelete {
                            transactionViewModel.archive(toDelete)
                        } else {
                            archiveSelected()
                        }
                    }
                } else if activeAlert == .delete {
                    Button("Delete Permanently", role: .destructive) {
                        deleteSelected()
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                alertMessage
            }
            .toolbar {
                if editMode == .active {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") {
                            exitEditMode()
                        }
                        .fontWeight(.bold)
                    }
                    ToolbarItem(placement: .topBarLeading) {
                        Button(selectedTransactions.count == sortedFilteredTransactions.count ? "Deselect All" : "Select All") {
                            toggleSelectAll()
                        }
                    }
                    
                    ToolbarItemGroup(placement: .bottomBar) {
                        Button("Archive") {
                            activeAlert = .archive
                        }
                        .disabled(selectedTransactions.isEmpty)
                        
                        Spacer()
                        
                        Button(role: .destructive) {
                            activeAlert = .delete
                        } label: {
                            Image(systemName: "trash")
                                .foregroundStyle(.red)
                        }
                        .disabled(selectedTransactions.isEmpty)
                    }
                } else {
                    ToolbarItem(placement: .topBarTrailing) {
                        HStack(spacing: 12) {
                            Button("Edit") { 
                                withAnimation {
                                    editMode = .active 
                                    appStateViewModel.isTabBarHidden = true
                                }
                            }
                            
                            Button {
                                transactionViewModel.presentAdd()
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title3)
                            }
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
            }
            .environment(\.editMode, $editMode)
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
            .toolbar(appStateViewModel.isTabBarHidden ? .hidden : .visible, for: .tabBar)
        }
    }
    
    private var alertTitle: String {
        switch activeAlert {
        case .archive: return "Confirm Archive"
        case .delete: return "Delete Forever"
        case .none: return ""
        }
    }
    
    private var alertMessage: Text {
        switch activeAlert {
        case .archive:
            return Text("Archive \(selectedTransactions.count > 0 ? "\(selectedTransactions.count)" : "this") transaction? It will still count towards your balance.")
        case .delete:
            return Text("Everything selected will be permanently removed. This will also restore the amounts back to your available balance. This cannot be undone.")
        case .none:
            return Text("")
        }
    }

    private func exitEditMode() {
        withAnimation {
            editMode = .inactive
            appStateViewModel.isTabBarHidden = false
            selectedTransactions.removeAll()
        }
    }
    
    private func toggleSelectAll() {
        withAnimation(.snappy(duration: 0.2)) {
            if selectedTransactions.count == sortedFilteredTransactions.count {
                selectedTransactions.removeAll()
            } else {
                selectedTransactions = Set(sortedFilteredTransactions.map { $0.id })
            }
        }
    }

    private func archiveSelected() {
        let targets = sortedFilteredTransactions.filter { selectedTransactions.contains($0.id) }
        transactionViewModel.archiveMultiple(targets)
        exitEditMode()
    }

    private func deleteSelected() {
        let targets = sortedFilteredTransactions.filter { selectedTransactions.contains($0.id) }
        transactionViewModel.deleteMultiplePermanently(targets)
        exitEditMode()
    }

    private var emptyStateView: some View {
        VStack {
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
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }
}
