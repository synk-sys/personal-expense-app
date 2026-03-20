import SwiftUI
import Charts

struct InsightsView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = InsightsViewModel()
    @State private var selectedPeriod: AnalysisPeriod = .month

    enum AnalysisPeriod: String, CaseIterable {
        case week = "Week"
        case month = "Month"
        case quarter = "Quarter"
        case year = "Year"
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    // Period Selector
                    periodSelector

                    // MARK: - All Insights (Behavioral Coach)
                    if !viewModel.insights.isEmpty {
                        coachSection
                    }

                    // MARK: - Spending by Category
                    categoryBreakdownSection

                    // MARK: - Spending Prediction
                    if let prediction = viewModel.spendingPrediction {
                        predictionSection(prediction)
                    }

                    // MARK: - Mood → Spending Correlation
                    if !viewModel.moodSpendingData.isEmpty {
                        moodSection
                    }

                    // MARK: - Day of Week Pattern
                    weekdayPatternSection

                    // MARK: - Net Worth Trend
                    netWorthSection

                    // MARK: - Freelancer Income Variance
                    if appState.isFreelancerMode {
                        incomeVarianceSection
                    }

                    Spacer(minLength: 100)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Insights")
        }
    }

    // MARK: - Period Selector
    var periodSelector: some View {
        HStack(spacing: 0) {
            ForEach(AnalysisPeriod.allCases, id: \.self) { period in
                Button {
                    withAnimation { selectedPeriod = period }
                } label: {
                    Text(period.rawValue)
                        .font(.subheadline)
                        .fontWeight(selectedPeriod == period ? .semibold : .regular)
                        .foregroundColor(selectedPeriod == period ? .white : .primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(selectedPeriod == period ? Color.indigo : Color.clear)
                        .cornerRadius(10)
                }
            }
        }
        .padding(4)
        .background(Color(.systemGray6))
        .cornerRadius(14)
    }

    // MARK: - Coach Section
    var coachSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .foregroundColor(.indigo)
                Text("Spending Coach")
                    .font(.headline)
            }

            ForEach(viewModel.insights) { insight in
                InsightCard(insight: insight)
            }
        }
    }

    // MARK: - Category Breakdown
    var categoryBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Where Money Goes")
                .font(.headline)

            let data = spendingByCategory
            if data.isEmpty {
                Text("No spending data for this period.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                ForEach(data.prefix(8), id: \.category) { item in
                    VStack(spacing: 4) {
                        HStack {
                            Image(systemName: item.icon)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(width: 20)
                            Text(item.category)
                                .font(.subheadline)
                            Spacer()
                            Text(formatAmount(item.amount))
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text("\(Int(item.percentage * 100))%")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(width: 35, alignment: .trailing)
                        }
                        GeometryReader { geo in
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.indigo.opacity(0.15))
                                .frame(height: 6)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.indigo)
                                        .frame(width: geo.size.width * CGFloat(item.percentage), height: 6),
                                    alignment: .leading
                                )
                        }
                        .frame(height: 6)
                    }
                }
            }
        }
        .cardStyle()
    }

    // MARK: - Prediction Section
    func predictionSection(_ prediction: SpendingPrediction) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundColor(.indigo)
                Text("Monthly Projection")
                    .font(.headline)
            }

            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Actual So Far")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(formatAmount(prediction.currentMonthActual))
                        .font(.title3)
                        .fontWeight(.bold)
                }

                Image(systemName: "arrow.right")
                    .foregroundColor(.secondary)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Projected Total")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(formatAmount(prediction.projectedSpend))
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(prediction.isOnTrack ? .green : .red)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Budget")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(formatAmount(prediction.predictedMonthlyTotal))
                        .font(.title3)
                        .fontWeight(.semibold)
                }
            }

            // Projection bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(.systemGray5))
                        .frame(height: 12)
                    // Budget line
                    RoundedRectangle(cornerRadius: 6)
                        .fill(prediction.isOnTrack ? Color.green : Color.red)
                        .frame(width: min(geo.size.width * CGFloat(prediction.projectedSpend / max(prediction.predictedMonthlyTotal, prediction.projectedSpend)), geo.size.width), height: 12)
                    // Actual
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.indigo)
                        .frame(width: min(geo.size.width * CGFloat(prediction.currentMonthActual / max(prediction.predictedMonthlyTotal, prediction.projectedSpend)), geo.size.width), height: 12)
                }
            }
            .frame(height: 12)

            HStack {
                Circle().fill(Color.indigo).frame(width: 8, height: 8)
                Text("Spent").font(.caption2).foregroundColor(.secondary)
                Circle().fill(prediction.isOnTrack ? Color.green : Color.red).frame(width: 8, height: 8)
                Text("Projected").font(.caption2).foregroundColor(.secondary)
                Spacer()
                Text("Day \(prediction.daysElapsed) of \(prediction.daysInMonth)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .cardStyle()
    }

    // MARK: - Mood → Spending
    var moodSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Mood → Spending")
                    .font(.headline)
                Spacer()
                Text("avg. per purchase")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            VStack(spacing: 10) {
                ForEach(viewModel.moodSpendingData, id: \.mood) { item in
                    HStack {
                        Text(item.mood.emoji)
                            .font(.title3)
                        Text(item.mood.rawValue.capitalized)
                            .font(.subheadline)
                        Spacer()
                        Text("avg \(formatAmount(item.averageSpend))")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text("(\(item.count)x)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Text("Track your mood when spending to identify emotional spending patterns.")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 4)
        }
        .cardStyle()
    }

    // MARK: - Weekday Pattern
    var weekdayPatternSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Spending by Day of Week")
                .font(.headline)

            let data = viewModel.weekdaySpending
            let maxVal = data.map(\.average).max() ?? 1

            HStack(alignment: .bottom, spacing: 8) {
                ForEach(data, id: \.weekday) { item in
                    VStack(spacing: 4) {
                        if item.average > 0 {
                            Text(formatCompact(item.average))
                                .font(.system(size: 8))
                                .foregroundColor(.secondary)
                        }
                        RoundedRectangle(cornerRadius: 4)
                            .fill(item.weekday == currentWeekday ? Color.indigo : Color.indigo.opacity(0.3))
                            .frame(height: item.average == 0 ? 4 : CGFloat(item.average / maxVal) * 80)
                        Text(item.weekday)
                            .font(.system(size: 9))
                            .foregroundColor(item.weekday == currentWeekday ? .indigo : .secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 100)

            if let highestDay = data.max(by: { $0.average < $1.average }), highestDay.average > 0 {
                Text("You spend the most on \(highestDay.weekday)s on average.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .cardStyle()
    }

    // MARK: - Net Worth Trend
    var netWorthSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Net Worth")
                    .font(.headline)
                Spacer()
                Text(formatAmount(viewModel.currentNetWorth))
                    .font(.headline)
                    .foregroundColor(viewModel.currentNetWorth >= 0 ? .green : .red)
            }

            if viewModel.netWorthTrend.count > 1 {
                if #available(iOS 16.0, *) {
                    Chart(viewModel.netWorthTrend) { snapshot in
                        LineMark(
                            x: .value("Date", snapshot.date),
                            y: .value("Net Worth", snapshot.netWorth)
                        )
                        .foregroundStyle(Color.indigo)
                        .interpolationMethod(.catmullRom)

                        AreaMark(
                            x: .value("Date", snapshot.date),
                            y: .value("Net Worth", snapshot.netWorth)
                        )
                        .foregroundStyle(Color.indigo.opacity(0.1))
                        .interpolationMethod(.catmullRom)
                    }
                    .frame(height: 120)
                    .chartYAxis(.hidden)
                    .chartXAxis(.hidden)
                }
            } else {
                Text("Add accounts and transactions to see net worth trends over time.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 10)
            }
        }
        .cardStyle()
    }

    // MARK: - Income Variance (Freelancer)
    var incomeVarianceSection: some View {
        let variance = viewModel.incomeVariance
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "briefcase.fill")
                    .foregroundColor(.orange)
                Text("Income Variance")
                    .font(.headline)
            }

            HStack(spacing: 0) {
                VStack {
                    Text("Min")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(formatAmount(variance.min))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.red)
                }
                .frame(maxWidth: .infinity)

                VStack {
                    Text("Avg")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(formatAmount(variance.average))
                        .font(.subheadline)
                        .fontWeight(.bold)
                }
                .frame(maxWidth: .infinity)

                VStack {
                    Text("Max")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(formatAmount(variance.max))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
            .cornerRadius(10)

            Text("Budget based on your minimum income to stay safe during slow months.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .cardStyle()
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.orange.opacity(0.3), lineWidth: 1))
    }

    // MARK: - Computed
    var spendingByCategory: [(category: String, icon: String, amount: Double, percentage: Double)] {
        let store = PersistenceController.shared
        let expenses = store.transactions.filter { $0.type == .expense && $0.date.isThisMonth }
        let total = expenses.reduce(0) { $0 + $1.amountInBaseCurrency }
        guard total > 0 else { return [] }
        let grouped = Dictionary(grouping: expenses, by: \.categoryName)
        return grouped.map { name, txns in
            let amount = txns.reduce(0) { $0 + $1.amountInBaseCurrency }
            return (category: name, icon: txns.first?.categoryIcon ?? "questionmark",
                    amount: amount, percentage: amount / total)
        }.sorted { $0.amount > $1.amount }
    }

    var currentWeekday: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: Date())
    }

    func formatAmount(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = appState.preferredCurrency
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(amount)"
    }

    func formatCompact(_ amount: Double) -> String {
        if amount >= 1000 { return "$\(Int(amount / 1000))k" }
        return "$\(Int(amount))"
    }
}
