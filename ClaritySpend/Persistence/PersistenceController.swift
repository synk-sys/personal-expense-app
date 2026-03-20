import CoreData
import Foundation

class PersistenceController: ObservableObject {
    static let shared = PersistenceController()

    let container: NSPersistentContainer

    // In-memory data stores (JSON-backed for simplicity — no CloudKit dependency needed)
    @Published var transactions: [Transaction] = []
    @Published var categories: [ExpenseCategory] = ExpenseCategory.defaults
    @Published var accounts: [Account] = []
    @Published var budget: Budget?
    @Published var netWorthHistory: [NetWorthSnapshot] = []

    private let transactionsURL: URL
    private let categoriesURL: URL
    private let accountsURL: URL
    private let budgetURL: URL
    private let netWorthURL: URL

    init(inMemory: Bool = false) {
        // Use a simple persistent container (no CloudKit by default — privacy first)
        container = NSPersistentContainer(name: "ClaritySpend")

        let storeDirectory: URL
        if inMemory {
            storeDirectory = URL(fileURLWithPath: "/dev/null")
        } else {
            storeDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        }

        transactionsURL = storeDirectory.appendingPathComponent("transactions.json")
        categoriesURL = storeDirectory.appendingPathComponent("categories.json")
        accountsURL = storeDirectory.appendingPathComponent("accounts.json")
        budgetURL = storeDirectory.appendingPathComponent("budget.json")
        netWorthURL = storeDirectory.appendingPathComponent("networth.json")

        // We use JSON files directly instead of CoreData for full local control
        loadAll()

        // Seed defaults if first launch
        if accounts.isEmpty {
            seedDefaults()
        }
    }

    // MARK: - Load
    private func loadAll() {
        transactions = load(from: transactionsURL) ?? []
        let savedCategories: [ExpenseCategory]? = load(from: categoriesURL)
        categories = savedCategories ?? ExpenseCategory.defaults
        accounts = load(from: accountsURL) ?? []
        budget = load(from: budgetURL)
        netWorthHistory = load(from: netWorthURL) ?? []
    }

    private func load<T: Decodable>(from url: URL) -> T? {
        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    // MARK: - Save
    func saveAll() {
        save(transactions, to: transactionsURL)
        save(categories, to: categoriesURL)
        save(accounts, to: accountsURL)
        save(budget, to: budgetURL)
        save(netWorthHistory, to: netWorthURL)
    }

    private func save<T: Encodable>(_ value: T, to url: URL) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        try? data.write(to: url, options: .atomicWrite)
    }

    // MARK: - Transaction CRUD
    func addTransaction(_ transaction: Transaction) {
        transactions.insert(transaction, at: 0)
        updateAccountBalance(for: transaction, operation: .add)
        updateBudgetEnvelope(for: transaction, operation: .add)
        saveAll()
    }

    func updateTransaction(_ updated: Transaction) {
        if let idx = transactions.firstIndex(where: { $0.id == updated.id }) {
            let old = transactions[idx]
            updateAccountBalance(for: old, operation: .remove)
            updateBudgetEnvelope(for: old, operation: .remove)
            transactions[idx] = updated
            updateAccountBalance(for: updated, operation: .add)
            updateBudgetEnvelope(for: updated, operation: .add)
            saveAll()
        }
    }

    func deleteTransaction(_ transaction: Transaction) {
        transactions.removeAll { $0.id == transaction.id }
        updateAccountBalance(for: transaction, operation: .remove)
        updateBudgetEnvelope(for: transaction, operation: .remove)
        saveAll()
    }

    // MARK: - Account CRUD
    func addAccount(_ account: Account) {
        accounts.append(account)
        saveAll()
    }

    func updateAccount(_ updated: Account) {
        if let idx = accounts.firstIndex(where: { $0.id == updated.id }) {
            accounts[idx] = updated
            saveAll()
        }
    }

    func deleteAccount(_ account: Account) {
        accounts.removeAll { $0.id == account.id }
        saveAll()
    }

    // MARK: - Budget CRUD
    func saveBudget(_ newBudget: Budget) {
        budget = newBudget
        saveAll()
    }

    // MARK: - Category CRUD
    func addCategory(_ category: ExpenseCategory) {
        categories.append(category)
        saveAll()
    }

    func updateCategory(_ updated: ExpenseCategory) {
        if let idx = categories.firstIndex(where: { $0.id == updated.id }) {
            categories[idx] = updated
            saveAll()
        }
    }

    func deleteCategory(_ category: ExpenseCategory) {
        categories.removeAll { $0.id == category.id }
        saveAll()
    }

