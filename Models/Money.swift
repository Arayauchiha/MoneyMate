import Foundation

struct Money: Equatable, Comparable, Hashable, Sendable {
    let amount: Decimal

    nonisolated static let zero = Money(0)

    nonisolated init(_ amount: Decimal) {
        // Round to 2 decimal places by default for currency
        let rounded = NSDecimalNumber(decimal: amount).rounding(accordingToBehavior: nil).decimalValue
        self.amount = rounded
    }

    nonisolated static func < (lhs: Money, rhs: Money) -> Bool {
        lhs.amount < rhs.amount
    }

    nonisolated static func + (lhs: Money, rhs: Money) -> Money {
        Money(lhs.amount + rhs.amount)
    }

    nonisolated static func - (lhs: Money, rhs: Money) -> Money {
        Money(lhs.amount - rhs.amount)
    }

    nonisolated var isZero: Bool {
        amount == .zero
    }

    nonisolated var absolute: Money {
        Money(abs(amount))
    }

    /// Default formatting using local storage for thread-safety and reactivity
    nonisolated var formatted: String {
        let symbol = UserDefaults.standard.string(forKey: "user_currency") ?? "₹"
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = symbol
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        return formatter.string(from: amount as NSDecimalNumber) ?? "0"
    }

    /// Explicitly formatted with a specific symbol for reactive UI
    nonisolated func formatted(with symbol: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = symbol
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        return formatter.string(from: amount as NSDecimalNumber) ?? "0"
    }

    nonisolated var formattedPlain: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        return formatter.string(from: amount as NSDecimalNumber) ?? "0"
    }

    nonisolated var formattedWithSign: String {
        let sign = amount > .zero ? "+" : (amount < .zero ? "-" : "")
        let absVal = absolute.formatted
        return "\(sign)\(absVal)"
    }

    nonisolated var formattedCompact: String {
        let sign = amount < 0 ? "-" : ""
        let absAmount = abs(amount)
        let symbol = UserDefaults.standard.string(forKey: "user_currency") ?? "₹"

        if absAmount >= 1_000_000 {
            return "\(sign)\(symbol)\((absAmount / 1_000_000).formatted(.number.precision(.fractionLength(0 ... 1))))M"
        } else if absAmount >= 1000 {
            return "\(sign)\(symbol)\((absAmount / 1000).formatted(.number.precision(.fractionLength(0 ... 1))))k"
        } else {
            return formatted
        }
    }
}

extension Decimal {
    var formattedPlain: String {
        Money(self).formattedPlain
    }
}
