import SwiftUI

struct GoalsView: View {
    @Environment(GoalsViewModel.self) private var goalsViewModel
    @Environment(AppStateViewModel.self) private var appStateViewModel

    var body: some View {
        NavigationStack {
            Group {
                if goalsViewModel.activeGoals.isEmpty && goalsViewModel.completedGoals.isEmpty {
                    emptyStateView
                } else {
                    List {
                        if !goalsViewModel.activeGoals.isEmpty {
                            Section("Active Goals") {


                                ForEach(goalsViewModel.activeGoals) { goal in
                                    GoalCardRow(goal: goal, viewModel: goalsViewModel)
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
                                    GoalCardRow(goal: goal, viewModel: goalsViewModel)
                                        .opacity(0.6)
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
        }
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
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(viewModel.status(for: goal).color.opacity(0.15))
                    .foregroundStyle(viewModel.status(for: goal).color)
                    .clipShape(Capsule())
            }
            
            Text(viewModel.progressLabel(for: goal))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
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
    }
}
