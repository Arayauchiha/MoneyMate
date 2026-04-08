import SwiftUI
import SwiftData
import Charts

struct GoalDetailView: View {
    let goal: Goal
    
    @Environment(GoalsViewModel.self) private var goalsViewModel
    @Environment(AppStateViewModel.self) private var appStateViewModel
    @Environment(\.modelContext) private var modelContext
    
    @Query private var allTransactions: [Transaction]
    @State private var isFundingPresented = false
    @State private var isDeleteAlertPresented = false
    @State private var isHistoryEditingMode = false
    @State private var selectedHistoryTransactions = Set<UUID>()
    @State private var isArchiveConfirmPresented = false
    @State private var isPermanentDeleteConfirmPresented = false
    @Environment(TransactionViewModel.self) private var transactionViewModel
    @Environment(\.dismiss) private var dismiss
    
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
            return allTransactions.filter { !$0.isArchived && $0.type == .transfer && $0.linkedGoal?.id == goal.id }
        case .budgetCap, .noSpend, .dailyLimit:
            let ids = Set(goal.blockedCategoryIDs)
            let startOfDay = Calendar.current.startOfDay(for: goal.startDate)
            return allTransactions.filter { 
                !$0.isArchived &&
                $0.type == .expense && 
                $0.date >= startOfDay && 
                $0.date <= goal.deadline &&
                (ids.isEmpty ? true : $0.category.map { ids.contains($0.id) } ?? false)
            }
        }
    }

    private var chartData: [FundingPoint] {
        let sorted = associatedTransactions.sorted { $0.date < $1.date }
        var currentTotal: Decimal = 0
        return sorted.map { txn in
            currentTotal += txn.money.amount
            return FundingPoint(date: txn.date, amount: currentTotal, incremental: txn.money.amount)
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(spacing: 24) {
                    headerSection
                    
                    if !chartData.isEmpty {
                        chartSection
                    }

                    VStack(alignment: .leading, spacing: 16) {
                        Text(goal.type == .savings ? "Funding History" : "Affecting Transactions")
                            .font(.system(size: 13, weight: .black))
                            .textCase(.uppercase)
                            .tracking(1)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            
                        if associatedTransactions.isEmpty {
                            emptyState
                        } else {
                            VStack(spacing: 0) {
                                ForEach(Array(associatedTransactions.enumerated()), id: \.element.id) { index, txn in
                                    HStack(spacing: 12) {
                                        if isHistoryEditingMode {
                                            Image(systemName: selectedHistoryTransactions.contains(txn.id) ? "checkmark.circle.fill" : "circle")
                                                .font(.title3)
                                                .foregroundStyle(selectedHistoryTransactions.contains(txn.id) ? .blue : .secondary)
                                                .transition(.move(edge: .leading).combined(with: .opacity))
                                                .onTapGesture {
                                                    if selectedHistoryTransactions.contains(txn.id) {
                                                        selectedHistoryTransactions.remove(txn.id)
                                                    } else {
                                                        selectedHistoryTransactions.insert(txn.id)
                                                    }
                                                }
                                                .padding(.leading, 24)
                                        }
                                        
                                        TransactionRow(transaction: txn)
                                            .padding(.vertical, 14)
                                            .padding(.horizontal, isHistoryEditingMode ? 12 : 24)
                                    }
                                    .contentShape(Rectangle())
                                    
                                    if index < associatedTransactions.count - 1 {
                                        Divider()
                                            .padding(.leading, isHistoryEditingMode ? 104 : 80)
                                            .padding(.trailing, 24)
                                    }
                                }
                            }
                            .padding(.vertical, 8)
                            .background(
                                FintechDesign.CardBackground()
                                    .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 32)
                                            .stroke(FintechDesign.adaptiveColor("E0E0E0", "FFFFFF").opacity(0.1), lineWidth: 1)
                                    )
                            )
                        }
                    }
                }
                .padding()
            }
            .background(Color(uiColor: .systemGroupedBackground))
        }
        .navigationTitle(isHistoryEditingMode ? "\(selectedHistoryTransactions.count) Selected" : "Goal Tracking")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(isHistoryEditingMode)
        .toolbar {
            if isHistoryEditingMode {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            isHistoryEditingMode = false
                            appStateViewModel.isTabBarHidden = false
                            selectedHistoryTransactions.removeAll()
                        }
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button(selectedHistoryTransactions.count == associatedTransactions.count ? "Deselect All" : "Select All") {
                        withAnimation(.snappy(duration: 0.2)) {
                            if selectedHistoryTransactions.count == associatedTransactions.count {
                                selectedHistoryTransactions.removeAll()
                            } else {
                                selectedHistoryTransactions = Set(associatedTransactions.map { $0.id })
                            }
                        }
                    }
                }
                
                ToolbarItemGroup(placement: .bottomBar) {
                    Button("Archive") {
                        isArchiveConfirmPresented = true
                    }
                    .disabled(selectedHistoryTransactions.isEmpty)
                    
                    Spacer()
                    
                    Button(role: .destructive) {
                        isPermanentDeleteConfirmPresented = true
                    } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(.red)
                    }
                    .disabled(selectedHistoryTransactions.isEmpty)
                }
            } else {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Section {
                            Button {
                                goalsViewModel.presentEdit(goal)
                            } label: {
                                Label("Edit Goal", systemImage: "pencil")
                            }
                            
                            Button {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                    isHistoryEditingMode = true
                                    appStateViewModel.isTabBarHidden = true
                                }
                            } label: {
                                Label("Select Funding", systemImage: "checkmark.circle")
                            }
                        }
                        
                        Section {
                            Button(role: .destructive) {
                                isDeleteAlertPresented = true
                            } label: {
                                Label("Delete Goal", systemImage: "trash")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.title3)
                    }
                }
            }
        }
        .sheet(isPresented: $isFundingPresented) {
            FundGoalView(goal: goal)
        }
        .alert("Delete Goal?", isPresented: $isDeleteAlertPresented) {
            Button("Delete", role: .destructive) {
                goalsViewModel.delete(goal)
                dismiss()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will permanently remove the goal and all its tracking data. This cannot be undone.")
        }
        .alert("Archive Funding?", isPresented: $isArchiveConfirmPresented) {
            Button("Archive", role: .destructive) {
                let toArchive = associatedTransactions.filter { selectedHistoryTransactions.contains($0.id) }
                transactionViewModel.archiveMultiple(toArchive)
                withAnimation {
                    selectedHistoryTransactions.removeAll()
                    isHistoryEditingMode = false
                    appStateViewModel.isTabBarHidden = false
                }
                Task { await goalsViewModel.load() }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("These transactions will be moved to the Archive and will no longer count toward this goal.")
        }
        .alert("Delete Permanently?", isPresented: $isPermanentDeleteConfirmPresented) {
            Button("Delete Forever", role: .destructive) {
                let toDelete = associatedTransactions.filter { selectedHistoryTransactions.contains($0.id) }
                transactionViewModel.deleteMultiplePermanently(toDelete)
                withAnimation {
                    selectedHistoryTransactions.removeAll()
                    isHistoryEditingMode = false
                    appStateViewModel.isTabBarHidden = false
                }
                Task { await goalsViewModel.load() }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will permanently erase these records from your history. This cannot be undone.")
        }
        .onDisappear {
            appStateViewModel.isTabBarHidden = false
        }
        .toolbar(appStateViewModel.isTabBarHidden ? .hidden : .visible, for: .tabBar)
    }
    
    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Progress Trend")
                .font(.system(size: 13, weight: .black))
                .textCase(.uppercase)
                .tracking(1)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
            
            Chart {
                ForEach(chartData) { point in
                    // Daily Funding Bars
                    BarMark(
                        x: .value("Date", point.date),
                        y: .value("Funded", point.incremental)
                    )
                    .foregroundStyle(goalsViewModel.status(for: goal).color.opacity(0.3))
                    
                    // Accumulative Line
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Total", point.amount)
                    )
                    .foregroundStyle(goalsViewModel.status(for: goal).color.gradient)
                    .interpolationMethod(.monotone)
                    .lineStyle(StrokeStyle(lineWidth: 4, lineCap: .round))
                    
                    // Points to make individual contributions visible
                    PointMark(
                        x: .value("Date", point.date),
                        y: .value("Total", point.amount)
                    )
                    .foregroundStyle(goalsViewModel.status(for: goal).color)
                    .symbol(Circle().strokeBorder(lineWidth: 2))
                    
                    AreaMark(
                        x: .value("Date", point.date),
                        y: .value("Total", point.amount)
                    )
                    .foregroundStyle(goalsViewModel.status(for: goal).color.gradient.opacity(0.15))
                    .interpolationMethod(.monotone)
                }
                
                if goal.type != .noSpend && goal.targetAmount.amount != 0 {
                    RuleMark(y: .value("Target", goal.targetAmount.amount))
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                        .foregroundStyle(.gray.opacity(0.5))
                        .annotation(position: .top, alignment: .trailing) {
                            HStack(spacing: 4) {
                                Image(systemName: "target")
                                Text("Goal: \(goal.targetAmount.formatted(with: appStateViewModel.userCurrency))")
                            }
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(uiColor: .secondarySystemGroupedBackground).opacity(0.8), in: Capsule())
                            .shadow(color: .black.opacity(0.05), radius: 2)
                            .offset(y: -8)
                        }
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { value in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.month().day())
                        .font(.system(size: 10, weight: .bold))
                }
            }
            .frame(height: 250)
            .padding(24)
            .background(
                FintechDesign.CardBackground()
                    .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 32)
                    .stroke(FintechDesign.adaptiveColor("E0E0E0", "FFFFFF").opacity(0.1), lineWidth: 1)
            )
            
            HStack(spacing: 20) {
                HStack(spacing: 6) {
                    Circle().fill(goalsViewModel.status(for: goal).color.opacity(0.3)).frame(width: 8, height: 8)
                    Text("Daily Funding").font(.caption).foregroundStyle(.secondary)
                }
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 2).fill(goalsViewModel.status(for: goal).color).frame(width: 12, height: 3)
                    Text("Cumulative Progress").font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal)
        }
    }
    
    private var headerSection: some View {
        let goalStatus = goalsViewModel.status(for: goal)
        let goalColor = goalStatus.color
        
        return VStack(spacing: 24) {
            // Master Header Info
            HStack(alignment: .top) {
                ZStack {
                    Circle()
                        .fill(goalColor.opacity(0.1))
                        .frame(width: 60, height: 60)
                    Image(systemName: goal.type.systemImage)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(goalColor)
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(goal.title)
                        .font(.title2)
                        .fontWeight(.black)
                        .foregroundStyle(FintechDesign.primaryText)
                    Text(goal.type.label)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .tracking(1)
                }
                
                Spacer()
                
                Text(goalStatus.label)
                    .font(.system(size: 10, weight: .black))
                    .textCase(.uppercase)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(goalColor.opacity(0.1), in: Capsule())
                    .foregroundStyle(goalColor)
            }
            
            // Stats Row
            HStack(spacing: 12) {
                DetailStat(title: "Deadline", value: goal.deadline.formatted(.dateTime.day().month().year()))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(Color.secondary.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
                
                DetailStat(title: "Time Left", value: "\(goal.daysRemaining) days")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(Color.secondary.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
            }
            
            // Progress Center
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .lastTextBaseline) {
                    Text(goalsViewModel.progressLabel(for: goal, symbol: appStateViewModel.userCurrency))
                        .font(.system(.title3, design: .rounded).bold())
                        .foregroundStyle(FintechDesign.primaryText)
                    
                    Spacer()
                    
                    Text("\(Int(goalsViewModel.progressFraction(for: goal) * 100))%")
                        .font(.system(.subheadline, design: .rounded).bold())
                        .foregroundStyle(goalColor)
                }
                
                // Custom Liquid Progress
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
                            .frame(width: geo.size.width * CGFloat(goalsViewModel.progressFraction(for: goal)))
                    }
                }
                .frame(height: 10)
                
                if goal.type == .savings && goalStatus != .achieved {
                    Button {
                        isFundingPresented = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "plus.circle.fill")
                            Text("Add Funds")
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(goalColor, in: RoundedRectangle(cornerRadius: 16))
                        .foregroundStyle(.white)
                        .shadow(color: goalColor.opacity(0.3), radius: 10, x: 0, y: 5)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 8)
                }
            }
        }
        .padding(24)
        .background(
            FintechDesign.CardBackground()
                .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 32)
                .stroke(FintechDesign.adaptiveColor("E0E0E0", "FFFFFF").opacity(0.1), lineWidth: 1)
        )
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "list.dash")
                .font(.largeTitle)
                .foregroundStyle(.tertiary)
            Text("No activity found for this goal.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .strokeBorder(Color.secondary.opacity(0.2), style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
        )
    }
}

struct DetailStat: View {
    let title: String
    let value: String
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption2).foregroundStyle(.secondary)
            Text(value).font(.subheadline).bold()
        }
    }
}

struct FundingPoint: Identifiable {
    let id = UUID()
    let date: Date
    let amount: Decimal
    let incremental: Decimal
}
