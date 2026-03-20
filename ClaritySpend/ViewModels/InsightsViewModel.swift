import Foundation
import SwiftUI

// MARK: - Behavioral Insight Model
struct BehavioralInsight: Identifiable {
    let id = UUID()
    var type: InsightType
    var title: String
    var message: String
    var actionLabel: String?
    var severity: Severity
    var icon: String
    var colorHex: String

    enum InsightType {
        case overspending, impulse, recurring, savingsOpportunity,
             incomeVariance, taxReminder, positiveFeedback, prediction,
             categorySpike, streakReward
    }

    enum Severity {
        case info, warning, critical, positive
        var color: Color {
            switch self {
            case .info: return .blue
            case .warning: return .orange
            case .critical: return .red
            case .positive: return .green
            }
        }
    }
}

// MARK: - Spending Prediction
struct SpendingPrediction {
    var predictedMonthlyTotal: Double
    var currentMonthActual: Double
    var daysElapsed: Int
    var daysInMonth: Int

    var projectedSpend: Double {
        guard daysElapsed > 0 else { return 0 }
        let dailyRate = currentMonthActual / Double(daysElapsed)
        return dailyRate * Double(daysInMonth)
    }

    var isOnTrack: Bool { projectedSpend <= predictedMonthlyTotal }

    var variancePercentage: Double {
        guard predictedMonthlyTotal > 0 else { return 0 }
        return (projectedSpend - predictedMonthlyTotal) / predictedMonthlyTotal
    }
}

class InsightsViewModel: ObservableObject {
    private let store: PersistenceController

    init(store: PersistenceController = .shared) {
        self.store = store
    }

    // MARK: - Generate Behavioral Insights
    var insights: [BehavioralInsight] {
        var result: [BehavioralInsight] = []

        // 1. Impulse spending warning
        let impulseTotal = thisMonthExpenses.filter { $0.isImpulse }
            .reduce(0) { $0 + $1.amountInBaseCurrency }
        if impulseTotal > 50 {
            result.append(BehavioralInsight(
                type: .impulse,
                title: "Impulse Spending Alert",
                message: "You've spent \(formatCurrency(impulseTotal)) on impulse purchases this month. That's money that could be saved.",
                actionLabel: "Review impulse purchases",
                severity: impulseTotal > 200 ? .critical : .warning,
                icon: "exclamationmark.triangle.fill",
                colorHex: "#FD79A8"
            ))
        }

        // 2. Category overspend
        if let envelope = overspentEnvelopes.first {
            let overage = envelope.spent - envelope.allocatedAmount
            result.append(BehavioralInsight(
                type: .overspending,
                title: "\(envelope.categoryName) Over Budget",
                message: "You've exceeded your \(envelope.categoryName) budget by \(formatCurrency(overage)).",
                actionLabel: "Adjust budget",
                severity: .critical,
                icon: "chart.bar.fill",
                colorHex: "#E17055"
            ))
        }

        // 3. Recurring subscription audit
        let recurringTotal = thisMonthExpenses.filter { $0.isRecurring }
            .reduce(0) { $0 + $1.amountInBaseCurrency }
        if recurringTotal > 100 {
            let count = thisMonthExpenses.filter { $0.isRecurring }.count
            result.append(BehavioralInsight(
                type: .recurring,
                title: "Subscription Check",
                message: "You have \(count) recurring charges totaling \(formatCurrency(recurringTotal)) this month. Still using all of them?",
                actionLabel: "Review subscriptions",
                severity: .info,
                icon: "repeat.circle.fill",
                colorHex: "#6C5CE7"
            ))
        }

        // 4. Month-over-month spike
        if let change = monthOverMonthChange, change > 0.2 {
            result.append(BehavioralInsight(
                type: .categorySpike,
                title: "Spending Up \(Int(change * 100))%",
                message: "Your spending this month is tracking \(Int(change * 100))% higher than last month.",
                actionLabel: "See breakdown",
                severity: change > 0.5 ? .critical : .warning,
                icon: "arrow.up.right.circle.fill",
                colorHex: "#E17055"
            ))
        }

        // 5. Positive: savings streak
        let savingsRate = savingsRateThisMonth
        if savingsRate > 0.2 {
            result.append(BehavioralInsight(
                type: .positiveFeedback,
                title: "Great Savings Rate! 🎉",
                message: "You're saving \(Int(savingsRate * 100))% of your income this month. Keep it up!",
                actionLabel: nil,
                severity: .positive,
                icon: "star.fill",
                colorHex: "#00B894"
            ))
        }

        // 6. Tax set-aside reminder (freelancer mode)
        if let budget = store.budget, budget.isFreelancerMode {
            let freelanceIncome = store.transactions
                .filter { $0.incomeType == .freelance || $0.incomeType == .invoice }
                .filter { Calendar.current.isDate($0.date, equalTo: Date(), toGranularity: .month) }
                .reduce(0) { $0 + $1.amountInBaseCurrency }

            if freelanceIncome > 0 {
                let recommended = freelanceIncome * budget.taxRate
                if budget.taxSetAsideBalance < recommended * 0.8 {
                    result.append(BehavioralInsight(
                        type: .taxReminder,
                        title: "Tax Set-Aside Needed",
                        message: "Based on \(formatCurrency(freelanceIncome)) freelance income, set aside \(formatCurrency(recommended)) for taxes.",
                        actionLabel: "Add to tax fund",
                        severity: .warning,
                        icon: "doc.text.fill",
                        colorHex: "#FDCB6E"
                    ))
                }
            }
        }

        // 7. Spending prediction
        if let prediction = spendingPrediction, !prediction.isOnTrack {
            result.append(BehavioralInsight(
                type: .prediction,
                title: "On Track to Overspend",
                message: "At your current pace, you'll spend \(formatCurrency(prediction.projectedSpend)) this month — \(formatCurrency(prediction.projectedSpend - prediction.predictedMonthlyTotal)) over budget.",
                actionLabel: "See projection",
                severity: .warning,
                icon: "calendar.badge.exclamationmark",
                colorHex: "#FDCB6E"
            ))
        }

        return result
    }

