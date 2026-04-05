import SwiftUI
import SwiftData

enum AddEditTransactionMode {
    case add
    case edit(Transaction)
}

struct AddEditTransactionView: View {
    @Environment(TransactionViewModel.self) private var transactionViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @Query(sort: \Category.name) private var categories: [Category]

    let mode: AddEditTransactionMode

    @State private var amountText: String = ""
    @State private var type: TransactionType = .expense
    @State private var category: Category?
    @State private var date: Date = .now
    @State private var note: String = ""
    @State private var customCategoryName: String = ""

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    private var existingTransaction: Transaction? {
        if case let .edit(t) = mode { return t }
        return nil
    }
    
    private var sortedCategories: [Category] {
        let regulars = categories.filter { $0.name != "Other" }
        let other = categories.first { $0.name == "Other" }
        if let other {
            return regulars + [other]
        }
        return regulars
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Type", selection: $type) {
                        ForEach(TransactionType.allCases) { tType in
                            Text(tType.label).tag(tType)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    HStack {
                        Text(Locale.current.currencySymbol ?? "$")
                            .foregroundStyle(.secondary)
                        TextField("Amount", text: $amountText)
                            .keyboardType(.decimalPad)
                            .font(.title2)
                    }
                }
                
                Section {
                    DatePicker("Date", selection: $date, in: ...Date.now, displayedComponents: .date)
                    
                    Picker("Category", selection: $category) {
                        Text("None").tag(Category?.none)
                        ForEach(sortedCategories) { cat in
                            Text(cat.name).tag(Category?.some(cat))
                        }
                    }
                    
                    if category?.name == "Other" {
                        TextField("Custom Category Name", text: $customCategoryName)
                    }
                }
                
                Section("Note") {
                    TextField("Enter notes (Optional)", text: $note)
                }
            }
            .navigationTitle(isEditing ? "Edit" : "Add Transaction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", role: .confirm) { save() }
                        .disabled(amountText.isEmpty || (category?.name == "Other" && customCategoryName.trimmingCharacters(in: .whitespaces).isEmpty))
                }
            }
            .onAppear {
                populateIfEditing()
                if categories.isEmpty {
                    Category.systemCategories.forEach { modelContext.insert($0) }
                }
            }
        }
    }

    private func populateIfEditing() {
        guard let existingTransaction else { return }
        amountText = existingTransaction.money.formattedPlain
        type = existingTransaction.type
        category = existingTransaction.category
        date = existingTransaction.date
        note = existingTransaction.note
        
        if let catName = category?.name, catName != "Other", !categories.contains(where: { $0.id == category?.id && $0.isSystem }) {
            // If the transaction uses a custom category, you could potentially show it.
            // But since it's already an existing custom category, the Picker will just select it if it's in the list.
            // Wait, the "Other" logic only applies to making a NEW custom category.
        }
    }

    private func save() {
        let separator = Locale.current.decimalSeparator ?? "."
        let cleaned = amountText.filter { $0.isNumber || String($0) == separator }
        guard let decimalAmount = Decimal(string: cleaned) else { return }
        let money = Money(decimalAmount)
        
        var finalCategory = category
        if category?.name == "Other", !customCategoryName.trimmingCharacters(in: .whitespaces).isEmpty {
            let cleanedName = customCategoryName.trimmingCharacters(in: .whitespaces)
            if let existing = categories.first(where: { $0.name.lowercased() == cleanedName.lowercased() }) {
                finalCategory = existing
            } else {
                let newCategory = Category(name: cleanedName, iconName: "star.fill", colorHex: "BDC3C7", isSystem: false)
                modelContext.insert(newCategory)
                finalCategory = newCategory
            }
        }

        if let existingTransaction {
            transactionViewModel.update(transaction: existingTransaction, amount: money, type: type, category: finalCategory, date: date, note: note)
        } else {
            transactionViewModel.add(amount: money, type: type, category: finalCategory, date: date, note: note)
        }
        dismiss()
    }
}
