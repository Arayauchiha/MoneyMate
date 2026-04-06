import SwiftUI

struct GoalsView: View {
    @Environment(GoalsViewModel.self) private var goalsViewModel
    @Environment(AppStateViewModel.self) private var appStateViewModel
    @Environment(TransactionViewModel.self) private var transactionViewModel

    @State private var goalToFund: Goal?
    @State private var goalToDelete: Goal?
    @State private var detailToNavigate: InsightDetailType?

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
                            GoalSection(title: "Active Goals", goals: goalsViewModel.activeGoals, viewModel: goalsViewModel, appState: appStateViewModel, goalToDelete: $goalToDelete) { goal in
                                goalToFund = goal
                            }
                        }
                        
                        if !goalsViewModel.achievedGoals.isEmpty {
                            GoalSection(title: "Completed Goals", goals: goalsViewModel.achievedGoals, viewModel: goalsViewModel, appState: appStateViewModel, goalToDelete: $goalToDelete, onFund: nil)
                        }
                        
                        if !goalsViewModel.completedGoals.isEmpty {
                            GoalSection(title: "Archive", goals: goalsViewModel.completedGoals, viewModel: goalsViewModel, appState: appStateViewModel, goalToDelete: $goalToDelete, opacity: 0.6, onFund: nil)
                        }
                    }
                }
                .padding()
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Goals")
            .task {
                await goalsViewModel.load()
            }
            .onAppear {
                // Double check refresh on appear
                Task { await goalsViewModel.load() }
            }
            .onChange(of: transactionViewModel.dataVersion) { _, _ in
                Task { await goalsViewModel.load() }
            }
            .navigationDestination(for: Goal.self) { targetGoal in
                GoalDetailView(goal: targetGoal)
            }
            .navigationDestination(item: $detailToNavigate) { type in
                let (start, end) = TimePeriod.month.dateRange
                InsightsDetailView(type: type, startDate: start, endDate: end)
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
            .alert("Delete Goal?", isPresented: Binding(
                get: { goalToDelete != nil },
                set: { if !$0 { goalToDelete = nil } }
            )) {
                Button("Delete", role: .destructive) {
                    if let goal = goalToDelete {
                        goalsViewModel.delete(goal)
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will permanently remove the goal and all its tracking data. This cannot be undone.")
            }
        }
    }

    private var availableToSaveBanner: some View {
        TabView {
            // Card 1: Available to Save
            VStack(spacing: 8) {
                Text("Available to Save")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                
                let money = goalsViewModel.availableToSave
                Text("\(appStateViewModel.userCurrency)\(money.formattedPlain)")
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundStyle(money.isZero ? AnyShapeStyle(.secondary) : AnyShapeStyle(Color.green))
                
                if goalsViewModel.isOverspent {
                    Text("Capped at zero due to overspending.")
                        .font(.caption2)
                        .foregroundStyle(.red)
                } else {
                    Text("Ready for your next goal")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(24)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 32, style: .continuous))
            .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 5)
            .padding(.horizontal, 2)
            
            // Card 2: Funded to Goals
            Button {
                detailToNavigate = .fundedToGoals
            } label: {
                VStack(spacing: 8) {
                    Text("Total Goal Funding")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    
                    let funded = goalsViewModel.totalGoalFunding
                    Text("\(appStateViewModel.userCurrency)\(funded.formattedPlain)")
                        .font(.system(size: 34, weight: .black, design: .rounded))
                        .foregroundStyle(Color.blue)
                    
                    HStack(spacing: 4) {
                        Text("View Allocation Detail")
                        Image(systemName: "chevron.right")
                    }
                    .font(.caption2).bold()
                    .foregroundStyle(.blue)
                }
                .frame(maxWidth: .infinity)
                .padding(24)
                .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 32, style: .continuous))
                .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 5)
                .padding(.horizontal, 2)
            }
            .buttonStyle(.plain)
        }
        .frame(height: 180)
        .tabViewStyle(.page(indexDisplayMode: .always))
        .indexViewStyle(.page(backgroundDisplayMode: .always))
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
    let appState: AppStateViewModel
    @Binding var goalToDelete: Goal?
    var opacity: Double = 1.0
    var onFund: ((Goal) -> Void)? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
            
            ForEach(goals) { goal in
                NavigationLink(value: goal) {
                    GoalCardRow(goal: goal, viewModel: viewModel, appState: appState) {
                        onFund?(goal)
                    }
                    .padding()
                    .opacity(opacity)
                    .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .shadow(color: Color.black.opacity(0.02 * opacity), radius: 8, x: 0, y: 4)
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button { viewModel.presentEdit(goal) } label: { Label("Edit", systemImage: "pencil") }
                    Button(role: .destructive) { goalToDelete = goal } label: { Label("Delete", systemImage: "trash") }
                }
            }
        }
    }
}

struct GoalCardRow: View {
    let goal: Goal
    let viewModel: GoalsViewModel
    let appState: AppStateViewModel
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
                    Text(viewModel.progressLabel(for: goal, symbol: appState.userCurrency))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    if let onFund = onFund, goal.type == .savings, viewModel.status(for: goal) != .achieved {
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
