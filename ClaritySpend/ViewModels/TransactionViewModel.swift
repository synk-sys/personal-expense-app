import Foundation
import SwiftUI
import Combine

class TransactionViewModel: ObservableObject {
    @Published var searchText: String = ""
    @Published var selectedFilter: TransactionFilter = .all
    @Published var selectedDateRange: DateRange = .thisMonth
    @Published var sortOrder: SortOrder = .dateDescending

    private let store: PersistenceController

    init(store: PersistenceController = .shared) {
        self.store = store
    }

    // MARK: - Filtering
    enum TransactionFilter: String, CaseIterable {
        case all = "All"
        case expenses = "Expenses"
        case income = "Income"
        case impulse = "Impulse"
        case recurring = "Recurring"
    }

    enum DateRange: String, CaseIterable {
        case today = "Today"
        case thisWeek = "This Week"
        case thisMonth = "This Month"
        case lastMonth = "Last Month"
        case last3Months = "3 Months"
        case thisYear = "This Year"
        case all = "All Time"

        var dateInterval: DateInterval? {
            let now = Date()
            let cal = Calendar.current
            switch self {
            case .today:
                return cal.dateInterval(of: .day, for: now)
            case .thisWeek:
                return cal.dateInterval(of: .weekOfYear, for: now)
            case .thisMonth:
                return cal.dateInterval(of: .month, for: now)
            case .lastMonth:
                let lastMonth = cal.date(byAdding: .month, value: -1, to: now)!
                return cal.dateInterval(of: .month, for: lastMonth)
            case .last3Months:
                let start = cal.date(byAdding: .month, value: -3, to: now)!
                return DateInterval(start: start, end: now)
            case .thisYear:
                return cal.dateInterval(of: .year, for: now)
            case .all:
                return nil
            }
        }
    }

    enum SortOrder: String, CaseIterable {
        case dateDescending = "Newest First"
        case dateAscending = "Oldest First"
        case amountDescending = "Highest Amount"
        case amountAscending = "Lowest Amount"
    }

    var filteredTransactions: [Transaction] {
        var result = store.transactions

        // Date filter
        if let interval = selectedDateRange.dateInterval {
            result = result.filter { interval.contains($0.date) }
        }

        // Type filter
        switch selectedFilter {
        case .all: break
        case .expenses: result = result.filter { $0.type == .expense }
        case .income: result = result.filter { $0.type == .income }
        case .impulse: result = result.filter { $0.isImpulse }
        case .recurring: result = result.filter { $0.isRecurring }
        }

        // Search
        if !searchText.isEmpty {
            result = result.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.categoryName.localizedCaseInsensitiveContains(searchText) ||
                $0.note.localizedCaseInsensitiveContains(searchText) ||
                ($0.merchantName?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }

        // Sort
        switch sortOrder {
        case .dateDescending: result.sort { $0.date > $1.date }
        case .dateAscending: result.sort { $0.date < $1.date }
        case .amountDescending: result.sort { $0.amountInBaseCurrency > $1.amountInBaseCurrency }
        case .amountAscending: result.sort { $0.amountInBaseCurrency < $1.amountInBaseCurrency }
        }

        return result
    }

    // MARK: - Summary Stats
    var totalExpenses: Double {
        filteredTransactions.filter { $0.type == .expense }
            .reduce(0) { $0 + $1.amountInBaseCurrency }
    }

    var totalIncome: Double {
        filteredTransactions.filter { $0.type == .income }
            .reduce(0) { $0 + $1.amountInBaseCurrency }
    }

    var netFlow: Double { totalIncome - totalExpenses }

    var impulseTotal: Double {
        filteredTransactions.filter { $0.isImpulse }
            .reduce(0) { $0 + $1.amountInBaseCurrency }
    }

    // MARK: - Grouped by Date
    var groupedTransactions: [(String, [Transaction])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: filteredTransactions) { transaction -> String in
            if calendar.isDateInToday(transaction.date) {
                return "Today"
            } else if calendar.isDateInYesterday(transaction.date) {
                return "Yesterday"
            } else {
                let formatter = DateFormatter()
                formatter.dateFormat = "MMMM d, yyyy"
                return formatter.string(from: transaction.date)
            }
        }
        return grouped.sorted { a, b in
            // Sort groups: Today first, Yesterday second, then by date
            let order = ["Today": 0, "Yesterday": 1]
            let aOrder = order[a.key] ?? Int.max
            let bOrder = order[b.key] ?? Int.max
            if aOrder != bOrder { return aOrder < bOrder }
            // For date strings, sort by the first transaction's date
            let aDate = a.value.first?.date ?? Date.distantPast
            let bDate = b.value.first?.date ?? Date.distantPast
            return aDate > bDate
        }
    }

    // MARK: - Spending by Category
    var spendingByCategory: [(category: String, icon: String, amount: Double, percentage: Double)] {
        let expenses = filteredTransactions.filter { $0.type == .expense }
        let total = expenses.reduce(0) { $0 + $1.amountInBaseCurrency }
        guard total > 0 else { return [] }

        let grouped = Dictionary(grouping: expenses, by: \.categoryName)
        return grouped.map { name, txns in
            let amount = txns.reduce(0) { $0 + $1.amountInBaseCurrency }
            let icon = txns.first?.categoryIcon ?? "questionmark.circle"
            return (category: name, icon: icon, amount: amount, percentage: amount / total)
        }.sorted { $0.amount > $1.amount }
    }

    // MARK: - Daily Spending for Chart
    var dailySpending: [(date: Date, amount: Double)] {
        guard let interval = selectedDateRange.dateInterval else { return [] }
        let expenses = store.transactions.filter {
            $0.type == .expense && interval.contains($0.date)
        }
        let grouped = Dictionary(grouping: expenses) { Calendar.current.startOfDay(for: $0.date) }
        return grouped.map { date, txns in
            (date: date, amount: txns.reduce(0) { $0 + $1.amountInBaseCurrency })
        }.sorted { $0.date < $1.date }
    }

    // MARK: - Month-over-Month Comparison
    func monthOverMonthChange() -> Double? {
        let cal = Calendar.current
        let now = Date()
        let thisMonth = cal.dateInterval(of: .month, for: now)!
        let lastMonthDate = cal.date(byAdding: .month, value: -1, to: now)!
        let lastMonth = cal.dateInterval(of: .month, for: lastMonthDate)!

        let thisTotal = store.transactions
            .filter { $0.type == .expense && thisMonth.contains($0.date) }
            .reduce(0) { $0 + $1.amountInBaseCurrency }

        let lastTotal = store.transactions
            .filter { $0.type == .expense && lastMonth.contains($0.date) }
            .reduce(0) { $0 + $1.amountInBaseCurrency }

        guard lastTotal > 0 else { return nil }
        return (thisTotal - lastTotal) / lastTotal
    }
}
