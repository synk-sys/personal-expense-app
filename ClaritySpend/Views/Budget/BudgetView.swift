import SwiftUI
import Charts

struct BudgetView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var store = PersistenceController.shared
    @State private var showingEditBudget = false
    @State private var showingFreelancerSetup = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    if let budget = store.budget {
                        // MARK: - Overview Card
                        budgetOverviewCard(budget)

                        // MARK: - Freelancer Tax Set-Aside (if enabled)
                        if appState.isFreelancerMode {
                            freelancerCard(budget)
                        }

                        // MARK: - Envelope Breakdown
                        envelopesSection(budget)

                        // MARK: - Spending Donut Chart
                        if #available(iOS 16.0, *) {
                            spendingChartSection(budget)
                        }

                        // MARK: - Net Worth Quick View
                        netWorthSection

                    } else {
                        emptyBudgetState
                    }

                    Spacer(minLength: 100)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Budget")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingEditBudget = true
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                            .foregroundColor(.indigo)
                    }
                }
            }
            .sheet(isPresented: $showingEditBudget) {
                EditBudgetView()
            }
        }
    }

    // MARK: - Overview Card
    func budgetOverviewCard(_ budget: Budget) -> some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(budget.name)
                        .font(.headline)
                    Text(periodLabel(budget))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(formatAmount(budget.remaining))
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(budget.remaining >= 0 ? .green : .red)
                    Text("remaining")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Main progress bar
            VStack(alignment: .leading, spacing: 6) {
                BudgetProgressBar(value: budget.spentPercentage)
                HStack {
                    Text("Spent: \(formatAmount(budget.spent))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("Budget: \(formatAmount(budget.totalAmount))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Status badges
            HStack(spacing: 8) {
                let overspent = budget.envelopes.filter { $0.isOverBudget }.count
                if overspent > 0 {
                    Label("\(overspent) over budget", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                }
                let nearLimit = budget.envelopes.filter { $0.spentPercentage >= 0.8 && !$0.isOverBudget }.count
                if nearLimit > 0 {
                    Label("\(nearLimit) near limit", systemImage: "exclamationmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(8)
                }
                Spacer()
            }
        }
        .cardStyle()
    }

    // MARK: - Freelancer Card
    func freelancerCard(_ budget: Budget) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "briefcase.fill")
                    .foregroundColor(.orange)
                Text("Freelancer Mode")
                    .font(.headline)
                Spacer()
                Text("Tax \(Int(appState.taxRate * 100))%")
                    .font(.caption)
                    .foregroundColor(.orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
            }

            // Tax set-aside balance
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Tax Set-Aside")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(formatAmount(budget.taxSetAsideBalance))
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.orange)
                }

                Divider().frame(height: 40)

                // Income variance
                let variance = incomeVarianceLast3Months
                VStack(alignment: .leading, spacing: 4) {
                    Text("Avg Monthly Income")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(formatAmount(variance.average))
                        .font(.title3)
                        .fontWeight(.bold)
                }

                Spacer()
            }

            // Survival vs Comfort budget display
            if let minimum = budget.minimumIncome, let comfort = budget.comfortIncome {
                VStack(spacing: 8) {
                    HStack {
                        Text("Survival Budget")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(formatAmount(minimum))
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    HStack {
                        Text("Comfort Budget")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(formatAmount(comfort))
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                }
                .padding(.top, 4)
            }

            // Next quarterly tax payment reminder
            if let nextQuarter = nextQuarterlyEstimatedPayment {
                HStack {
                    Image(systemName: "calendar.badge.exclamationmark")
                        .foregroundColor(.orange)
                    Text("Quarterly tax payment due: \(nextQuarter)")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
        }
        .cardStyle()
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.orange.opacity(0.3), lineWidth: 1))
    }

    // MARK: - Envelopes
    func envelopesSection(_ budget: Budget) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Envelopes")
                    .font(.headline)
                Spacer()
                Text("\(budget.envelopes.count) categories")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            ForEach(budget.envelopes.sorted(by: { $0.isEssential && !$1.isEssential })) { envelope in
                EnvelopeRow(envelope: envelope, currency: appState.preferredCurrency)
            }
        }
        .cardStyle()
    }

    // MARK: - Spending Chart
    @available(iOS 16.0, *)
    func spendingChartSection(_ budget: Budget) -> some View {
        let data = budget.envelopes.filter { $0.spent > 0 }
        guard !data.isEmpty else { return AnyView(EmptyView()) }

        return AnyView(
            VStack(alignment: .leading, spacing: 12) {
                Text("Spending Breakdown")
                    .font(.headline)

                Chart(data) { envelope in
                    SectorMark(
                        angle: .value("Spent", envelope.spent),
                        innerRadius: .ratio(0.55),
                        angularInset: 2
                    )
                    .cornerRadius(4)
                    .foregroundStyle(Color(hex: envelope.categoryColorHex))
                }
                .frame(height: 200)

                // Legend
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(data) { envelope in
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color(hex: envelope.categoryColorHex))
                                .frame(width: 8, height: 8)
                            Text(envelope.categoryName)
                                .font(.caption2)
                                .lineLimit(1)
                            Spacer()
                            Text(formatAmount(envelope.spent))
                                .font(.caption2)
                                .fontWeight(.medium)
                        }
                    }
                }
            }
            .cardStyle()
        )
    }

    // MARK: - Net Worth Quick View
    var netWorthSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Accounts & Net Worth")
                .font(.headline)

            ForEach(store.accounts) { account in
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color(hex: account.colorHex).opacity(0.2))
                            .frame(width: 36, height: 36)
                        Image(systemName: account.type.icon)
                            .font(.system(size: 14))
                            .foregroundColor(Color(hex: account.colorHex))
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(account.name)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text(account.type.displayName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(formatAmount(account.balance))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(account.balance >= 0 ? .primary : .red)

                        if let util = account.utilizationRate {
                            Text("\(Int(util * 100))% utilized")
                                .font(.caption2)
                                .foregroundColor(util > 0.7 ? .red : .secondary)
                        }
                    }
                }

                if account.id != store.accounts.last?.id {
                    Divider()
                }
            }

            Divider()

            let netWorth = store.accounts.filter { $0.isIncludedInNetWorth }
                .reduce(0) { $0 + ($1.type.isAsset ? $1.balance : -abs($1.balance)) }
            HStack {
                Text("Net Worth")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                Text(formatAmount(netWorth))
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(netWorth >= 0 ? .green : .red)
            }
        }
        .cardStyle()
    }

    // MARK: - Empty State
    var emptyBudgetState: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.pie")
                .font(.system(size: 50))
                .foregroundColor(.secondary)
            Text("No Budget Set")
                .font(.headline)
            Text("Set a monthly budget to track your spending by category.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button("Create Budget") {
                showingEditBudget = true
            }
            .buttonStyle(.borderedProminent)
            .tint(.indigo)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 60)
    }

    // MARK: - Helpers
    func periodLabel(_ budget: Budget) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: budget.startDate)
    }

    func formatAmount(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = appState.preferredCurrency
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(amount)"
    }

    var incomeVarianceLast3Months: (average: Double, min: Double, max: Double) {
        let cal = Calendar.current
        let now = Date()
        let totals = (0..<3).map { offset -> Double in
            let date = cal.date(byAdding: .month, value: -offset, to: now)!
            return store.transactions
                .filter { $0.type == .income && cal.isDate($0.date, equalTo: date, toGranularity: .month) }
                .reduce(0) { $0 + $1.amountInBaseCurrency }
        }.filter { $0 > 0 }
        guard !totals.isEmpty else { return (0, 0, 0) }
        return (average: totals.reduce(0, +) / Double(totals.count),
                min: totals.min() ?? 0,
                max: totals.max() ?? 0)
    }

    var nextQuarterlyEstimatedPayment: String? {
        let cal = Calendar.current
        let now = Date()
        let month = cal.component(.month, from: now)
        let year = cal.component(.year, from: now)

        // IRS quarterly deadlines: Apr 15, Jun 17, Sep 16, Jan 15
        let deadlines: [(m: Int, d: Int, label: String)] = [
            (4, 15, "Apr 15"), (6, 17, "Jun 17"), (9, 16, "Sep 16"), (1, 15, "Jan 15")
        ]

        for deadline in deadlines {
            var components = DateComponents(year: deadline.m == 1 ? year + 1 : year,
                                            month: deadline.m, day: deadline.d)
            if let date = cal.date(from: components), date > now {
                let days = cal.dateComponents([.day], from: now, to: date).day ?? 0
                return "\(deadline.label) (\(days) days)"
            }
        }
        return nil
    }
}