    // MARK: - Spending Prediction
    var spendingPrediction: SpendingPrediction? {
        guard let budget = store.budget else { return nil }
        let cal = Calendar.current
        let now = Date()
        let interval = cal.dateInterval(of: .month, for: now)!
        let daysInMonth = cal.range(of: .day, in: .month, for: now)!.count
        let daysElapsed = cal.dateComponents([.day], from: interval.start, to: now).day ?? 1

        let actual = thisMonthExpenses.reduce(0) { $0 + $1.amountInBaseCurrency }

        return SpendingPrediction(
            predictedMonthlyTotal: budget.totalAmount,
            currentMonthActual: actual,
            daysElapsed: max(daysElapsed, 1),
            daysInMonth: daysInMonth
        )
    }

    // MARK: - Mood Spending Correlation
    var moodSpendingData: [(mood: Mood, averageSpend: Double, count: Int)] {
        let expenses = store.transactions.filter { $0.type == .expense && $0.moodAtPurchase != nil }
        let grouped = Dictionary(grouping: expenses, by: { $0.moodAtPurchase! })
        return grouped.map { mood, txns in
            let avg = txns.reduce(0) { $0 + $1.amountInBaseCurrency } / Double(txns.count)
            return (mood: mood, averageSpend: avg, count: txns.count)
        }.sorted { $0.averageSpend > $1.averageSpend }
    }

    // MARK: - Weekly Spending Pattern
    var weekdaySpending: [(weekday: String, average: Double)] {
        let cal = Calendar.current
        let expenses = store.transactions.filter { $0.type == .expense }
        let grouped = Dictionary(grouping: expenses) { txn -> Int in
            cal.component(.weekday, from: txn.date)
        }
        let dayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        return (1...7).map { weekday in
            let txns = grouped[weekday] ?? []
            let average = txns.isEmpty ? 0 : txns.reduce(0) { $0 + $1.amountInBaseCurrency } / Double(txns.count)
            return (weekday: dayNames[weekday - 1], average: average)
        }
    }

    // MARK: - Savings Rate
    var savingsRateThisMonth: Double {
        let income = store.transactions
            .filter { $0.type == .income && $0.date.isThisMonth }
            .reduce(0) { $0 + $1.amountInBaseCurrency }
        let expenses = thisMonthExpenses.reduce(0) { $0 + $1.amountInBaseCurrency }
        guard income > 0 else { return 0 }
        return max(0, (income - expenses) / income)
    }

    // MARK: - Net Worth Trend
    var netWorthTrend: [NetWorthSnapshot] {
        Array(store.netWorthHistory.suffix(30))
    }

    var currentNetWorth: Double {
        let assets = store.accounts.filter { $0.type.isAsset }.reduce(0) { $0 + $1.balance }
        let liabilities = store.accounts.filter { !$0.type.isAsset }.reduce(0) { $0 + abs($1.balance) }
        return assets - liabilities
    }

    // MARK: - Freelancer Income Variance
    var incomeVariance: (average: Double, min: Double, max: Double, lastThree: [Double]) {
        let last3Months = (0..<3).compactMap { offset -> Double? in
            let cal = Calendar.current
            let date = cal.date(byAdding: .month, value: -offset, to: Date())!
            let income = store.transactions
                .filter { $0.type == .income && cal.isDate($0.date, equalTo: date, toGranularity: .month) }
                .reduce(0) { $0 + $1.amountInBaseCurrency }
            return income > 0 ? income : nil
        }
        guard !last3Months.isEmpty else { return (0, 0, 0, []) }
        let avg = last3Months.reduce(0, +) / Double(last3Months.count)
        return (average: avg, min: last3Months.min() ?? 0, max: last3Months.max() ?? 0, lastThree: last3Months)
    }

    // MARK: - Private Helpers
    private var thisMonthExpenses: [Transaction] {
        store.transactions.filter { $0.type == .expense && $0.date.isThisMonth }
    }

    private var overspentEnvelopes: [BudgetEnvelope] {
        store.budget?.envelopes.filter { $0.isOverBudget } ?? []
    }

    private var monthOverMonthChange: Double? {
        let cal = Calendar.current
        let now = Date()
        let thisInterval = cal.dateInterval(of: .month, for: now)!
        let lastDate = cal.date(byAdding: .month, value: -1, to: now)!
        let lastInterval = cal.dateInterval(of: .month, for: lastDate)!

        let thisTotal = store.transactions
            .filter { $0.type == .expense && thisInterval.contains($0.date) }
            .reduce(0) { $0 + $1.amountInBaseCurrency }
        let lastTotal = store.transactions
            .filter { $0.type == .expense && lastInterval.contains($0.date) }
            .reduce(0) { $0 + $1.amountInBaseCurrency }

        guard lastTotal > 0 else { return nil }
        return (thisTotal - lastTotal) / lastTotal
    }

    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(amount)"
    }
}
