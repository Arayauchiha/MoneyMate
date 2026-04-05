import SwiftUI

struct TransactionFilterView: View {
    @Environment(TransactionViewModel.self) private var transactionViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Text("Filters — \(transactionViewModel.activeFilterCount) active")
                .navigationTitle("Filter")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Reset") { transactionViewModel.clearFilters() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(role: .confirm) { dismiss() }
                    }
                }
        }
    }
}
