import Foundation

// MARK: - Budget Period
enum BudgetPeriod: String, Codable, CaseIterable {
    case weekly = "weekly"
    case monthly = "monthly"
    case custom = "custom"

    var displayName: String {
        switch self {
        case .weekly: return "Weekly"
        case .monthly: return "Monthly"
        case .custom: return "Custom"
        }
    }
}

// MARK: - Budget Model
struct Budget: Identifiable, Codable {
    let id: UUID
    var name: String
    var totalAmount: Double
    var period: BudgetPeriod
    var startDate: Date
    var endDate: Date?
    var envelopes: [BudgetEnvelope]
    var isFreelancerMode: Bool
    var expectedIncome: Double?      // For freelancers, expected income this period
    var minimumIncome: Double?       // Survival budget based on minimum income
    var comfortIncome: Double?       // Comfort budget based of comfort income
    var taxRate: Double
    var taxSetAsideBalance: Double   // Accumulated tax set-aside amount

    init(
        id: UUID = UUID(),
        name: String = "Monthly Budget",
        totalAmount: Double,
        period: BudgetPeriod = .monthly,
        startDate: Date = Date().startOfMonth,
        endDate: Date? = nil,
        envelopes: [BudgetEnvelope] = [],
        isFreelancerMode: Bool = false,
        expectedIncome: Double? = nil,
        minimumIncome: Double? = nil,
        comfortIncome: Double? = nil,
        taxRate: Double = 0.25,
        taxSetAsideBalance: Double = 0
    ) {
        self.id = id
        self.name = name
        self.totalAmount = totalAmount
        self.period = period
        self.startDate = startDate
        self.endDate = endDate
        self.envelopes = envelopes
        self.isFreelancerMode = isFreelancerMode
        self.expectedIncome = expectedIncome
        self.minimumIncome = minimumIncome
        self.comfortIncome = comfortIncome
        self.taxRate = taxRate
        self.taxSetAsideBalance = taxSetAsideBalance
    }

    var spent: Double {
        envelopes.reduce(0) { $0 + $1.spent }
    }

    var remaining: Double {
        totalAmount - spent
    }

    var spentPercentage: Double {
        guard totalAmount > 0 else { return 0 }
        return min(spent / totalAmount, 1.0)
    }
}

// MARK: - Budget Envelope (for envelope budgeting)
struct BudgetEnvelope: Identifiable, Codable {
    let id: UUID
    var categoryId: UUID?
    var categoryName: String
    var categoryIcon: String
    var categoryColorHex: String
    var allocatedAmount: Double
    var spent: Double
    var isEssential: Bool   // Bills you must pay vs discretionary

    init(
        id: UUID = UUID(),
        categoryId: UUID? = nil,
        categoryName: String,
        categoryIcon: String,
        categoryColorHex: String = "#4ECDC4",
        allocatedAmount: Double,
        spent: Double = 0,
        isEssential: Bool = false
    ) {
        self.id = id
        self.categoryId = categoryId
        self.categoryName = categoryName
        self.categoryIcon = categoryIcon
        self.categoryColorHex = categoryColorHex
        self.allocatedAmount = allocatedAmount
        self.spent = spent
        self.isEssential = isEssential
    }

    var remaining: Double { allocatedAmount - spent }
    var isOverBudget: Bool { spent > allocatedAmount }
    var spentPercentage: Double {
        guard allocatedAmount > 0 else { return 0 }
        return min(spent / allocatedAmount, 1.0)
    }
}

// MARK: - Net Worth Snapshot
struct NetWorthSnapshot: Identifiable, Codable {
    let id: UUID
    var date: Date
    var totalAssets: Double
    var totalLiabilities: Double
    var netWorth: Double { totalAssets - totalLiabilities }
    var accounts: [AccountSnapshot]

    init(id: UUID = UUID(), date: Date = Date(), assets: Double, liabilities: Double, accounts: [AccountSnapshot] = []) {
        self.id = id
        self.date = date
        self.totalAssets = assets
        self.totalLiabilities = liabilities
        self.accounts = accounts
    }
}

struct AccountSnapshot: Identifiable, Codable {
    let id: UUID
    var accountId: UUID
    var accountName: String
    var balance: Double
    var isAsset: Bool
}

// MARK: - Date Extensions
extension Date {
    var startOfMonth: Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: self)
        return calendar.date(from: components) ?? self
    }

    var endOfMonth: Date {
        let calendar = Calendar.current
        var components = DateComponents()
        components.month = 1
        components.day = -1
        return calendar.date(byAdding: components, to: startOfMonth) ?? self
    }

    var startOfWeek: Date {
        let calendar = Calendar.current
        return calendar.dateInterval(of: .weekOfYear, for: self)?.start ?? self
    }

    var isToday: Bool {
        Calendar.current.isDateInToday(self)
    }

    var isThisMonth: Bool {
        Calendar.current.isDate(self, equalTo: Date(), toGranularity: .month)
    }

    var friendlyDisplay: String {
        let formatter = DateFormatter()
        if isToday {
            formatter.dateFormat = "'Today,' h:mm a"
        } else if Calendar.current.isDateInYesterday(self) {
            formatter.dateFormat = "'Yesterday,' h:mm a"
        } else {
            formatter.dateFormat = "MMM d, h:mm a"
        }
        return formatter.string(from: self)
    }
}
