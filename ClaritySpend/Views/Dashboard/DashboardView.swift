import SwiftUI
import Charts

struct DashboardView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var store = PersistenceController.shared
    @StateObject private var insightsVM = InsightsViewModel()
    @State private var showingNetWorthDetail = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    // MARK: - Header Hero Card
                    heroCard

                    // MARK: - Quick Stats Row
                    quickStatsRow

                    // MARK: - Behavioral Insights
                    if !insightsVM.insights.isEmpty {
                        insightsSection
                    }

                    // MARK: - Budget Progress
                    if let budget = store.budget {
                        budgetSection(budget)
                    }

                    // MARK: - Spending Chart (last 7 days)
                    spendingChartSection

                    // MARK: - Recent Transactions
                    recentTransactionsSection

                    Spacer(minLength: 100)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Good \(timeOfDay),")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("Clarity")
                            .font(.headline)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        appState.showingAddTransaction = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(.indigo)
                    }
                }
            }
        }
    }

    // MARK: - Hero Card
    var heroCard: some View {
        VStack(spacing: 4) {
            Text("Net Worth")
                .font(.caption)
                .foregroundColor(.white.opacity(0.8))

            Text(formattedNetWorth)
                .font(.system(size: 38, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            if let prediction = insightsVM.spendingPrediction {
                HStack(spacing: 4) {
                    Image(systemName: prediction.isOnTrack ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    Text(prediction.isOnTrack
                         ? "On track this month"
                         : "Projected \(formatAmount(prediction.projectedSpend - prediction.predictedMonthlyTotal)) over")
                        .font(.caption)
                }
                .foregroundColor(.white.opacity(0.9))
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .background(
            LinearGradient(
                colors: [Color(hex: "#6C5CE7"), Color(hex: "#a29bfe")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(20)
        .onTapGesture { showingNetWorthDetail = true }
    }

    // MARK: - Quick Stats
    var quickStatsRow: some View {
        HStack(spacing: 12) {
            StatCard(
                title: "This Month",
                value: formatAmount(thisMonthExpenses),
                subtitle: monthChangeText,
                icon: "arrow.down.circle.fill",
                color: .red
            )
            StatCard(
                title: "Income",
                value: formatAmount(thisMonthIncome),
                subtitle: "this month",
                icon: "arrow.up.circle.fill",
                color: .green
            )
            StatCard(
                title: "Savings",
                value: "\(Int(savingsRate * 100))%",
                subtitle: "rate",
                icon: "percent",
                color: .indigo
            )
        }
    }

    // MARK: - Insights Section
    var insightsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Insights")
                .font(.headline)

            ForEach(insightsVM.insights.prefix(3)) { insight in
                InsightCard(insight: insight)
            }
        }
    }

    // MARK: - Budget Section
    func budgetSection(_ budget: Budget) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Budget")
                    .font(.headline)
                Spacer()
                Text("\(Int(budget.spentPercentage * 100))% used")
                    .font(.caption)
                    .foregroundColor(budget.spentPercentage > 0.9 ? .red : .secondary)
            }

            VStack(spacing: 8) {
                HStack {
                    Text("Spent: \(formatAmount(budget.spent))")
                        .font(.subheadline)
                    Spacer()
                    Text("of \(formatAmount(budget.totalAmount))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                BudgetProgressBar(value: budget.spentPercentage)

                // Top envelopes
                ForEach(budget.envelopes.sorted(by: { $0.spentPercentage > $1.spentPercentage }).prefix(3)) { envelope in
                    HStack(spacing: 10) {
                        CategoryIconView(icon: envelope.categoryIcon, colorHex: envelope.categoryColorHex, size: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(envelope.categoryName)
                                .font(.caption)
                                .fontWeight(.medium)
                            BudgetProgressBar(value: envelope.spentPercentage, isEssential: envelope.isEssential)
                        }
                        Spacer()
                        Text(formatAmount(envelope.spent))
                            .font(.caption)
                            .foregroundColor(envelope.isOverBudget ? .red : .secondary)
                    }
                }
            }
        }
        .cardStyle()
    }

    // MARK: - Spending Chart
    var spendingChartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Last 7 Days")
                .font(.headline)

            let dailyData = last7DaysData
            if dailyData.isEmpty {
                Text("No spending data yet. Add your first transaction!")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                if #available(iOS 16.0, *) {
                    Chart(dailyData, id: \.label) { item in
                        BarMark(
                            x: .value("Day", item.label),
                            y: .value("Amount", item.amount)
                        )
                        .foregroundStyle(Color.indigo.gradient)
                        .cornerRadius(6)
                    }
                    .frame(height: 140)
                    .chartYAxis(.hidden)
                } else {
                    SimpleBarChart(data: dailyData)
                        .frame(height: 140)
                }
            }
        }
        .cardStyle()
    }

    // MARK: - Recent Transactions
    var recentTransactionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Recent")
                    .font(.headline)
                Spacer()
                Button("See All") {
                    appState.selectedTab = .transactions
                }
                .font(.subheadline)
                .foregroundColor(.indigo)
            }

            if store.transactions.isEmpty {
                emptyTransactionsPlaceholder
            } else {
                ForEach(store.transactions.prefix(5)) { txn in
                    TransactionRow(transaction: txn, currency: appState.preferredCurrency)
                    if txn.id != store.transactions.prefix(5).last?.id {
                        Divider()
                    }
                }
            }
        }
        .cardStyle()
    }

    var emptyTransactionsPlaceholder: some View {
        VStack(spacing: 10) {
            Image(systemName: "plus.circle.dashed")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            Text("No transactions yet")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Button("Add First Transaction") {
                appState.showingAddTransaction = true
            }
            .buttonStyle(.borderedProminent)
            .tint(.indigo)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    // MARK: - Computed Properties
    var thisMonthExpenses: Double {
        PersistenceController.shared.transactions
            .filter { $0.type == .expense && $0.date.isThisMonth }
            .reduce(0) { $0 + $1.amountInBaseCurrency }
    }

    var thisMonthIncome: Double {
        PersistenceController.shared.transactions
            .filter { $0.type == .income && $0.date.isThisMonth }
            .reduce(0) { $0 + $1.amountInBaseCurrency }
    }

    var savingsRate: Double {
        guard thisMonthIncome > 0 else { return 0 }
        return max(0, (thisMonthIncome - thisMonthExpenses) / thisMonthIncome)
    }

    var formattedNetWorth: String {
        formatAmount(insightsVM.currentNetWorth)
    }

    var timeOfDay: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<12: return "morning"
        case 12..<17: return "afternoon"
        default: return "evening"
        }
    }

    var monthChangeText: String {
        guard let change = insightsVM.spendingPrediction else { return "this month" }
        return "budget \(Int(change.spentPercentage * 100))% used"
    }

    var last7DaysData: [(label: String, amount: Double)] {
        let cal = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return (0..<7).reversed().map { offset -> (label: String, amount: Double) in
            let date = cal.date(byAdding: .day, value: -offset, to: Date())!
            let amount = PersistenceController.shared.transactions
                .filter { $0.type == .expense && cal.isDate($0.date, inSameDayAs: date) }
                .reduce(0) { $0 + $1.amountInBaseCurrency }
            return (label: formatter.string(from: date), amount: amount)
        }
    }

    func formatAmount(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = appState.preferredCurrency
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(amount)"
    }
}

