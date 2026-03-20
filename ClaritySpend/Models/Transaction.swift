import Foundation
import CoreData

// MARK: - Transaction Type
enum TransactionType: String, CaseIterable, Codable {
    case expense = "expense"
    case income = "income"
    case transfer = "transfer"

    var displayName: String {
        switch self {
        case .expense: return "Expense"
        case .income: return "Income"
        case .transfer: return "Transfer"
        }
    }
}

// MARK: - Income Type (for freelancer mode)
enum IncomeType: String, CaseIterable, Codable {
    case salary = "salary"          // Regular salaried
    case freelance = "freelance"    // Freelance/contract payment
    case invoice = "invoice"        // Invoice payment received
    case passive = "passive"        // Rental, dividends, etc.
    case other = "other"

    var requiresTaxSetAside: Bool {
        switch self {
        case .freelance, .invoice: return true
        default: return false
        }
    }
}

// MARK: - Category Model
struct ExpenseCategory: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var icon: String       // SF Symbol name
    var colorHex: String
    var parentCategoryId: UUID?
    var isCustom: Bool
    var monthlyBudget: Double?
    var keywords: [String] // For auto-categorization

    init(id: UUID = UUID(), name: String, icon: String, colorHex: String,
         parentCategoryId: UUID? = nil, isCustom: Bool = false,
         monthlyBudget: Double? = nil, keywords: [String] = []) {
        self.id = id
        self.name = name
        self.icon = icon
        self.colorHex = colorHex
        self.parentCategoryId = parentCategoryId
        self.isCustom = isCustom
        self.monthlyBudget = monthlyBudget
        self.keywords = keywords
    }
}

// MARK: - Transaction Model
struct Transaction: Identifiable, Codable {
    let id: UUID
    var amount: Double
    var currency: String
    var amountInBaseCurrency: Double // Always stored in user's preferred currency
    var exchangeRate: Double

    var title: String
    var note: String
    var date: Date
    var type: TransactionType
    var categoryId: UUID?
    var categoryName: String   // Denormalized for display
    var categoryIcon: String

    var accountId: UUID?
    var accountName: String

    var incomeType: IncomeType?
    var taxSetAsideAmount: Double? // Calculated for freelance income

    var tags: [String]
    var receiptImageData: Data?
    var isRecurring: Bool
    var recurringInterval: RecurringInterval?
    var merchantName: String?
    var location: String?

    // Behavioral tracking
    var isImpulse: Bool        // User flagged as impulse purchase
    var moodAtPurchase: Mood?

    init(
        id: UUID = UUID(),
        amount: Double,
        currency: String = "USD",
        amountInBaseCurrency: Double? = nil,
        exchangeRate: Double = 1.0,
        title: String,
        note: String = "",
        date: Date = Date(),
        type: TransactionType = .expense,
        categoryId: UUID? = nil,
        categoryName: String = "Uncategorized",
        categoryIcon: String = "questionmark.circle",
        accountId: UUID? = nil,
        accountName: String = "Cash",
        incomeType: IncomeType? = nil,
        taxSetAsideAmount: Double? = nil,
        tags: [String] = [],
        receiptImageData: Data? = nil,
        isRecurring: Bool = false,
        recurringInterval: RecurringInterval? = nil,
        merchantName: String? = nil,
        location: String? = nil,
        isImpulse: Bool = false,
        moodAtPurchase: Mood? = nil
    ) {
        self.id = id
        self.amount = amount
        self.currency = currency
        self.amountInBaseCurrency = amountInBaseCurrency ?? amount
        self.exchangeRate = exchangeRate
        self.title = title
        self.note = note
        self.date = date
        self.type = type
        self.categoryId = categoryId
        self.categoryName = categoryName
        self.categoryIcon = categoryIcon
        self.accountId = accountId
        self.accountName = accountName
        self.incomeType = incomeType
        self.taxSetAsideAmount = taxSetAsideAmount
        self.tags = tags
        self.receiptImageData = receiptImageData
        self.isRecurring = isRecurring
        self.recurringInterval = recurringInterval
        self.merchantName = merchantName
        self.location = location
        self.isImpulse = isImpulse
        self.moodAtPurchase = moodAtPurchase
    }
}

enum RecurringInterval: String, Codable, CaseIterable {
    case daily = "daily"
    case weekly = "weekly"
    case biweekly = "biweekly"
    case monthly = "monthly"
    case quarterly = "quarterly"
    case yearly = "yearly"

