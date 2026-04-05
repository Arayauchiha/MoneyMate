import SwiftUI
import SwiftData

struct ArchivedTransactionsView: View {
    @Environment(TransactionViewModel.self) private var transactionViewModel
    @Environment(AppStateViewModel.self) private var appStateViewModel
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Transaction> { $0.isArchived == true }, sort: \.date, order: .reverse) private var archivedTransactions: [Transaction]
    
    @State private var transactionToDelete: Transaction?
    @State private var selectedTransactions: Set<Transaction.ID> = []
    @State private var editMode: EditMode = .inactive
    
    // Combined alert state
    enum AlertType { case none, delete, restore }
    @State private var activeAlert: AlertType = .none

    var body: some View {
        ZStack(alignment: .bottom) {
            Color(uiColor: .systemGroupedBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                if archivedTransactions.isEmpty {
                    ContentUnavailableView {
                        Label("No Archived Transactions", systemImage: "archivebox")
                    } description: {
                        Text("When you archive transactions, they will appear here.")
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(selection: $selectedTransactions) {
                        Section {
                            ForEach(archivedTransactions) { txn in
                                TransactionCard(transaction: txn)
                                    .tag(txn.id)
                                    .swipeActions(edge: .leading) {
                                        if editMode == .inactive {
                                            Button {
                                                transactionToDelete = txn
                                                activeAlert = .restore
                                            } label: {
                                                Label("Restore", systemImage: "arrow.uturn.backward")
                                            }
                                            .tint(.green)
                                        }
                                    }
                                    .swipeActions(edge: .trailing) {
                                        if editMode == .inactive {
                                            Button {
                                                transactionToDelete = txn
                                                activeAlert = .delete
                                            } label: {
                                                Label("Delete Forever", systemImage: "trash.fill")
                                            }
                                        }
                                    }
                                    .listRowSeparator(.hidden)
                                    .listRowBackground(Color.clear)
                                    .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                            }
                            
                            // Spacer item within the SAME section to avoid extra separators
                            Color.clear
                                .frame(height: 140)
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                        } header: {
                            Text("Recently Deleted")
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundStyle(.secondary)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 16)
                                .background(.ultraThinMaterial, in: Capsule())
                                .onTapGesture {
                                    if editMode == .inactive && !archivedTransactions.isEmpty {
                                        withAnimation {
                                            editMode = .active
                                            appStateViewModel.isTabBarHidden = true
                                        }
                                    }
                                }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            
            // Subdued Info Watermark at fixed bottom
            if !archivedTransactions.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "info.circle")
                        .font(.caption)
                    Text("These transactions still count towards your balance to match your bank history. Restore them to see them in the main list, or delete forever to remove their impact.")
                        .font(.system(size: 10, weight: .medium))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                .foregroundStyle(.secondary.opacity(0.4))
                .padding(.bottom, 24)
                .allowsHitTesting(false)
            }
        }
        .navigationTitle("Archive")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if editMode == .active {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        exitEditMode()
                    }
                    .fontWeight(.bold)
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button(selectedTransactions.count == archivedTransactions.count ? "Deselect All" : "Select All") {
                        toggleSelectAll()
                    }
                }
                
                ToolbarItemGroup(placement: .bottomBar) {
                    Button("Restore") {
                        activeAlert = .restore
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
                if !archivedTransactions.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Edit") {
                            withAnimation {
                                editMode = .active
                                appStateViewModel.isTabBarHidden = true
                            }
                        }
                    }
                }
            }
        }
        .environment(\.editMode, $editMode)
        .alert(alertTitle, isPresented: Binding(
            get: { activeAlert != .none },
            set: { if !$0 { activeAlert = .none; transactionToDelete = nil } }
        )) {
            if activeAlert == .delete {
                Button("Delete Permanently", role: .destructive) {
                    if let toDelete = transactionToDelete {
                        transactionViewModel.deletePermanently(toDelete)
                    } else {
                        deleteSelected()
                    }
                }
            } else if activeAlert == .restore {
                Button("Restore") {
                    if let toRestore = transactionToDelete {
                        transactionViewModel.restore(toRestore)
                    } else {
                        restoreSelected()
                    }
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            alertMessage
        }
        .toolbar(appStateViewModel.isTabBarHidden ? .hidden : .visible, for: .tabBar)
    }
    
    private var alertTitle: String {
        switch activeAlert {
        case .delete: return "Permanent Delete"
        case .restore: return "Restore"
        case .none: return ""
        }
    }
    
    private var alertMessage: Text {
        let count = transactionToDelete != nil ? 1 : selectedTransactions.count
        switch activeAlert {
        case .delete:
            return Text("This will permanently remove \(count > 1 ? "\(count) records" : "the record") and restore the amounts to your balance. This cannot be undone.")
        case .restore:
            return Text("Restore \(count) \(count > 1 ? "transactions" : "transaction") to your main list?")
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
            if selectedTransactions.count == archivedTransactions.count {
                selectedTransactions.removeAll()
            } else {
                selectedTransactions = Set(archivedTransactions.map { $0.id })
            }
        }
    }

    private func restoreSelected() {
        let targets = archivedTransactions.filter { selectedTransactions.contains($0.id) }
        transactionViewModel.restoreMultiple(targets)
        exitEditMode()
    }

    private func deleteSelected() {
        let targets = archivedTransactions.filter { selectedTransactions.contains($0.id) }
        transactionViewModel.deleteMultiplePermanently(targets)
        exitEditMode()
    }
}
