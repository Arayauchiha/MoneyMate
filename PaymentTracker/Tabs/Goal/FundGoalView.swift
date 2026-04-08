import SwiftUI

struct FundGoalView: View {
    let goal: Goal
    @Environment(GoalsViewModel.self) private var goalsViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var amountText: String = ""
    @State private var showErrorAlert: Bool = false
    @State private var errorMessage: String = ""
    @State private var showSuccessAlert: Bool = false
    @State private var successMessage: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .center, spacing: 12) {
                        Image(systemName: "hand.holding.heart.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(.blue.gradient)
                        
                        Text(goal.title)
                            .font(.headline)
                        
                        VStack(spacing: 4) {
                            Text("Available to Save")
                                .font(.caption2)
                                .textCase(.uppercase)
                                .foregroundStyle(.secondary)
                            Text(goalsViewModel.availableToSave.formatted)
                                .font(.title)
                                .fontWeight(.black)
                                .foregroundStyle(.green)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                }
                .listRowBackground(Color.clear)
                
                Section {
                    HStack {
                        Text(Locale.current.currencySymbol ?? "$")
                            .font(.title3.bold())
                            .foregroundStyle(.secondary)
                        TextField("0.00", text: $amountText)
                            .keyboardType(.decimalPad)
                            .font(.title2.bold())
                    }
                } header: {
                    Text("Funding Amount")
                } footer: {
                    Text("This amount will be transferred from your available daily balance into this goal.")
                }
            }
            .navigationTitle("Fund Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    let amountValue = Decimal(string: amountText.replacingOccurrences(of: ",", with: ".")) ?? 0
                    Button("Transfer") {
                        validateAndSave()
                    }
                    .disabled(amountValue <= 0)
                    .fontWeight(.bold)
                }
            }
            .alert("Transfer Failed", isPresented: $showErrorAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .alert("Funding Successful! 🎉", isPresented: $showSuccessAlert) {
                Button("Great!") { dismiss() }
            } message: {
                Text(successMessage)
            }
        }
    }

    private func validateAndSave() {
        let separator = Locale.current.decimalSeparator ?? "."
        let cleaned = amountText.filter { $0.isNumber || String($0) == separator }
        let amountDecimal = Decimal(string: cleaned) ?? .zero
        let amount = Money(amountDecimal)
        
        let available = goalsViewModel.availableToSave
        
        if amountDecimal <= 0 {
            errorMessage = "Please enter a valid positive amount."
            showErrorAlert = true
            return
        }
        
        let current = goalsViewModel.currentAmount(for: goal).amount
        let needed = max(0, goal.targetAmount.amount - current)
        
        if amountDecimal > needed {
            errorMessage = "You only need \(Money(needed).formatted) more to achieve this goal. Please adjust your amount."
            showErrorAlert = true
            return
        }
        
        if amountDecimal > available.amount {
            errorMessage = "You only have \(available.formatted) available to save. Please enter a smaller amount."
            showErrorAlert = true
            return
        }
        
        goalsViewModel.fund(goal: goal, amount: amount)
        successMessage = "Nice work! You've successfully funded \(amount.formatted) towards '\(goal.title)'."
        showSuccessAlert = true
    }
}
