import SwiftUI

struct GoalsView: View {
    @Environment(GoalsViewModel.self) private var goalsViewModel
    @Environment(AppStateViewModel.self) private var appStateViewModel

    @State private var goalToFund: Goal?

    var body: some View {
        NavigationStack {
            Group {
                if goalsViewModel.activeGoals.isEmpty && goalsViewModel.completedGoals.isEmpty {
                    emptyStateView
                } else {
                    List {
                        availableToSaveBanner
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                            .padding(.bottom, 8)

                        if !goalsViewModel.activeGoals.isEmpty {
                            Section("Active Goals") {
                                ForEach(goalsViewModel.activeGoals) { goal in
                                    NavigationLink(value: goal) {
                                        GoalCardRow(goal: goal, viewModel: goalsViewModel) {
                                            goalToFund = goal
                                        }
                                    }
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive) {
                                            goalsViewModel.delete(goal)
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                                    .swipeActions(edge: .leading) {
                                        Button {
                                            goalsViewModel.presentEdit(goal)
                                        } label: {
                                            Label("Edit", systemImage: "pencil")
                                        }
                                        .tint(.blue)
                                    }
                                }
                            }
                        }
                        
                        if !goalsViewModel.completedGoals.isEmpty {
                            Section("Completed / Expired") {
                                ForEach(goalsViewModel.completedGoals) { goal in
                                    NavigationLink(value: goal) {
                                        GoalCardRow(goal: goal, viewModel: goalsViewModel, onFund: nil)
                                            .opacity(0.6)
                                    }
                                    .swipeActions(edge: .trailing) {
                                        Button(role: .destructive) {
                                            goalsViewModel.delete(goal)
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .navigationDestination(for: Goal.self) { targetGoal in
                        GoalDetailView(goal: targetGoal)
                    }
                }
            }
            .navigationTitle("Goals")
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
        VStack(spacing: 4) {
            Text("Available to Save")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            Text(goalsViewModel.availableToSave.formatted)
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(.green)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(uiColor: .systemBackground))
                .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
        )
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "target")
                .font(.system(size: 64))
                .foregroundStyle(.tertiary)
            
            Text("No Goals Yet")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Set up savings goals or spending challenges to stay on track.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Button("Create a Goal") {
                goalsViewModel.presentAdd()
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemGroupedBackground))
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
                
                Text(viewModel.status(for: goal).label)
                    .font(.caption)
                    .fontWeight(.bold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(viewModel.status(for: goal).color.opacity(0.15))
                    .foregroundStyle(viewModel.status(for: goal).color)
                    .clipShape(Capsule())
            }
            
            if goal.type == .savings {
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
                                .font(.caption)
                                .fontWeight(.bold)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.blue)
                                .foregroundStyle(.white)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            } else {
                Text(viewModel.progressLabel(for: goal))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            ProgressView(value: viewModel.progressFraction(for: goal))
                .tint(viewModel.status(for: goal).color)
            
            HStack {
                Text(goal.type.label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Text("\(goal.daysRemaining) days left")
                    .font(.caption)
                    .foregroundStyle(goal.daysRemaining < 3 ? .red : .secondary)
            }
        }
        .padding(.vertical, 4)
        .overlay {
            if viewModel.status(for: goal) == .achieved && !goal.isExpired {
                // simple visual override for gamified hit
                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
            }
        }
    }
}