// MARK: - Stat Card
struct StatCard: View {
    var title: String
    var value: String
    var subtitle: String
    var icon: String
    var color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(color)
                Text(title)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
            Text(subtitle)
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(padding: 12)
    }
}

// MARK: - Insight Card
struct InsightCard: View {
    var insight: BehavioralInsight

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(insight.severity.color.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: insight.icon)
                    .font(.system(size: 16))
                    .foregroundColor(insight.severity.color)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(insight.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(insight.message)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .background(insight.severity.color.opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(insight.severity.color.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Transaction Row
struct TransactionRow: View {
    var transaction: Transaction
    var currency: String

    var body: some View {
        HStack(spacing: 12) {
            CategoryIconView(icon: transaction.categoryIcon, colorHex: categoryColor, size: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Text(transaction.categoryName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    if transaction.isImpulse {
                        Text("• impulse")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    if transaction.isRecurring {
                        Image(systemName: "repeat")
                            .font(.caption2)
                            .foregroundColor(.blue)
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(transaction.type == .income ? "+" : "-")\(formatAmount(transaction.amountInBaseCurrency))")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(transaction.type == .income ? .green : .primary)
                Text(transaction.date.friendlyDisplay)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    var categoryColor: String {
        ExpenseCategory.defaults.first { $0.name == transaction.categoryName }?.colorHex ?? "#6C5CE7"
    }

    func formatAmount(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(amount)"
    }
}

// MARK: - Simple Bar Chart (iOS 15 fallback)
struct SimpleBarChart: View {
    var data: [(label: String, amount: Double)]

    var maxValue: Double { data.map(\.amount).max() ?? 1 }

    var body: some View {
        HStack(alignment: .bottom, spacing: 6) {
            ForEach(data, id: \.label) { item in
                VStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.indigo)
                        .frame(height: item.amount == 0 ? 4 : CGFloat(item.amount / maxValue) * 110)
                    Text(item.label)
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

extension BudgetPrediction {
    var spentPercentage: Double {
        guard predictedMonthlyTotal > 0 else { return 0 }
        return currentMonthActual / predictedMonthlyTotal
    }
}

// Alias for SpendingPrediction to avoid confusion
typealias BudgetPrediction = SpendingPrediction