    // MARK: - Net Worth Snapshot
    func recordNetWorthSnapshot() {
        let assets = accounts.filter { $0.type.isAsset && $0.isIncludedInNetWorth }
            .reduce(0) { $0 + $1.balance }
        let liabilities = accounts.filter { !$0.type.isAsset && $0.isIncludedInNetWorth }
            .reduce(0) { $0 + abs($1.balance) }

        let snapshots = accounts.filter { $0.isIncludedInNetWorth }.map { acc in
            AccountSnapshot(id: UUID(), accountId: acc.id, accountName: acc.name,
                           balance: acc.balance, isAsset: acc.type.isAsset)
        }

        let snapshot = NetWorthSnapshot(id: UUID(), date: Date(), assets: assets,
                                        liabilities: liabilities, accounts: snapshots)
        netWorthHistory.append(snapshot)
        // Keep last 365 snapshots
        if netWorthHistory.count > 365 {
            netWorthHistory.removeFirst(netWorthHistory.count - 365)
        }
        saveAll()
    }

    // MARK: - Smart Auto-Categorization
    func suggestCategory(for title: String) -> ExpenseCategory? {
        let lowercased = title.lowercased()
        return categories.first { category in
            category.keywords.contains { keyword in
                lowercased.contains(keyword.lowercased())
            }
        }
    }

    // MARK: - Tax Set-Aside (Freelancer Mode)
    func calculateTaxSetAside(for amount: Double, rate: Double) -> Double {
        return amount * rate
    }

    func addToTaxSetAside(_ amount: Double) {
        guard var currentBudget = budget else { return }
        currentBudget.taxSetAsideBalance += amount
        budget = currentBudget
        saveAll()
    }

    // MARK: - Helpers
    private enum BalanceOperation { case add, remove }

    private func updateAccountBalance(for transaction: Transaction, operation: BalanceOperation) {
        guard let accountId = transaction.accountId,
              let idx = accounts.firstIndex(where: { $0.id == accountId }) else { return }
        let delta = transaction.amountInBaseCurrency
        switch (transaction.type, operation) {
        case (.expense, .add): accounts[idx].balance -= delta
        case (.expense, .remove): accounts[idx].balance += delta
        case (.income, .add): accounts[idx].balance += delta
        case (.income, .remove): accounts[idx].balance -= delta
        default: break
        }
    }

    private func updateBudgetEnvelope(for transaction: Transaction, operation: BalanceOperation) {
        guard transaction.type == .expense,
              let categoryId = transaction.categoryId,
              var currentBudget = budget else { return }

        if let idx = currentBudget.envelopes.firstIndex(where: { $0.categoryId == categoryId }) {
            switch operation {
            case .add: currentBudget.envelopes[idx].spent += transaction.amountInBaseCurrency
            case .remove: currentBudget.envelopes[idx].spent -= transaction.amountInBaseCurrency
            }
            budget = currentBudget
        }
    }

    private func seedDefaults() {
        accounts = [
            Account(id: UUID(), name: "Cash Wallet", type: .cash, balance: 200, colorHex: "#00B894"),
            Account(id: UUID(), name: "Checking Account", type: .checking, balance: 3500, colorHex: "#0984E3"),
            Account(id: UUID(), name: "Savings Account", type: .savings, balance: 10000, colorHex: "#6C5CE7"),
        ]

        let envelopes: [BudgetEnvelope] = [
            BudgetEnvelope(categoryName: "Food & Dining", categoryIcon: "fork.knife", categoryColorHex: "#FF6B6B", allocatedAmount: 500, isEssential: false),
            BudgetEnvelope(categoryName: "Groceries", categoryIcon: "cart.fill", categoryColorHex: "#4ECDC4", allocatedAmount: 300, isEssential: true),
            BudgetEnvelope(categoryName: "Transportation", categoryIcon: "car.fill", categoryColorHex: "#45B7D1", allocatedAmount: 200, isEssential: true),
            BudgetEnvelope(categoryName: "Entertainment", categoryIcon: "tv.fill", categoryColorHex: "#FFEAA7", allocatedAmount: 150, isEssential: false),
            BudgetEnvelope(categoryName: "Utilities", categoryIcon: "bolt.fill", categoryColorHex: "#74B9FF", allocatedAmount: 200, isEssential: true),
        ]

        budget = Budget(totalAmount: 3000, envelopes: envelopes)
        saveAll()
    }

    // MARK: - Export
    func exportAsCSV() -> String {
        var csv = "Date,Title,Amount,Currency,Category,Account,Type,Note\n"
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        for t in transactions {
            let row = [
                formatter.string(from: t.date),
                "\"\(t.title)\"",
                String(t.amount),
                t.currency,
                "\"\(t.categoryName)\"",
                "\"\(t.accountName)\"",
                t.type.rawValue,
                "\"\(t.note)\""
            ].joined(separator: ",")
            csv += row + "\n"
        }
        return csv
    }
}
