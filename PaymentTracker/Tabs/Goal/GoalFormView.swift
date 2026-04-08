import SwiftUI
import SwiftData

enum GoalFormMode {
    case add
    case edit(Goal)
}

struct GoalFormView: View {
    @Environment(GoalsViewModel.self) private var goalsViewModel
    @Environment(AppStateViewModel.self) private var appStateViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @Query(sort: \Category.name) private var categories: [Category]

    let mode: GoalFormMode

    @State private var title: String = ""
    @State private var type: GoalType = .savings
    @State private var targetAmountText: String = ""
    @State private var startDate: Date = .now
    @State private var deadline: Date = Calendar.current.date(byAdding: .month, value: 1, to: .now)!
    @State private var blockedCategories: [Category] = []
    
    @State private var isAddingCustomCategory = false
    @State private var customCategoryName = ""

    @State private var showSuccessAlert = false
    @State private var successMessage = ""

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    private var existingGoal: Goal? {
        if case let .edit(goal) = mode { return goal }
        return nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Goal Configuration") {
                    if !isEditing {
                        Picker("Type", selection: $type) {
                            ForEach(GoalType.allCases) { t in
                                Text(t.label).tag(t)
                            }
                        }
                    } else {
                        HStack {
                            Text("Type")
                            Spacer()
                            Text(type.label).foregroundStyle(.secondary)
                        }
                    }
                    
                    TextField("Title", text: $title)
                    
                    if type != .noSpend {
                        HStack {
                            Text(appStateViewModel.userCurrency)
                                .foregroundStyle(.secondary)
                            TextField(type == .dailyLimit ? "Daily Limit" : "Target Amount", text: $targetAmountText)
                                .keyboardType(.decimalPad)
                        }
                    }
                }
                
                Section("Timeframe") {
                    if type != .savings {
                        DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                    }
                    DatePicker("Deadline", selection: $deadline, in: startDate..., displayedComponents: .date)
                }
                
                if type == .budgetCap || type == .noSpend || type == .dailyLimit {
                    Section {
                        if categories.isEmpty {
                            Text("No categories available")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(categories) { cat in
                                Toggle(isOn: binding(for: cat)) {
                                    Label(cat.name, systemImage: cat.iconName)
                                }
                            }
                        }
                        
                        if isAddingCustomCategory {
                            HStack {
                                TextField("New Category Name", text: $customCategoryName)
                                Button("Add") {
                                    let cleaned = customCategoryName.trimmingCharacters(in: .whitespaces)
                                    if !cleaned.isEmpty && !categories.contains(where: { $0.name.lowercased() == cleaned.lowercased() }) {
                                        let newCat = Category(name: cleaned, iconName: "star.fill", colorHex: "BDC3C7", isSystem: false)
                                        modelContext.insert(newCat)
                                        blockedCategories.append(newCat)
                                    }
                                    customCategoryName = ""
                                    isAddingCustomCategory = false
                                }
                                .disabled(customCategoryName.trimmingCharacters(in: .whitespaces).isEmpty)
                            }
                        } else {
                            Button("Add Category...") {
                                isAddingCustomCategory = true
                            }
                        }
                        
                    } header: {
                        Text("Monitored Categories")
                    } footer: {
                        Text("Transactions in these categories will affect this goal's gamification.")
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(isEditing ? "Edit Goal" : "New Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    let isTitleValid = !title.trimmingCharacters(in: .whitespaces).isEmpty
                    let isAmountInValid = type != .noSpend && (Decimal(string: targetAmountText.replacingOccurrences(of: ",", with: ".")) ?? 0) <= 0
                    
                    Button("Save", role: .confirm) { save() }
                        .disabled(!isTitleValid || isAmountInValid)
                }
            }
            .alert("Goal Saved!", isPresented: $showSuccessAlert) {
                Button("OK") { dismiss() }
            } message: {
                Text(successMessage)
            }
            .onAppear {
                populateIfEditing()
            }
        }
    }
    
    private func binding(for category: Category) -> Binding<Bool> {
        Binding(
            get: {
                blockedCategories.contains(where: { $0.id == category.id })
            },
            set: { isSet in
                if isSet {
                    if !blockedCategories.contains(where: { $0.id == category.id }) {
                        blockedCategories.append(category)
                    }
                } else {
                    let targetID = category.id
                    blockedCategories.removeAll(where: { $0.id == targetID })
                }
            }
        )
    }

    private func populateIfEditing() {
        guard let existingGoal else { return }
        title = existingGoal.title
        type = existingGoal.type
        targetAmountText = existingGoal.targetAmount.formattedPlain
        startDate = existingGoal.startDate
        deadline = existingGoal.deadline
        blockedCategories = categories.filter { existingGoal.blockedCategoryIDs.contains($0.id) }
    }

    private func save() {
        let separator = Locale.current.decimalSeparator ?? "."
        let cleaned = targetAmountText.filter { $0.isNumber || String($0) == separator }
        let amount = Money(Decimal(string: cleaned) ?? .zero)

        if let existingGoal {
            goalsViewModel.update(goal: existingGoal, title: title, targetAmount: amount, startDate: startDate, deadline: deadline, blockedCategories: blockedCategories)
            successMessage = "Goal '\(title)' updated successfully!"
        } else {
            goalsViewModel.add(title: title, type: type, targetAmount: amount, startDate: startDate, deadline: deadline, blockedCategories: blockedCategories)
            successMessage = "New goal '\(title)' created successfully!"
        }
        
        showSuccessAlert = true
    }
}
