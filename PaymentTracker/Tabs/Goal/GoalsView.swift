import SwiftUI

struct GoalsView: View {
    @Environment(GoalsViewModel.self) private var goalsViewModel
    @Environment(AppStateViewModel.self) private var appStateViewModel

    @State private var goalToFund: Goal?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    availableToSaveBanner
                    
                    if goalsViewModel.activeGoals.isEmpty && 
                       goalsViewModel.achievedGoals.isEmpty && 
                       goalsViewModel.completedGoals.isEmpty {
                        emptyStateView
                    } else {
                        if !goalsViewModel.activeGoals.isEmpty {
                            GoalSection(title: "Active Goals", goals: goalsViewModel.activeGoals, viewModel: goalsViewModel) { goal in
                                goalToFund = goal
                            }
                        }
                        
                        if !goalsViewModel.achievedGoals.isEmpty {
                            GoalSection(title: "Completed Goals", goals: goalsViewModel.achievedGoals, viewModel: goalsViewModel, onFund: nil)
                        }
                        
                        if !goalsViewModel.completedGoals.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Archive")
                                    .font(.headline)
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 4)
                                
                                ForEach(goalsViewModel.completedGoals) { goal in
                                    NavigationLink(value: goal) {
                                        GoalCardRow(goal: goal, viewModel: goalsViewModel, onFund: nil)
                                            .opacity(0.6)
                                            .padding()
                                            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Goals")
            .navigationDestination(for: Goal.self) { targetGoal in
                GoalDetailView(goal: targetGoal)
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        goalsViewModel.presentAdd()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                    }
                }
            }
            .sheet(isPresented: .init(
                get: { goalsViewModel.isGoalFormPresented },
                set: { goalsViewModel.isGoalFormPresented = $0 }
            )) {
                GoalFormView(mode: goalsViewModel.goalToEdit.map { .edit($0) } ?? .add)
            }
            .sheet(item: $goalToFund) { targetGoal in
                FundGoalView(goal: targetGoal)
            }
        }
    }

    private var availableToSaveBanner: some View {
        let money = goalsViewModel.availableToSave
        return VStack(spacing: 8) {
            Text("Available to Save")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            
            Text(money.formatted)
                .font(.system(size: 34, weight: .black, design: .rounded))
                .foregroundStyle(money.isZero ? AnyShapeStyle(.secondary) : AnyShapeStyle(Color.green))
            
            if money.isZero {
                Text("Capped at zero due to overspending.")
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(.red.opacity(0.1), in: Capsule())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
                .shadow(color: Color.black.opacity(0.02), radius: 10, x: 0, y: 5)
        )
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "target")
                .font(.system(size: 64))
                .foregroundStyle(.tertiary)
            Text("No Goals Yet").font(.title2).bold()
            Button("Create a Goal") { goalsViewModel.presentAdd() }.buttonStyle(.borderedProminent)
        }
        .padding(.top, 60)
    }
}

struct GoalSection: View {
    let title: String
    let goals: [Goal]
    let viewModel: GoalsViewModel
    var onFund: ((Goal) -> Void)?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
            
            ForEach(goals) { goal in
                NavigationLink(value: goal) {
                    GoalCardRow(goal: goal, viewModel: viewModel) {
                        onFund?(goal)
                    }
                    .padding()
                    .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .shadow(color: Color.black.opacity(0.02), radius: 8, x: 0, y: 4)
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button { viewModel.presentEdit(goal) } label: { Label("Edit", systemImage: "pencil") }
                    Button(role: .destructive) { viewModel.delete(goal) } label: { Label("Delete", systemImage: "trash") }
                }
            }
        }
    }
}

struct GoalCardRow: View {
    let goal: Goal
    let viewModel: GoalsViewModel
    var onFund: (() -> Void)? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: goal.type.systemImage)
                    .foregroundStyle(.blue)
                    .font(.title3)
                
                Text(goal.title)
                    .font(.headline)
                
                Spacer()
                
                let status = viewModel.status(for: goal)
                Text(status.label)
                    .font(.caption)
                    .fontWeight(.bold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(status.color.opacity(0.15))
                    .foregroundStyle(status.color)
                    .clipShape(Capsule())
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(viewModel.progressLabel(for: goal))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    if let onFund = onFund, viewModel.status(for: goal) != .achieved {
                        Button {
                            onFund()
                        } label: {
                            Text("Fund")
                                .font(.caption).bold()
                                .padding(.horizontal, 12).padding(.vertical, 6)
                                .background(Color.blue)
                                .foregroundStyle(.white)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                ProgressView(value: viewModel.progressFraction(for: goal))
                    .tint(viewModel.status(for: goal).color)
            }
            
            HStack {
                Text(goal.type.label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(goal.daysRemaining) days left")
                    .font(.caption2)
                    .foregroundStyle(goal.daysRemaining < 3 ? .red : .secondary)
            }
        }
    }
}
