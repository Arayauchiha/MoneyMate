import SwiftUI
import SwiftData

enum AddEditTransactionMode {
    case add
    case edit(Transaction)
}

struct AddEditTransactionView: View {
    @Environment(TransactionViewModel.self) private var transactionViewModel
    @Environment(AppStateViewModel.self) private var appStateViewModel
    @Environment(GoalsViewModel.self) private var goalsViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @Query(sort: \Category.name) private var categories: [Category]

    let mode: AddEditTransactionMode

    @State private var amountText: String = ""
    @State private var type: TransactionType = .expense
    @State private var category: Category?
    @State private var date: Date = .now
    @State private var repeatFrequency: String = "never"
    @State private var title: String = ""
    @State private var note: String = ""
    @State private var customCategoryName: String = ""
    @State private var selectedGoal: Goal? = nil

    @State private var showSuccessAlert = false
    @State private var successMessage = ""

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    private var existingTransaction: Transaction? {
        if case let .edit(t) = mode { return t }
        return nil
    }
    
    private var sortedCategories: [Category] {
        let regulars = categories.filter { $0.name != "Miscellaneous" }
        let other = categories.first { $0.name == "Miscellaneous" }
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
                        ForEach(TransactionType.allCases.filter { $0 != .transfer }) { tType in
                            Text(tType.label).tag(tType)
                        }
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                    .padding(.bottom, 8)
                }
                .listRowSeparator(.hidden)

                Section {
                    TextField("Title (e.g. Tuition Fee)", text: $title)
                        .font(.headline)
                    
                    HStack {
                        Text(appStateViewModel.userCurrency)
                            .foregroundStyle(.secondary)
                        TextField("Amount", text: $amountText)
                            .keyboardType(.decimalPad)
                            .font(.title2)
                    }
                }
                
                Section {
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                    
                    Picker("Repeat", selection: $repeatFrequency) {
                        Text("Never").tag("never")
                        Text("Daily").tag("daily")
                        Text("Weekly").tag("weekly")
                        Text("Monthly").tag("monthly")
                        Text("Yearly").tag("yearly")
                    }
                    
                    Picker("Category", selection: $category) {
                        Label("Uncategorised", systemImage: "questionmark.circle")
                            .tag(Category?.none)
                        
                        Divider()
                        
                        ForEach(sortedCategories) { cat in
                            Label(cat.name, systemImage: cat.iconName)
                                .tag(Category?.some(cat))
                        }
                        
                        Divider()
                        
                        Label("Create New Category", systemImage: "plus.circle")
                            .tag(Category?.some(Category(name: "__create_new__", iconName: "star.fill", colorHex: "BDC3C7")))
                    }
                    
                    if category?.name == "__create_new__" {
                        TextField("New Category Name", text: $customCategoryName)
                    }
                }
                
                if type == .transfer {
                    Section("Link to Goal") {
                        Picker("Goal", selection: $selectedGoal) {
                            Text("None").tag(Goal?.none)
                            ForEach(goalsViewModel.goals.filter { $0.type == .savings }) { g in
                                Text(g.title).tag(Goal?.some(g))
                            }
                        }
                    }
                }
                
                Section("Note") {
                    TextField("Personal memo", text: $note, axis: .vertical)
                        .lineLimit(3...10)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(isEditing ? "Edit" : "Add Transaction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    let amountValue = Decimal(string: amountText.replacingOccurrences(of: ",", with: ".")) ?? 0
                    let isTitleValid = !title.trimmingCharacters(in: .whitespaces).isEmpty
                    let isCategoryValid = category?.name != "__create_new__" || !customCategoryName.trimmingCharacters(in: .whitespaces).isEmpty
                    
                    Button("Save", role: .confirm) { save() }
                        .disabled(amountValue <= 0 || !isTitleValid || !isCategoryValid)
                }
            }
            .alert("Success!", isPresented: $showSuccessAlert) {
                Button("OK") { dismiss() }
            } message: {
                Text(successMessage)
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
        repeatFrequency = existingTransaction.repeatFrequency
        title = existingTransaction.title
        note = existingTransaction.note
        selectedGoal = existingTransaction.linkedGoal
    }

    private func save() {
        let separator = Locale.current.decimalSeparator ?? "."
        let cleaned = amountText.filter { $0.isNumber || String($0) == separator }
        guard let decimalAmount = Decimal(string: cleaned) else { return }
        let money = Money(decimalAmount)
        
        var finalCategory = category
        if category?.name == "__create_new__", !customCategoryName.trimmingCharacters(in: .whitespaces).isEmpty {
            let cleanedName = customCategoryName.trimmingCharacters(in: .whitespaces)
            if let existing = categories.first(where: { $0.name.lowercased() == cleanedName.lowercased() }) {
                finalCategory = existing
            } else {
                let vibrantColors = ["FF4757", "2ED573", "1E90FF", "ff6b81", "ffa502", "3742fa", "A55EEA", "f7b731", "2bcbba"]
                let randomColor = vibrantColors.randomElement() ?? "BDC3C7"
                let newCategory = Category(name: cleanedName, iconName: "star.fill", colorHex: randomColor, isSystem: false)
                modelContext.insert(newCategory)
                finalCategory = newCategory
            }
        }

        if let existingTransaction {
            transactionViewModel.update(transaction: existingTransaction, amount: money, type: type, category: finalCategory, date: date, title: title, note: note, repeatFrequency: repeatFrequency, linkedGoal: selectedGoal)
            successMessage = "Successfully updated \(title)"
        } else {
            transactionViewModel.add(amount: money, type: type, category: finalCategory, date: date, title: title, note: note, repeatFrequency: repeatFrequency, linkedGoal: selectedGoal)
            successMessage = "Successfully added \(title)"
        }
        
        showSuccessAlert = true
    }
}
