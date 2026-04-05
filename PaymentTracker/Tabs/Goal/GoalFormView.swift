import SwiftUI
import SwiftData

enum GoalFormMode {
    case add
    case edit(Goal)
}

struct GoalFormView: View {
    @Environment(GoalsViewModel.self) private var goalsViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @Query(sort: \Category.name) private var categories: [Category]

    let mode: GoalFormMode

    @State private var title: String = ""
    @State private var type: GoalType = .savings
    @State private var targetAmountText: String = ""
    @State private var deadline: Date = Calendar.current.date(byAdding: .month, value: 1, to: .now)!
    @State private var blockedCategories: [Category] = []

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
                Section("Goal Details") {
                    TextField("Title", text: $title)
                    
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
                    
                    if type != .noSpend {
                        HStack {
                            Text(Locale.current.currencySymbol ?? "$")
                                .foregroundStyle(.secondary)
                            TextField("Target Amount", text: $targetAmountText)
                                .keyboardType(.decimalPad)
                        }
                    }
                    
                    DatePicker("Deadline", selection: $deadline, in: Date.now..., displayedComponents: .date)
                }
                
                if type == .budgetCap || type == .noSpend {
                    Section {
                        if categories.isEmpty {
                            Text("No categories available")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(categories) { cat in
                                Toggle(cat.name, isOn: binding(for: cat))
                            }
                        }
                    } header: {
                        Text("Monitored Categories")
                    } footer: {
                        Text("Transactions in these categories will affect this goal.")
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Goal" : "New Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", role: .confirm) { save() }
                        .disabled(title.isEmpty || (type != .noSpend && targetAmountText.isEmpty))
                }
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
        deadline = existingGoal.deadline
    }

    private func save() {
        let separator = Locale.current.decimalSeparator ?? "."
        let cleaned = targetAmountText.filter { $0.isNumber || String($0) == separator }
        let amount = Money(Decimal(string: cleaned) ?? .zero)

        if let existingGoal {
            goalsViewModel.update(goal: existingGoal, title: title, targetAmount: amount, deadline: deadline)
        } else {
            goalsViewModel.add(title: title, type: type, targetAmount: amount, deadline: deadline, blockedCategories: blockedCategories)
        }
        dismiss()
    }
}
