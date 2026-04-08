import SwiftUI
import SwiftData

struct GoalsView: View {
    @Environment(GoalsViewModel.self) private var goalsViewModel
    @Environment(AppStateViewModel.self) private var appStateViewModel
    @Environment(TransactionViewModel.self) private var transactionViewModel
    @Environment(\.modelContext) private var modelContext

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
                    .environment(goalsViewModel)
                    .environment(appStateViewModel)
                    .environment(transactionViewModel)
                    .modelContext(modelContext)
            }
            .navigationDestination(item: $detailToNavigate) { type in
                let (start, end) = TimePeriod.month.dateRange
                InsightsDetailView(type: type, startDate: start, endDate: end)
                    .environment(goalsViewModel)
                    .environment(appStateViewModel)
                    .environment(transactionViewModel)
                    .modelContext(modelContext)
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

    @State private var bannerPageIndex: Int? = 0

    private var availableToSaveBanner: some View {
        VStack(spacing: 8) {
            GeometryReader { geo in
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 12) {
                        // Card 1: Available to Save
                        NavigationLink {
                            let (start, end) = TimePeriod.month.dateRange
                            InsightsDetailView(type: .totalSpend, startDate: start, endDate: end)
                        } label: {
                            ZStack {
                                RoundedRectangle(cornerRadius: 32, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [Color(hex: "06B6D4"), Color(hex: "10B981")],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                
                                Circle()
                                    .fill(.white.opacity(0.15))
                                    .frame(width: 200, height: 200)
                                    .blur(radius: 50)
                                    .offset(x: 100, y: -50)
                                
                                VStack(spacing: 12) {
                                    Text("Available to Save")
                                        .font(.system(size: 10, weight: .black))
                                        .foregroundStyle(.white.opacity(0.7))
                                        .textCase(.uppercase)
                                        .tracking(1)
                                    
                                    let money = goalsViewModel.availableToSave
                                    Text(money.formatted(with: appStateViewModel.userCurrency))
                                        .font(.system(size: 40, weight: .black, design: .rounded))
                                        .foregroundStyle(.white)
                                    
                                    if goalsViewModel.isOverspent {
                                        Text("Capped at zero due to overspending")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundStyle(.white.opacity(0.9))
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 4)
                                            .background(Color.red.opacity(0.3), in: Capsule())
                                    } else {
                                        Text("Ready for your next milestone")
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundStyle(.white.opacity(0.7))
                                    }
                                }
                            }
                            .frame(width: geo.size.width)
                            .frame(height: 180)
                            .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .id(0)
                        
                        // Card 2: Funded to Goals
                        NavigationLink {
                            let (start, end) = TimePeriod.month.dateRange
                            InsightsDetailView(type: .fundedToGoals, startDate: start, endDate: end)
                        } label: {
                            ZStack {
                                RoundedRectangle(cornerRadius: 32, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [Color(hex: "6366F1"), Color(hex: "A855F7")],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                
                                VStack(spacing: 12) {
                                    Text("Total Goal Funding")
                                        .font(.system(size: 10, weight: .black))
                                        .foregroundStyle(.white.opacity(0.7))
                                        .textCase(.uppercase)
                                        .tracking(1)
                                    
                                    let funded = goalsViewModel.totalGoalFunding
                                    Text(funded.formatted(with: appStateViewModel.userCurrency))
                                        .font(.system(size: 40, weight: .black, design: .rounded))
                                        .foregroundStyle(.white)
                                    
                                    HStack(spacing: 4) {
                                        Text("View Allocation Detail")
                                        Image(systemName: "arrow.right")
                                    }
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(.white.opacity(0.2), in: Capsule())
                                }
                            }
                            .frame(width: geo.size.width)
                            .frame(height: 180)
                            .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .id(1)
                    }
                    .scrollTargetLayout()
                }
                .scrollPosition(id: $bannerPageIndex)
                .scrollTargetBehavior(.viewAligned)
                .contentMargins(.horizontal, 0, for: .scrollContent)
            }
            .frame(height: 180)
            
            // Page Indicator
            HStack(spacing: 6) {
                ForEach(0..<2) { index in
                    Circle()
                        .fill(bannerPageIndex == index ? AnyShapeStyle(Color.primary) : AnyShapeStyle(Color.secondary.opacity(0.3)))
                        .frame(width: bannerPageIndex == index ? 8 : 6, height: bannerPageIndex == index ? 8 : 6)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: bannerPageIndex)
                }
            }
            .padding(.top, 4)
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(FintechDesign.brandGradient.opacity(0.1))
                    .frame(width: 100, height: 100)
                Image(systemName: "target")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundStyle(FintechDesign.brandGradient)
            }
            
            Text("No Goals Yet")
                .font(.title3.bold())
                .foregroundStyle(FintechDesign.primaryText)
            
            Button {
                goalsViewModel.presentAdd()
            } label: {
                Text("Create a Goal")
                    .font(.headline)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 14)
                    .background(FintechDesign.brandGradient, in: Capsule())
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
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
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(title)
                    .font(.system(size: 13, weight: .black))
                    .textCase(.uppercase)
                    .tracking(1)
                    .foregroundStyle(Color.secondary)
                Spacer()
                Text("\(goals.count)")
                    .font(.caption2.bold())
                    .foregroundStyle(Color.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.1), in: Capsule())
            }
            .padding(.horizontal, 8)
            
            ForEach(goals) { goal in
                NavigationLink(value: goal) {
                    GoalCardRow(goal: goal, viewModel: viewModel, appState: appState) {
                        onFund?(goal)
                    }
                    .padding(24)
                    .opacity(opacity)
                    .background(
                        FintechDesign.CardBackground()
                            .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 32)
                                    .stroke(FintechDesign.adaptiveColor("E0E0E0", "FFFFFF").opacity(0.1), lineWidth: 1)
                            )
                    )
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
        let goalStatus = viewModel.status(for: goal)
        let goalColor = goalStatus.color
        
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top) {
                ZStack {
                    Circle()
                        .fill(goalColor.opacity(0.1))
                        .frame(width: 48, height: 48)
                    Image(systemName: goal.type.systemImage)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(goalColor)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(goal.title)
                        .font(.headline)
                        .foregroundStyle(FintechDesign.primaryText)
                    Text(goal.type.label)
                        .font(.caption)
                        .foregroundStyle(Color.secondary)
                }
                
                Spacer()
                
                Text(goalStatus.label)
                    .font(.system(size: 10, weight: .black))
                    .textCase(.uppercase)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(goalColor.opacity(0.1), in: Capsule())
                    .foregroundStyle(goalColor)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .lastTextBaseline) {
                    Text(viewModel.progressLabel(for: goal, symbol: appState.userCurrency))
                        .font(.system(.subheadline, design: .rounded).bold())
                        .foregroundStyle(FintechDesign.primaryText)
                    
                    Spacer()
                    
                    if let onFund = onFund, goal.type == .savings, goalStatus != .achieved {
                        Button {
                            onFund()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "plus.circle.fill")
                                Text("Fund")
                            }
                            .font(.system(size: 13, weight: .bold))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(goalColor, in: Capsule())
                            .foregroundStyle(.white)
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                // Custom Gradient Progress Bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.secondary.opacity(0.1))
                        
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [goalColor, goalColor.opacity(0.6)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * CGFloat(viewModel.progressFraction(for: goal)))
                    }
                }
                .frame(height: 8)
            }
            
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                    Text("\(goal.daysRemaining) days left")
                }
                .font(.caption2.bold())
                .foregroundStyle(goal.daysRemaining < 7 ? Color.red : Color.secondary)
                
                Spacer()
                
                let percent = Int(viewModel.progressFraction(for: goal) * 100)
                Text("\(percent)% achieved")
                    .font(.system(size: 10, weight: .black))
                    .foregroundStyle(Color.secondary)
            }
        }
    }
}
