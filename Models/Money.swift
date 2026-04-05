import Foundation

extension Decimal {
    nonisolated var doubleValue: Double {
        (self as NSDecimalNumber).doubleValue
    }
}

nonisolated struct Money: Codable, Hashable, Sendable {
    let amount: Decimal

    init(_ amount: Decimal) {
        self.amount = amount
    }

    init(_ amount: Int) {
        self.amount = Decimal(amount)
    }

    static let zero = Money(Decimal.zero)

    static func + (lhs: Money, rhs: Money) -> Money {
        Money(lhs.amount + rhs.amount)
    }

    static func - (lhs: Money, rhs: Money) -> Money {
        Money(lhs.amount - rhs.amount)
    }

    static func * (lhs: Money, rhs: Decimal) -> Money {
        Money(lhs.amount * rhs)
    }

    var isNegative: Bool {
        amount < .zero
    }

    var isZero: Bool {
        amount == .zero
    }

    var absolute: Money {
        Money(abs(amount))
    }
}

extension Money: Comparable {
    static func < (lhs: Money, rhs: Money) -> Bool {
        lhs.amount < rhs.amount
    }
}

extension Money {
    private static let currencyFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = Locale.current.currency?.identifier ?? "USD"
        f.locale = .current
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        return f
    }()

    private static let currencyFormatterNoSymbol: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        f.groupingSeparator = Locale.current.groupingSeparator ?? ","
        f.decimalSeparator = Locale.current.decimalSeparator ?? "."
        f.usesGroupingSeparator = true
        return f
    }()

    private static let compactFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 1
        f.minimumFractionDigits = 0
        f.usesGroupingSeparator = true
        return f
    }()

    var formatted: String {
        let nsDecimal = amount as NSDecimalNumber
        return Self.currencyFormatter.string(from: nsDecimal) ?? fallbackString
    }

    var formattedWithSign: String {
        let sign = amount >= .zero ? "+" : ""
        return "\(sign)\(formatted)"
    }

    var formattedCompact: String {
        let symbol = Self.currencyFormatter.currencySymbol ?? "$"
        let abs = Swift.abs(amount)
        let sign = amount < .zero ? "-" : ""

        switch abs {
        case _ where abs >= 1_000_000:
            let val = (abs / 1_000_000) as NSDecimalNumber
            return "\(sign)\(symbol)\(Self.compactFormatter.string(from: val) ?? "")M"
        case _ where abs >= 1000:
            let val = (abs / 1000) as NSDecimalNumber
            return "\(sign)\(symbol)\(Self.compactFormatter.string(from: val) ?? "")K"
        default:
            return "\(sign)\(formatted)"
        }
    }

    var formattedPlain: String {
        let nsDecimal = amount as NSDecimalNumber
        return Self.currencyFormatterNoSymbol.string(from: nsDecimal) ?? fallbackString
    }

    static var currencySymbol: String {
        currencyFormatter.currencySymbol ?? "$"
    }

    private var fallbackString: String {
        unsafe String(format: "%.2f", (amount as NSDecimalNumber).doubleValue)
    }
}

extension Money: ExpressibleByIntegerLiteral {
    init(integerLiteral value: Int) {
        self.init(value)
    }
}

extension Money: CustomStringConvertible {
    var description: String {
        formatted
    }
}
