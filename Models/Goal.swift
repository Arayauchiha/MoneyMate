import Foundation
import SwiftData

@Model
final class Goal: Identifiable {
    var id: UUID
    var title: String
    var type: GoalType
    var deadline: Date
    var isActive: Bool
    var currentStreak: Int
    var longestStreak: Int
    var lastEvaluatedDate: Date?

    private var targetAmountRaw: String

    private var blockedCategoryIDsRaw: String

    init(
        id: UUID = .init(),
        title: String,
        type: GoalType,
        targetAmount: Money = .zero,
        deadline: Date,
        blockedCategories: [Category] = [],
        isActive: Bool = true
    ) {
        self.id = id
        self.title = title
        self.type = type
        targetAmountRaw = "\(targetAmount.amount)"
        self.deadline = deadline
        self.isActive = isActive
        currentStreak = 0
        longestStreak = 0
        lastEvaluatedDate = nil
        blockedCategoryIDsRaw = blockedCategories
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
        guard !targetAmount.isZero else { return 0 }
        let fraction = (currentAmount.amount / targetAmount.amount) as NSDecimalNumber
        return min(max(fraction.doubleValue, 0), 1)
    }

    @MainActor
    func progressLabel(currentAmount: Money) -> String {
        switch type {
        case .savings, .budgetCap:
            "\(currentAmount.formatted) of \(targetAmount.formatted)"
        case .noSpend:
            "\(currentStreak)-day streak"
        }
    }

    func status(currentAmount: Money) -> GoalStatus {
        if isExpired {
            return progress(currentAmount: currentAmount) >= 1 ? .achieved : .failed
        }
        let p = progress(currentAmount: currentAmount)
        if p >= 1 { return .achieved }

        let totalDays = max(1, Calendar.current.dateComponents(
            [.day], from: .now.addingTimeInterval(-86400 * Double(daysRemaining)), to: deadline
        ).day ?? 1)
        let elapsed = Double(totalDays - daysRemaining) / Double(totalDays)
        return (p < elapsed * 0.8) ? .atRisk : .onTrack
    }
}
