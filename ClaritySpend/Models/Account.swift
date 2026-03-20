import Foundation
import SwiftUI

enum AccountType: String, CaseIterable, Codable {
    case cash = "cash"
    case checking = "checking"
    case savings = "savings"
    case creditCard = "creditCard"
    case investment = "investment"
    case loan = "loan"
    case other = "other"

    var displayName: String {
        switch self {
        case .cash: return "Cash"
        case .checking: return "Checking"
        case .savings: return "Savings"
        case .creditCard: return "Credit Card"
        case .investment: return "Investment"
        case .loan: return "Loan"
        case .other: return "Other"
        }
    }

    var icon: String {
        switch self {
        case .cash: return "banknote"
        case .checking: return "building.columns"
        case .savings: return "piggybank.fill"
        case .creditCard: return "creditcard.fill"
        case .investment: return "chart.line.uptrend.xyaxis"
        case .loan: return "doc.text.fill"
        case .other: return "questionmark.circle"
        }
    }

    var isAsset: Bool {
        switch self {
        case .loan, .creditCard: return false
        default: return true
        }
    }
}

struct Account: Identifiable, Codable {
    let id: UUID
    var name: String
    var type: AccountType
    var balance: Double
    var currency: String
    var colorHex: String
    var isIncludedInNetWorth: Bool
    var note: String
    var institution: String?  // Bank/broker name (no login needed — user types it)
    var lastFourDigits: String?
    var creditLimit: Double?  // For credit cards

    init(
        id: UUID = UUID(),
        name: String,
        type: AccountType = .checking,
        balance: Double = 0,
        currency: String = "USD",
        colorHex: String = "#4ECDC4",
        isIncludedInNetWorth: Bool = true,
        note: String = "",
        institution: String? = nil,
        lastFourDigits: String? = nil,
        creditLimit: Double? = nil
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.balance = balance
        self.currency = currency
        self.colorHex = colorHex
        self.isIncludedInNetWorth = isIncludedInNetWorth
        self.note = note
        self.institution = institution
        self.lastFourDigits = lastFourDigits
        self.creditLimit = creditLimit
    }

    var availableCredit: Double? {
        guard type == .creditCard, let limit = creditLimit else { return nil }
        return limit - abs(balance)
    }

    var utilizationRate: Double? {
        guard type == .creditCard, let limit = creditLimit, limit > 0 else { return nil }
        return abs(balance) / limit
    }
}

// MARK: - Currency Model
struct Currency: Identifiable, Codable {
    let id: String   // ISO 4217 code e.g., "USD"
    var symbol: String
    var name: String
    var exchangeRate: Double   // Rate relative to USD
    var lastUpdated: Date?

    static let supported: [Currency] = [
        Currency(id: "USD", symbol: "$", name: "US Dollar", exchangeRate: 1.0),
        Currency(id: "EUR", symbol: "€", name: "Euro", exchangeRate: 0.92),
        Currency(id: "GBP", symbol: "£", name: "British Pound", exchangeRate: 0.79),
        Currency(id: "CAD", symbol: "CA$", name: "Canadian Dollar", exchangeRate: 1.36),
        Currency(id: "AUD", symbol: "A$", name: "Australian Dollar", exchangeRate: 1.53),
        Currency(id: "JPY", symbol: "¥", name: "Japanese Yen", exchangeRate: 149.5),
        Currency(id: "CHF", symbol: "Fr", name: "Swiss Franc", exchangeRate: 0.90),
        Currency(id: "INR", symbol: "₹", name: "Indian Rupee", exchangeRate: 83.5),
        Currency(id: "MXN", symbol: "MX$", name: "Mexican Peso", exchangeRate: 17.2),
        Currency(id: "BRL", symbol: "R$", name: "Brazilian Real", exchangeRate: 4.97),
        Currency(id: "SGD", symbol: "S$", name: "Singapore Dollar", exchangeRate: 1.34),
        Currency(id: "HKD", symbol: "HK$", name: "Hong Kong Dollar", exchangeRate: 7.82),
        Currency(id: "NZD", symbol: "NZ$", name: "New Zealand Dollar", exchangeRate: 1.63),
        Currency(id: "SEK", symbol: "kr", name: "Swedish Krona", exchangeRate: 10.42),
        Currency(id: "NOK", symbol: "kr", name: "Norwegian Krone", exchangeRate: 10.55),
        Currency(id: "DKK", symbol: "kr", name: "Danish Krone", exchangeRate: 6.88),
        Currency(id: "PLN", symbol: "zł", name: "Polish Zloty", exchangeRate: 3.99),
        Currency(id: "CZK", symbol: "Kč", name: "Czech Koruna", exchangeRate: 22.6),
        Currency(id: "AED", symbol: "د.إ", name: "UAE Dirham", exchangeRate: 3.67),
        Currency(id: "SAR", symbol: "ر.س", name: "Saudi Riyal", exchangeRate: 3.75),
        Currency(id: "ZAR", symbol: "R", name: "South African Rand", exchangeRate: 18.6),
        Currency(id: "KRW", symbol: "₩", name: "South Korean Won", exchangeRate: 1325),
        Currency(id: "TWD", symbol: "NT$", name: "Taiwan Dollar", exchangeRate: 31.5),
        Currency(id: "THB", symbol: "฿", name: "Thai Baht", exchangeRate: 35.4),
        Currency(id: "PHP", symbol: "₱", name: "Philippine Peso", exchangeRate: 55.8),
    ]

    static func find(_ code: String) -> Currency? {
        supported.first { $0.id == code }
    }

    func format(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = id
        formatter.currencySymbol = symbol
        return formatter.string(from: NSNumber(value: amount)) ?? "\(symbol)\(amount)"
    }
}