    var displayName: String {
        switch self {
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        case .biweekly: return "Every 2 Weeks"
        case .monthly: return "Monthly"
        case .quarterly: return "Quarterly"
        case .yearly: return "Yearly"
        }
    }
}

enum Mood: String, Codable, CaseIterable {
    case happy = "happy"
    case stressed = "stressed"
    case bored = "bored"
    case celebrating = "celebrating"
    case sad = "sad"
    case neutral = "neutral"

    var emoji: String {
        switch self {
        case .happy: return "😊"
        case .stressed: return "😰"
        case .bored: return "😑"
        case .celebrating: return "🎉"
        case .sad: return "😢"
        case .neutral: return "😐"
        }
    }
}

// MARK: - Default Categories
extension ExpenseCategory {
    static let defaults: [ExpenseCategory] = [
        ExpenseCategory(id: UUID(), name: "Food & Dining", icon: "fork.knife", colorHex: "#FF6B6B",
                       keywords: ["restaurant", "cafe", "coffee", "lunch", "dinner", "breakfast", "food", "pizza", "burger", "sushi", "doordash", "ubereats", "grubhub"]),
        ExpenseCategory(id: UUID(), name: "Groceries", icon: "cart.fill", colorHex: "#4ECDC4",
                       keywords: ["grocery", "supermarket", "whole foods", "trader joe", "safeway", "kroger", "walmart", "costco"]),
        ExpenseCategory(id: UUID(), name: "Transportation", icon: "car.fill", colorHex: "#45B7D1",
                       keywords: ["uber", "lyft", "gas", "fuel", "parking", "toll", "transit", "bus", "metro", "train"]),
        ExpenseCategory(id: UUID(), name: "Shopping", icon: "bag.fill", colorHex: "#96CEB4",
                       keywords: ["amazon", "target", "clothing", "shoes", "accessories", "online shopping"]),
        ExpenseCategory(id: UUID(), name: "Entertainment", icon: "tv.fill", colorHex: "#FFEAA7",
                       keywords: ["netflix", "spotify", "hulu", "disney", "movie", "concert", "game", "streaming"]),
        ExpenseCategory(id: UUID(), name: "Health & Fitness", icon: "heart.fill", colorHex: "#DDA0DD",
                       keywords: ["gym", "pharmacy", "doctor", "dentist", "hospital", "medicine", "fitness", "yoga"]),
        ExpenseCategory(id: UUID(), name: "Utilities", icon: "bolt.fill", colorHex: "#74B9FF",
                       keywords: ["electric", "water", "gas", "internet", "phone", "utility", "at&t", "verizon", "comcast"]),
        ExpenseCategory(id: UUID(), name: "Rent & Housing", icon: "house.fill", colorHex: "#A29BFE",
                       keywords: ["rent", "mortgage", "hoa", "insurance", "home"]),
        ExpenseCategory(id: UUID(), name: "Travel", icon: "airplane", colorHex: "#FD79A8",
                       keywords: ["hotel", "airbnb", "flight", "airline", "travel", "vacation"]),
        ExpenseCategory(id: UUID(), name: "Education", icon: "book.fill", colorHex: "#00B894",
                       keywords: ["tuition", "school", "course", "udemy", "coursera", "books", "textbook"]),
        ExpenseCategory(id: UUID(), name: "Personal Care", icon: "sparkles", colorHex: "#FDCB6E",
                       keywords: ["salon", "haircut", "spa", "beauty", "cosmetics", "skincare"]),
        ExpenseCategory(id: UUID(), name: "Investments", icon: "chart.line.uptrend.xyaxis", colorHex: "#00CEC9",
                       keywords: ["robinhood", "fidelity", "vanguard", "schwab", "stock", "etf", "crypto", "investment"]),
        ExpenseCategory(id: UUID(), name: "Subscriptions", icon: "repeat", colorHex: "#6C5CE7",
                       keywords: ["subscription", "membership", "annual", "monthly plan"]),
        ExpenseCategory(id: UUID(), name: "Business", icon: "briefcase.fill", colorHex: "#E17055",
                       keywords: ["office", "software", "saas", "business", "professional", "consulting"]),
        ExpenseCategory(id: UUID(), name: "Income", icon: "dollarsign.circle.fill", colorHex: "#00B894",
                       keywords: ["salary", "payroll", "paycheck", "direct deposit", "freelance payment"]),
    ]
}
