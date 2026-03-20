import SwiftUI
import PhotosUI

struct AddTransactionView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var store = PersistenceController.shared
    @Environment(\.dismiss) var dismiss

    // Form state
    @State private var transactionType: TransactionType = .expense
    @State private var amountText: String = ""
    @State private var title: String = ""
    @State private var note: String = ""
    @State private var selectedDate: Date = Date()
    @State private var selectedCurrency: String = "USD"
    @State private var selectedCategoryId: UUID? = nil
    @State private var selectedAccountId: UUID? = nil

    // Auto-categorization
    @State private var suggestedCategory: ExpenseCategory? = nil

    // Advanced options
    @State private var showAdvanced: Bool = false
    @State private var isRecurring: Bool = false
    @State private var recurringInterval: RecurringInterval = .monthly
    @State private var isImpulse: Bool = false
    @State private var selectedMood: Mood? = nil
    @State private var incomeType: IncomeType = .salary
    @State private var tags: String = ""

    // Multi-currency
    @State private var showCurrencyPicker = false

    // Validation
    @State private var showValidationError = false
    @State private var validationMessage = ""

    var amount: Double { Double(amountText) ?? 0 }

    // Tax set-aside for freelancer mode
    var taxSetAside: Double {
        guard appState.isFreelancerMode,
              transactionType == .income,
              (incomeType == .freelance || incomeType == .invoice) else { return 0 }
        return amount * appState.taxRate
    }

    var selectedCategory: ExpenseCategory? {
        store.categories.first { $0.id == selectedCategoryId }
    }

    var selectedAccount: Account? {
        store.accounts.first { $0.id == selectedAccountId }
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    // MARK: - Type Selector
                    typePicker
                        .padding(.horizontal, 20)
                        .padding(.top, 20)

                    // MARK: - Amount
                    amountSection
                        .padding(.horizontal, 20)
                        .padding(.top, 16)

                    // MARK: - Core Fields
                    coreFieldsSection
                        .padding(.horizontal, 20)
                        .padding(.top, 20)

                    // MARK: - Tax Set-Aside Banner (Freelancer)
                    if taxSetAside > 0 {
                        taxSetAsideBanner
                            .padding(.horizontal, 20)
                            .padding(.top, 12)
                    }

                    // MARK: - Advanced Toggle
                    Button {
                        withAnimation { showAdvanced.toggle() }
                    } label: {
                        HStack {
                            Text("Advanced Options")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Image(systemName: showAdvanced ? "chevron.up" : "chevron.down")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 20)
                    }

                    // MARK: - Advanced Section
                    if showAdvanced {
                        advancedSection
                            .padding(.horizontal, 20)
                            .padding(.top, 12)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    Spacer(minLength: 100)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("New Transaction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.secondary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") { saveTransaction() }
                        .fontWeight(.semibold)
                        .foregroundColor(.indigo)
                }
            }
            .alert("Required Field", isPresented: $showValidationError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(validationMessage)
            }
            .onAppear {
                selectedCurrency = appState.preferredCurrency
                selectedAccountId = store.accounts.first?.id
            }
        }
    }

    // MARK: - Type Picker
    var typePicker: some View {
        HStack(spacing: 0) {
            ForEach(TransactionType.allCases, id: \.self) { type in
                Button {
                    withAnimation { transactionType = type }
                } label: {
                    Text(type.displayName)
                        .font(.subheadline)
                        .fontWeight(transactionType == type ? .semibold : .regular)
                        .foregroundColor(transactionType == type ? .white : .secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(transactionType == type ? typeColor(type) : Color.clear)
                        .cornerRadius(10)
                }
            }
        }
        .padding(4)
        .background(Color(.systemGray6))
        .cornerRadius(14)
    }

    func typeColor(_ type: TransactionType) -> Color {
        switch type {
        case .expense: return .red.opacity(0.8)
        case .income: return .green.opacity(0.8)
        case .transfer: return .blue.opacity(0.8)
        }
    }

    // MARK: - Amount Section
    var amountSection: some View {
        VStack(spacing: 8) {
            HStack {
                // Currency selector
                Button {
                    showCurrencyPicker = true
                } label: {
                    HStack(spacing: 4) {
                        Text(selectedCurrency)
                            .font(.title3)
                            .fontWeight(.semibold)
                        Image(systemName: "chevron.down")
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
                .sheet(isPresented: $showCurrencyPicker) {
                    CurrencyPickerView(selectedCurrency: $selectedCurrency)
                }

                Spacer()
            }

            TextField("0.00", text: $amountText)
                .font(.system(size: 52, weight: .bold, design: .rounded))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)

            if selectedCurrency != appState.preferredCurrency {
                let rate = Currency.find(selectedCurrency)?.exchangeRate ?? 1
                let baseRate = Currency.find(appState.preferredCurrency)?.exchangeRate ?? 1
                let converted = (amount / rate) * baseRate
                Text("≈ \(formatAmount(converted)) \(appState.preferredCurrency)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Core Fields
    var coreFieldsSection: some View {
        VStack(spacing: 0) {
            // Title with auto-categorization
            VStack(alignment: .leading, spacing: 6) {
                TextField("What was this for?", text: $title)
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .onChange(of: title) { newValue in
                        if let suggestion = store.suggestCategory(for: newValue) {
                            suggestedCategory = suggestion
                            if selectedCategoryId == nil {
                                selectedCategoryId = suggestion.id
                            }
                        }
                    }

                // Auto-categorization suggestion
                if let suggestion = suggestedCategory, selectedCategoryId == suggestion.id {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.caption)
                            .foregroundColor(.indigo)
                        Text("Auto-categorized as \(suggestion.name)")
                            .font(.caption)
                            .foregroundColor(.indigo)
                        Spacer()
                        Button("Change") {
                            suggestedCategory = nil
                            selectedCategoryId = nil
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 4)
                }
            }

            // Category Picker
            VStack(spacing: 8) {
                HStack {
                    Text("Category")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(store.categories) { category in
                            CategoryChip(
                                category: category,
                                isSelected: selectedCategoryId == category.id
                            ) {
                                selectedCategoryId = category.id
                                suggestedCategory = nil
                            }
                        }
                    }
                    .padding(.horizontal, 2)
                }
            }
            .padding(.top, 16)

            // Account Picker
            if !store.accounts.isEmpty {
                VStack(spacing: 8) {
                    HStack {
                        Text("Account")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(selectedAccount?.name ?? "Select")
                            .font(.subheadline)
                    }
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(store.accounts) { account in
                                Button {
                                    selectedAccountId = account.id
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: account.type.icon)
                                            .font(.caption)
                                        Text(account.name)
                                            .font(.caption)
                                            .lineLimit(1)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(selectedAccountId == account.id
                                                ? Color(hex: account.colorHex)
                                                : Color(.systemGray6))
                                    .foregroundColor(selectedAccountId == account.id ? .white : .primary)
                                    .cornerRadius(20)
                                }
                            }
                        }
                    }
                }
                .padding(.top, 16)
            }

            // Date
            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(.secondary)
                DatePicker("Date", selection: $selectedDate, displayedComponents: [.date, .hourAndMinute])
                    .labelsHidden()
                Spacer()
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .padding(.top, 16)

            // Note
            TextField("Add a note (optional)", text: $note)
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .padding(.top, 8)
        }
    }

    // MARK: - Tax Set-Aside Banner
    var taxSetAsideBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "doc.text.fill")
                .foregroundColor(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text("Tax Set-Aside Recommended")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text("Set aside \(formatAmount(taxSetAside)) (\(Int(appState.taxRate * 100))%) for estimated taxes")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(12)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.orange.opacity(0.3), lineWidth: 1))
    }

    // MARK: - Advanced Section
    var advancedSection: some View {
        VStack(spacing: 12) {
            // Income type (freelancer mode)
            if transactionType == .income && appState.isFreelancerMode {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Income Type")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Picker("Income Type", selection: $incomeType) {
                        ForEach(IncomeType.allCases, id: \.self) { type in
                            Text(type.rawValue.capitalized).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
            }

            // Recurring
            VStack(alignment: .leading, spacing: 8) {
                Toggle("Recurring Transaction", isOn: $isRecurring)
                    .font(.subheadline)
                if isRecurring {
                    Picker("Frequency", selection: $recurringInterval) {
                        ForEach(RecurringInterval.allCases, id: \.self) { interval in
                            Text(interval.displayName).tag(interval)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)

            // Impulse flag
            if transactionType == .expense {
                Toggle(isOn: $isImpulse) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        VStack(alignment: .leading) {
                            Text("Mark as Impulse")
                                .font(.subheadline)
                            Text("Flag to track unplanned spending")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
            }

            // Mood tracking
            VStack(alignment: .leading, spacing: 10) {
                Text("How are you feeling?")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                HStack(spacing: 12) {
                    ForEach(Mood.allCases, id: \.self) { mood in
                        Button {
                            selectedMood = selectedMood == mood ? nil : mood
                        } label: {
                            Text(mood.emoji)
                                .font(.title2)
                                .padding(8)
                                .background(selectedMood == mood ? Color.indigo.opacity(0.2) : Color(.systemGray6))
                                .cornerRadius(10)
                        }
                    }
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)

            // Tags
            VStack(alignment: .leading, spacing: 6) {
                Text("Tags (comma-separated)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("work, travel, family...", text: $tags)
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
        }
    }

    // MARK: - Save
    func saveTransaction() {
        guard amount > 0 else {
            validationMessage = "Please enter an amount greater than 0."
            showValidationError = true
            return
        }
        guard !title.trimmingCharacters(in: .whitespaces).isEmpty else {
            validationMessage = "Please enter a description."
            showValidationError = true
            return
        }

        let category = store.categories.first { $0.id == selectedCategoryId }
        let account = store.accounts.first { $0.id == selectedAccountId }

        // Calculate exchange rate
        let fromRate = Currency.find(selectedCurrency)?.exchangeRate ?? 1
        let toRate = Currency.find(appState.preferredCurrency)?.exchangeRate ?? 1
        let convertedAmount = (amount / fromRate) * toRate
        let exchangeRate = convertedAmount / amount

        let transaction = Transaction(
            amount: amount,
            currency: selectedCurrency,
            amountInBaseCurrency: convertedAmount,
            exchangeRate: exchangeRate,
            title: title,
            note: note,
            date: selectedDate,
            type: transactionType,
            categoryId: category?.id,
            categoryName: category?.name ?? "Uncategorized",
            categoryIcon: category?.icon ?? "questionmark.circle",
            accountId: account?.id,
            accountName: account?.name ?? "Cash",
            incomeType: transactionType == .income ? incomeType : nil,
            taxSetAsideAmount: taxSetAside > 0 ? taxSetAside : nil,
            tags: tags.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) },
            isRecurring: isRecurring,
            recurringInterval: isRecurring ? recurringInterval : nil,
            isImpulse: isImpulse,
            moodAtPurchase: selectedMood
        )

        store.addTransaction(transaction)

        // Accumulate tax set-aside automatically
        if taxSetAside > 0 {
            store.addToTaxSetAside(taxSetAside)
        }

        dismiss()
    }

    func formatAmount(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = appState.preferredCurrency
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(amount)"
    }
}

// MARK: - Category Chip
struct CategoryChip: View {
    var category: ExpenseCategory
    var isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: category.icon)
                    .font(.caption)
                Text(category.name)
                    .font(.caption)
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color(hex: category.colorHex) : Color(.systemGray6))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(20)
        }
    }
}

// MARK: - Currency Picker
struct CurrencyPickerView: View {
    @Binding var selectedCurrency: String
    @Environment(\.dismiss) var dismiss
    @State private var searchText = ""

    var filtered: [Currency] {
        if searchText.isEmpty { return Currency.supported }
        return Currency.supported.filter {
            $0.id.localizedCaseInsensitiveContains(searchText) ||
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationView {
            List(filtered) { currency in
                Button {
                    selectedCurrency = currency.id
                    dismiss()
                } label: {
                    HStack {
                        Text(currency.symbol)
                            .frame(width: 30, alignment: .leading)
                            .font(.headline)
                        VStack(alignment: .leading) {
                            Text(currency.id)
                                .fontWeight(.medium)
                            Text(currency.name)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        if selectedCurrency == currency.id {
                            Image(systemName: "checkmark")
                                .foregroundColor(.indigo)
                        }
                    }
                }
                .foregroundColor(.primary)
            }
            .searchable(text: $searchText, prompt: "Search currency")
            .navigationTitle("Select Currency")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
