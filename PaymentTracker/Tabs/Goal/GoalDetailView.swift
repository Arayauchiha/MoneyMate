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
            let ids = Set(goal.blockedCategoryIDs)
            return allTransactions.filter { 
                $0.type == .expense && 
                $0.date >= goal.startDate && 
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
        ScrollView {
            VStack(spacing: 24) {
                headerSection
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 32, style: .continuous)
                            .fill(Color(uiColor: .secondarySystemGroupedBackground))
                            .shadow(color: Color.black.opacity(0.04), radius: 15, x: 0, y: 10)
                    )
                
                if !chartData.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Progress Trend")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        
                        Chart {
                            ForEach(chartData) { point in
                                // Daily Funding Bars
                                BarMark(
                                    x: .value("Date", point.date),
                                    y: .value("Funded", point.incremental)
                                )
                                .foregroundStyle(goalsViewModel.status(for: goal).color.opacity(0.2))
                                
                                // Accumulative Line
                                LineMark(
                                    x: .value("Date", point.date),
                                    y: .value("Total", point.amount)
                                )
                                .foregroundStyle(goalsViewModel.status(for: goal).color.gradient)
                                .interpolationMethod(.stepStart)
                                .lineStyle(StrokeStyle(lineWidth: 3))
                                
                                AreaMark(
                                    x: .value("Date", point.date),
                                    y: .value("Total", point.amount)
                                )
                                .foregroundStyle(goalsViewModel.status(for: goal).color.gradient.opacity(0.1))
                                .interpolationMethod(.stepStart)
                            }
                            
                            if goal.type != .noSpend && !goal.targetAmount.isZero {
                                RuleMark(y: .value("Target", goal.targetAmount.amount))
                                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
                                    .foregroundStyle(.gray)
                                    .annotation(position: .top, alignment: .leading) {
                                        Text("Target: \(goal.targetAmount.formatted)")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundStyle(.secondary)
                                            .padding(4)
                                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 4))
                                            .offset(y: -4)
                                    }
                            }
                        }
                        .frame(height: 240)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .fill(Color(uiColor: .secondarySystemGroupedBackground))
                                .shadow(color: Color.black.opacity(0.02), radius: 10, x: 0, y: 5)
                        )
                        
                        HStack {
                            Label("Daily Funding", systemImage: "square.fill")
                                .foregroundStyle(goalsViewModel.status(for: goal).color.opacity(0.3))
                            Spacer()
                            Label("Current Total", systemImage: "line.diagonal")
                                .foregroundStyle(goalsViewModel.status(for: goal).color)
                        }
                        .font(.caption2)
                        .padding(.horizontal)
                    }
                }

                VStack(alignment: .leading, spacing: 16) {
                    Text(goal.type == .savings ? "Funding History" : "Affecting Transactions")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        
                    if associatedTransactions.isEmpty {
                        emptyState
                    } else {
                        VStack(spacing: 0) {
                            ForEach(Array(associatedTransactions.enumerated()), id: \.element.id) { index, txn in
                                TransactionRow(transaction: txn)
                                    .padding(.vertical, 12)
                                    .padding(.horizontal, 16)
                                
                                if index < associatedTransactions.count - 1 {
                                    Divider().padding(.leading, 64)
                                }
                            }
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .fill(Color(uiColor: .secondarySystemGroupedBackground))
                        )
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Goal Tracking")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(uiColor: .systemGroupedBackground))
    }

    private var headerSection: some View {
        VStack(spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text(goal.title)
                        .font(.title2)
                        .fontWeight(.black)
                    Text(goal.type.label)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                }
                Spacer()
                
                let status = goalsViewModel.status(for: goal)
                Label(status.label, systemImage: status.systemImage)
                    .font(.caption)
                    .fontWeight(.bold)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(status.color.opacity(0.15), in: Capsule())
                    .foregroundStyle(status.color)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(goalsViewModel.progressLabel(for: goal))
                        .font(.headline)
                    Spacer()
                    Text("\(Int(goalsViewModel.progressFraction(for: goal) * 100))%")
                        .font(.subheadline).bold()
                }
                
                ProgressView(value: goalsViewModel.progressFraction(for: goal))
                    .tint(goalsViewModel.status(for: goal).color)
                    .scaleEffect(x: 1, y: 1.5, anchor: .center)
            }
            
            HStack {
                DetailStat(title: "Deadline", value: goal.deadline.formatted(.dateTime.day().month().year()))
                Spacer()
                DetailStat(title: "Time Left", value: "\(goal.daysRemaining) days")
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "list.dash")
                .font(.largeTitle)
                .foregroundStyle(.tertiary)
            Text("No activity found for this goal.")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(.quaternary, style: StrokeStyle(lineWidth: 1, dash: [4]))
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
