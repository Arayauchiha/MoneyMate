import SwiftUI

enum AddEditTransactionMode {
    case add
    case edit(Transaction)
}

struct AddEditTransactionView: View {
    @Environment(TransactionViewModel.self) private var transactionViewModel
    @Environment(\.dismiss) private var dismiss

    let mode: AddEditTransactionMode

    @State private var amountText: String = ""
    @State private var type: TransactionType = .expense
    @State private var category: Category?
    @State private var date: Date = .now
    @State private var note: String = ""

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    private var existingTransaction: Transaction? {
        if case let .edit(t) = mode { return t }
        return nil
    }

    var body: some View {
        NavigationStack {
            Text(isEditing ? "Edit transaction" : "Add transaction")
                .navigationTitle(isEditing ? "Edit" : "Add")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(role: .cancel) { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(role: .confirm) { save() }
                            .disabled(amountText.isEmpty)
                    }
                }
        }
        .onAppear { populateIfEditing() }
    }

    private func populateIfEditing() {
        guard let existingTransaction else { return }
        amountText = existingTransaction.money.formattedPlain
        type = existingTransaction.type
        category = existingTransaction.category
        date = existingTransaction.date
        note = existingTransaction.note
    }

    private func save() {
        let separator = Locale.current.decimalSeparator ?? "."
        let cleaned = amountText
            .filter { $0.isNumber || String($0) == separator }
        guard let decimalAmount = Decimal(string: cleaned) else { return }
        let money = Money(decimalAmount)

        if let existingTransaction {
            transactionViewModel.update(transaction: existingTransaction, amount: money, type: type, category: category, date: date, note: note)
        } else {
            transactionViewModel.add(amount: money, type: type, category: category, date: date, note: note)
        }
        dismiss()
    }
}
