import SwiftUI
import SwiftData
import Charts

struct GoalDetailView: View {
    let goal: Goal
    
    @Environment(GoalsViewModel.self) private var goalsViewModel
    @Environment(\.modelContext) private var modelContext
    
    @Query private var allTransactions: [Transaction]
    
    init(goal: Goal) {
        self.goal = goal
        let descriptor = FetchDescriptor<Transaction>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        _allTransactions = Query(descriptor)
    }
    
    private var associatedTransactions: [Transaction] {
        switch goal.type {
        case .savings:
            return allTransactions.filter { $0.type == .transfer && $0.linkedGoal?.id == goal.id }
        case .budgetCap, .noSpend:
            return allTransactions.filter { 
                $0.type == .expense && 
                $0.date >= goal.startDate && 
                $0.date <= goal.deadline &&
                goal.blockedCategoryIDs.contains($0.category?.id ?? UUID())
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header Status
                VStack(spacing: 12) {
                    GoalCardRow(goal: goal, viewModel: goalsViewModel, onFund: nil)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color(uiColor: .secondarySystemGroupedBackground))
                                .shadow(color: .black.opacity(0.02), radius: 5, x: 0, y: 2)
                        )
                }
                
                // Content Section
                VStack(alignment: .leading, spacing: 16) {
                    Text(goal.type == .savings ? "Funding History" : "Affecting Transactions")
                        .font(.headline)
                        .padding(.horizontal, 4)
                        
                    if associatedTransactions.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "list.dash")
                                .font(.largeTitle)
                                .foregroundStyle(.tertiary)
                            Text("No activity found for this goal.")
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 32)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color(uiColor: .secondarySystemGroupedBackground))
                        )
                    } else {
                        VStack(spacing: 0) {
                            ForEach(Array(associatedTransactions.enumerated()), id: \.element.id) { index, txn in
                                TransactionRow(transaction: txn)
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 16)
                                
                                if index < associatedTransactions.count - 1 {
                                    Divider().padding(.leading, 64)
                                }
                            }
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color(uiColor: .secondarySystemGroupedBackground))
                        )
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Goal Details")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(uiColor: .systemGroupedBackground))
    }
}
