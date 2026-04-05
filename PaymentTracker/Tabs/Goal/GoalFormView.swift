import SwiftUI

enum GoalFormMode {
    case add
    case edit(Goal)
}

struct GoalFormView: View {
    @Environment(GoalsViewModel.self) private var goalsViewModel
    @Environment(\.dismiss) private var dismiss

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
            Text(isEditing ? "Edit goal" : "New goal")
                .navigationTitle(isEditing ? "Edit goal" : "New goal")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(role: .cancel) { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(role: .confirm) { save() }
                            .disabled(title.isEmpty)
                    }
                }
        }
        .onAppear { populateIfEditing() }
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
