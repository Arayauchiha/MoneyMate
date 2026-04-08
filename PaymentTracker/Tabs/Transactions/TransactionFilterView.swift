import SwiftUI
import SwiftData

struct TransactionFilterView: View {
    @Environment(TransactionViewModel.self) private var transactionViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @Query(sort: \Category.name) private var categories: [Category]

    // Local state for two-way binding, we will apply changes on dismiss if needed,
    // or bind directly to the view model since it uses `@Observable`.
    // It's cleaner to bind directly for instant filtering if we want, or just wait.
    // The view model is an `@Observable` class, so we can use `@Bindable`.
    var body: some View {
        @Bindable var tvm = transactionViewModel
        
        NavigationStack {
            Form {
                Section("Type") {
                    Picker("Transaction Type", selection: $tvm.selectedType) {
                        Text("All").tag(TransactionType?.none)
                        ForEach(TransactionType.allCases) { t in
                            Text(t.label).tag(TransactionType?.some(t))
                        }
                    }
                }
                
                Section("Category") {
                    Picker("Category", selection: $tvm.selectedCategory) {
                        Label("All Categories", systemImage: "square.grid.2x2")
                            .tag(Category?.none)
                        
                        Divider()
                        
                        ForEach(categories) { cat in
                            Label(cat.name, systemImage: cat.iconName)
                                .tag(Category?.some(cat))
                        }
                    }
                }
                
                Section("Date Range") {
                    // Start date toggle
                    Toggle("Filter by Start Date", isOn: Binding(
                        get: { tvm.dateFrom != nil },
                        set: { if $0 { tvm.dateFrom = .now } else { tvm.dateFrom = nil } }
                    ))
                    
                    if let from = tvm.dateFrom {
                        DatePicker("From", selection: Binding(
                            get: { from },
                            set: { tvm.dateFrom = $0 }
                        ), displayedComponents: .date)
                    }
                    
                    // End date toggle
                    Toggle("Filter by End Date", isOn: Binding(
                        get: { tvm.dateTo != nil },
                        set: { if $0 { tvm.dateTo = .now } else { tvm.dateTo = nil } }
                    ))
                    
                    if let to = tvm.dateTo {
                        DatePicker("To", selection: Binding(
                            get: { to },
                            set: { tvm.dateTo = $0 }
                        ), displayedComponents: .date)
                    }
                }
            }
            .navigationTitle("Filter (\(transactionViewModel.activeFilterCount))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Reset") { transactionViewModel.clearFilters() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
