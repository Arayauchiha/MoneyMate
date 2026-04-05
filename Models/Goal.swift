import Foundation
import SwiftData

@Model
final class Goal: Identifiable {
    var id: UUID
    var title: String
    var type: GoalType
    var startDate: Date = Date()
    var deadline: Date
    var isActive: Bool
    var currentStreak: Int
    var longestStreak: Int
    var lastEvaluatedDate: Date?

    private var targetAmountRaw: String
    private var blockedCategoryIDsRaw: String
    
    @Relationship(inverse: \Transaction.linkedGoal)
    var transactions: [Transaction]?

    init(
        id: UUID = .init(),
        title: String,
        type: GoalType,
        targetAmount: Money = .zero,
        startDate: Date = .now,
        deadline: Date,
        blockedCategories: [Category] = [],
        isActive: Bool = true
    ) {
        self.id = id
        self.title = title
        self.type = type
        self.targetAmountRaw = "\(targetAmount.amount)"
        self.startDate = startDate
        self.deadline = deadline
        self.isActive = isActive
        self.currentStreak = 0
        self.longestStreak = 0
        self.lastEvaluatedDate = nil
        self.blockedCategoryIDsRaw = blockedCategories
            .map(\.id.uuidString)
            .joined(separator: ",")
    }

    var targetAmount: Money {
        get {
            let d = Decimal(string: targetAmountRaw) ?? .zero
            return Money(d)
        }
        set { targetAmountRaw = "\(newValue.amount)" }
    }

    var blockedCategoryIDs: [UUID] {
        get {
            blockedCategoryIDsRaw
                .split(separator: ",")
                .compactMap { UUID(uuidString: String($0)) }
        }
        set {
            blockedCategoryIDsRaw = newValue
                .map(\.uuidString)
                .joined(separator: ",")
        }
    }

    var daysRemaining: Int {
        max(0, Calendar.current.dateComponents([.day], from: .now, to: deadline).day ?? 0)
    }

    var isExpired: Bool {
        deadline < .now
    }

    func progress(currentAmount: Money) -> Double {
        guard !targetAmount.isZero else {
            if type == .noSpend {
                let totalDays = max(1, Calendar.current.dateComponents([.day], from: startDate, to: deadline).day ?? 1)
                return min(Double(currentStreak) / Double(totalDays), 1)
            }
            return 0 
        }
        let fraction = (currentAmount.amount / targetAmount.amount) as NSDecimalNumber
        return min(max(fraction.doubleValue, 0), 1)
    }

    @MainActor
    func progressLabel(currentAmount: Money) -> String {
        switch type {
        case .savings, .budgetCap:
            "\(currentAmount.formattedCompact) / \(targetAmount.formattedCompact)"
        case .noSpend:
            "\(currentStreak)-day streak"
        }
    }

    func status(currentAmount: Money) -> GoalStatus {
        let p = progress(currentAmount: currentAmount)
        let totalDays = max(1, Calendar.current.dateComponents([.day], from: startDate, to: deadline).day ?? 1)
        let elapsedDays = max(0, Calendar.current.dateComponents([.day], from: startDate, to: .now).day ?? 0)
        let elapsed = min(Double(elapsedDays) / Double(totalDays), 1.0)

        switch type {
        case .savings:
            if isExpired { return p >= 1 ? .achieved : .failed }
            if p >= 1 { return .achieved }
            return (p < elapsed * 0.8) ? .atRisk : .onTrack
            
        case .budgetCap:
            if p >= 1 { return .failed }
            if isExpired { return p < 1 ? .achieved : .failed }
            return (p > elapsed * 1.1) ? .atRisk : .onTrack
            
        case .noSpend:
            if isExpired { return currentStreak >= totalDays * 8/10 ? .achieved : .failed }
            if currentStreak == 0 && elapsed > 0 { return .atRisk }
            return .onTrack
        }
    }
}