// MARK: - Envelope Row
struct EnvelopeRow: View {
    var envelope: BudgetEnvelope
    var currency: String

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 10) {
                CategoryIconView(icon: envelope.categoryIcon, colorHex: envelope.categoryColorHex, size: 32)

                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(envelope.categoryName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        if envelope.isEssential {
                            Text("essential")
                                .font(.caption2)
                                .foregroundColor(.blue)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(4)
                        }
                    }

                    HStack {
                        Text(formatAmount(envelope.spent))
                            .font(.caption)
                            .foregroundColor(envelope.isOverBudget ? .red : .secondary)
                        Text("/ \(formatAmount(envelope.allocatedAmount))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(envelope.isOverBudget
                         ? "+\(formatAmount(envelope.spent - envelope.allocatedAmount))"
                         : formatAmount(envelope.remaining))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(envelope.isOverBudget ? .red : .green)
                    Text(envelope.isOverBudget ? "over" : "left")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            BudgetProgressBar(value: envelope.spentPercentage, isEssential: envelope.isEssential)
        }
        .padding(.vertical, 4)
    }

    func formatAmount(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(amount)"
    }
}

// MARK: - Edit Budget Sheet
struct EditBudgetView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var store = PersistenceController.shared
    @Environment(\.dismiss) var dismiss

    @State private var totalAmount: String = ""
    @State private var envelopes: [BudgetEnvelope] = []
    @State private var isFreelancerMode: Bool = false
    @State private var taxRate: String = "25"
    @State private var minimumIncome: String = ""
    @State private var comfortIncome: String = ""

    var body: some View {
        NavigationView {
            Form {
                Section("Total Monthly Budget") {
                    HStack {
                        Text("$")
                        TextField("3000", text: $totalAmount)
                            .keyboardType(.decimalPad)
                    }
                }

                Section("Freelancer Mode") {
                    Toggle("Variable Income Mode", isOn: $isFreelancerMode)
                    if isFreelancerMode {
                        HStack {
                            Text("Tax Rate (%)")
                            Spacer()
                            TextField("25", text: $taxRate)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 60)
                        }
                        HStack {
                            Text("Survival Budget")
                            Spacer()
                            TextField("0", text: $minimumIncome)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 100)
                        }
                        HStack {
                            Text("Comfort Budget")
                            Spacer()
                            TextField("0", text: $comfortIncome)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 100)
                        }
                    }
                }

                Section("Category Envelopes") {
                    ForEach($envelopes) { $envelope in
                        HStack {
                            CategoryIconView(icon: envelope.categoryIcon, colorHex: envelope.categoryColorHex, size: 28)
                            Text(envelope.categoryName)
                            Spacer()
                            TextField("0", value: $envelope.allocatedAmount, format: .number)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 80)
                        }
                    }

                    Button {
                        addEnvelope()
                    } label: {
                        Label("Add Category", systemImage: "plus")
                    }
                }
            }
            .navigationTitle("Edit Budget")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") { saveBudget() }
                        .fontWeight(.semibold)
                }
            }
            .onAppear { loadExisting() }
        }
    }

    func loadExisting() {
        if let budget = store.budget {
            totalAmount = String(budget.totalAmount)
            envelopes = budget.envelopes
            isFreelancerMode = budget.isFreelancerMode
            taxRate = String(Int(budget.taxRate * 100))
            minimumIncome = budget.minimumIncome.map { String($0) } ?? ""
            comfortIncome = budget.comfortIncome.map { String($0) } ?? ""
        } else {
            totalAmount = "3000"
            envelopes = [
                BudgetEnvelope(categoryName: "Food & Dining", categoryIcon: "fork.knife", categoryColorHex: "#FF6B6B", allocatedAmount: 500),
                BudgetEnvelope(categoryName: "Groceries", categoryIcon: "cart.fill", categoryColorHex: "#4ECDC4", allocatedAmount: 300, isEssential: true),
                BudgetEnvelope(categoryName: "Transportation", categoryIcon: "car.fill", categoryColorHex: "#45B7D1", allocatedAmount: 200, isEssential: true),
                BudgetEnvelope(categoryName: "Entertainment", categoryIcon: "tv.fill", categoryColorHex: "#FFEAA7", allocatedAmount: 150),
            ]
        }
    }

    func addEnvelope() {
        envelopes.append(BudgetEnvelope(categoryName: "New Category",
                                        categoryIcon: "questionmark.circle",
                                        categoryColorHex: "#74B9FF",
                                        allocatedAmount: 100))
    }

    func saveBudget() {
        let total = Double(totalAmount) ?? 3000
        let rate = (Double(taxRate) ?? 25) / 100
        let min = Double(minimumIncome)
        let comfort = Double(comfortIncome)

        var budget = Budget(
            totalAmount: total,
            envelopes: envelopes,
            isFreelancerMode: isFreelancerMode,
            minimumIncome: min,
            comfortIncome: comfort,
            taxRate: rate,
            taxSetAsideBalance: store.budget?.taxSetAsideBalance ?? 0
        )
        store.saveBudget(budget)

        appState.isFreelancerMode = isFreelancerMode
        appState.taxRate = rate
        UserDefaults.standard.set(isFreelancerMode, forKey: "isFreelancerMode")
        UserDefaults.standard.set(rate, forKey: "taxRate")

        dismiss()
    }
}
