import SwiftUI

struct FundGoalView: View {
    let goal: Goal
    @Environment(GoalsViewModel.self) private var goalsViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var amountText: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .center, spacing: 8) {
                        Text(goal.title)
                            .font(.headline)
                        
                        Text("Available to Save")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(goalsViewModel.availableToSave.formatted)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(.green)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                
                Section("Funding Amount") {
                    HStack {
                        Text(Locale.current.currencySymbol ?? "$")
                            .foregroundStyle(.secondary)
                        TextField("0.00", text: $amountText)
                            .keyboardType(.decimalPad)
                            .font(.title3)
                    }
                }
            }
            .navigationTitle("Fund Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Transfer") {
                        save()
                    }
                    .disabled(amountText.isEmpty)
                }
            }
        }
    }

    private func save() {
        let separator = Locale.current.decimalSeparator ?? "."
        let cleaned = amountText.filter { $0.isNumber || String($0) == separator }
        let amount = Money(Decimal(string: cleaned) ?? .zero)
        
        goalsViewModel.fund(goal: goal, amount: amount)
        dismiss()
    }
}
