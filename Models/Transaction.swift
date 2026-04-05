import Foundation
import SwiftData

@Model
final class Transaction: Identifiable {
    var id: UUID
    var type: TransactionType
    var date: Date
    var note: String

    private var amountRaw: String

    var category: Category?
    var linkedGoal: Goal?

    init(
        id: UUID = .init(),
        amount: Money,
        type: TransactionType,
        category: Category? = nil,
        linkedGoal: Goal? = nil,
        date: Date = .now,
        note: String = ""
    ) {
        self.id = id
        self.amountRaw = "\(amount.amount)"
        self.type = type
        self.category = category
        self.linkedGoal = linkedGoal
        self.date = date
        self.note = note
    }

    var money: Money {
        get {
            let d = Decimal(string: amountRaw) ?? .zero
            return Money(d)
        }
        set { amountRaw = "\(newValue.amount)" }
    }

    @MainActor
    var signedMoney: Money {
        Money(money.amount * type.balanceMultiplier)
    }

    @MainActor
    var formattedAmount: String {
        switch type {
        case .income: "+\(money.formatted)"
        case .expense: "-\(money.formatted)"
        case .transfer: money.formatted
        }
    }

    @MainActor
    var formattedAmountCompact: String {
        switch type {
        case .income: "+\(money.formattedCompact)"
        case .expense: "-\(money.formattedCompact)"
        case .transfer: money.formattedCompact
        }
    }
}

extension Transaction {
    @MainActor
    static func predicate(from start: Date, to end: Date) -> Predicate<Transaction> {
        return #Predicate<Transaction> { $0.date >= start && $0.date <= end }
    }

    @MainActor
    static func predicate(type: TransactionType) -> Predicate<Transaction> {
        let raw = type.rawValue
        return #Predicate<Transaction> { $0.type.rawValue == raw }
    }
}
