import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var store = PersistenceController.shared
    @State private var showingCurrencyPicker = false
    @State private var showingAbout = false
    @State private var showingExport = false
    @State private var showingCategoryManager = false
    @State private var showingAccountManager = false
    @State private var exportContent = ""
    @State private var showingDeleteConfirm = false

    var body: some View {
        NavigationView {
            List {
                // MARK: - Privacy First Banner
                Section {
                    privacyBanner
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)

                // MARK: - Preferences
                Section("Preferences") {
                    // Base Currency
                    Button {
                        showingCurrencyPicker = true
                    } label: {
                        HStack {
                            SettingsIcon(icon: "dollarsign.circle.fill", color: .green)
                            Text("Base Currency")
                            Spacer()
                            Text(appState.preferredCurrency)
                                .foregroundColor(.secondary)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .foregroundColor(.primary)
                    .sheet(isPresented: $showingCurrencyPicker) {
                        CurrencyPickerView(selectedCurrency: $appState.preferredCurrency)
                            .onChange(of: appState.preferredCurrency) { newValue in
                                UserDefaults.standard.set(newValue, forKey: "preferredCurrency")
                            }
                    }

                    // Appearance
                    NavigationLink {
                        AppearanceSettingsView()
                    } label: {
                        HStack {
                            SettingsIcon(icon: "paintbrush.fill", color: .purple)
                            Text("Appearance")
                        }
                    }
                }

                // MARK: - Freelancer Mode
                Section("Income & Tax") {
                    Toggle(isOn: $appState.isFreelancerMode) {
                        HStack {
                            SettingsIcon(icon: "briefcase.fill", color: .orange)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Freelancer Mode")
                                Text("Variable income & tax set-aside")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .onChange(of: appState.isFreelancerMode) { value in
                        UserDefaults.standard.set(value, forKey: "isFreelancerMode")
                        if var budget = store.budget {
                            budget = Budget(
                                id: budget.id, name: budget.name,
                                totalAmount: budget.totalAmount,
                                envelopes: budget.envelopes,
                                isFreelancerMode: value,
                                minimumIncome: budget.minimumIncome,
                                comfortIncome: budget.comfortIncome,
                                taxRate: budget.taxRate,
                                taxSetAsideBalance: budget.taxSetAsideBalance
                            )
                            store.saveBudget(budget)
                        }
                    }

                    if appState.isFreelancerMode {
                        HStack {
                            SettingsIcon(icon: "percent", color: .orange)
                            Text("Tax Rate")
                            Spacer()
                            Stepper("\(Int(appState.taxRate * 100))%",
                                    value: $appState.taxRate,
                                    in: 0.05...0.50,
                                    step: 0.01)
                                .labelsHidden()
                            Text("\(Int(appState.taxRate * 100))%")
                                .foregroundColor(.secondary)
                                .frame(width: 40, alignment: .trailing)
                        }
                        .onChange(of: appState.taxRate) { value in
                            UserDefaults.standard.set(value, forKey: "taxRate")
                        }
                    }
                }

                // MARK: - Data & Privacy
                Section("Data & Privacy") {
                    Toggle(isOn: $appState.iCloudSyncEnabled) {
                        HStack {
                            SettingsIcon(icon: "icloud.fill", color: .blue)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("iCloud Sync")
                                Text("Sync across your Apple devices")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .onChange(of: appState.iCloudSyncEnabled) { value in
                        UserDefaults.standard.set(value, forKey: "iCloudSyncEnabled")
                    }

                    Button {
                        exportContent = store.exportAsCSV()
                        showingExport = true
                    } label: {
                        HStack {
                            SettingsIcon(icon: "arrow.up.doc.fill", color: .indigo)
                            Text("Export Data (CSV)")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .foregroundColor(.primary)
                    .sheet(isPresented: $showingExport) {
                        ExportView(csvContent: exportContent)
                    }

                    Button(role: .destructive) {
                        showingDeleteConfirm = true
                    } label: {
                        HStack {
                            SettingsIcon(icon: "trash.fill", color: .red)
                            Text("Delete All Data")
                        }
                    }
                    .confirmationDialog("Delete All Data",
                                       isPresented: $showingDeleteConfirm,
                                       titleVisibility: .visible) {
                        Button("Delete Everything", role: .destructive) {
                            deleteAllData()
                        }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text("This will permanently delete all your transactions, budgets, and accounts. This cannot be undone.")
                    }
                }

                // MARK: - Manage
                Section("Manage") {
                    Button {
                        showingCategoryManager = true
                    } label: {
                        HStack {
                            SettingsIcon(icon: "tag.fill", color: .teal)
                            Text("Manage Categories")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .foregroundColor(.primary)
                    .sheet(isPresented: $showingCategoryManager) {
                        CategoryManagerView()
                    }

                    Button {
                        showingAccountManager = true
                    } label: {
                        HStack {
                            SettingsIcon(icon: "building.columns.fill", color: .blue)
                            Text("Manage Accounts")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .foregroundColor(.primary)
                    .sheet(isPresented: $showingAccountManager) {
                        AccountManagerView()
                    }
                }

                // MARK: - About
                Section("About") {
                    Button {
                        showingAbout = true
                    } label: {
                        HStack {
                            SettingsIcon(icon: "info.circle.fill", color: .gray)
                            Text("About ClaritySpend")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .foregroundColor(.primary)
                    .sheet(isPresented: $showingAbout) {
                        AboutView()
                    }

                    HStack {
                        SettingsIcon(icon: "number", color: .gray)
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Settings")
        }
    }

    // MARK: - Privacy Banner
    var privacyBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "lock.shield.fill")
                .font(.title2)
                .foregroundColor(.green)
            VStack(alignment: .leading, spacing: 4) {
                Text("Your data stays on your device")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text("No account required. No data sold. No bank credentials stored.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .background(Color.green.opacity(0.08))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.green.opacity(0.2), lineWidth: 1))
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    func deleteAllData() {
        store.transactions.removeAll()
        store.accounts.removeAll()
        store.budget = nil
        store.netWorthHistory.removeAll()
        store.saveAll()
    }
}

// MARK: - Settings Icon
struct SettingsIcon: View {
    var icon: String
    var color: Color

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 7)
                .fill(color)
                .frame(width: 30, height: 30)
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(.white)
        }
    }
}

// MARK: - Export View
struct ExportView: View {
    var csvContent: String
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Your transaction data is ready to export.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text(csvContent.prefix(2000) + (csvContent.count > 2000 ? "\n..." : ""))
                        .font(.system(.caption, design: .monospaced))
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)

                    ShareLink(item: csvContent,
                              preview: SharePreview("clarity_transactions.csv",
                                                    image: Image(systemName: "doc.text"))) {
                        Label("Share / Export CSV", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.indigo)
                }
                .padding()
            }
            .navigationTitle("Export Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Category Manager
struct CategoryManagerView: View {
    @StateObject private var store = PersistenceController.shared
    @Environment(\.dismiss) var dismiss
    @State private var showingAddCategory = false
    @State private var categoryToDelete: ExpenseCategory? = nil

    var body: some View {
        NavigationView {
            List {
                ForEach(store.categories) { category in
                    HStack(spacing: 12) {
                        CategoryIconView(icon: category.icon, colorHex: category.colorHex, size: 32)
                        VStack(alignment: .leading) {
                            Text(category.name)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            if !category.keywords.isEmpty {
                                Text(category.keywords.prefix(3).joined(separator: ", "))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        Spacer()
                        if category.isCustom {
                            Text("Custom")
                                .font(.caption2)
                                .foregroundColor(.indigo)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.indigo.opacity(0.1))
                                .cornerRadius(4)
                        }
                    }
                    .swipeActions(edge: .trailing) {
                        if category.isCustom {
                            Button(role: .destructive) {
                                store.deleteCategory(category)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Categories")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddCategory = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddCategory) {
                AddCategoryView()
            }
        }
    }
}

// MARK: - Add Category
struct AddCategoryView: View {
    @StateObject private var store = PersistenceController.shared
    @Environment(\.dismiss) var dismiss
    @State private var name = ""
    @State private var icon = "tag.fill"
    @State private var colorHex = "#6C5CE7"
    @State private var keywords = ""

    let iconOptions = ["tag.fill", "star.fill", "heart.fill", "house.fill", "car.fill",
                       "gamecontroller.fill", "music.note", "camera.fill", "gift.fill",
                       "sportscourt.fill", "pawprint.fill", "leaf.fill", "flame.fill"]

    var body: some View {
        NavigationView {
            Form {
                Section("Name") {
                    TextField("Category name", text: $name)
                }
                Section("Icon") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 12) {
                        ForEach(iconOptions, id: \.self) { iconName in
                            Button {
                                icon = iconName
                            } label: {
                                Image(systemName: iconName)
                                    .font(.title3)
                                    .foregroundColor(icon == iconName ? Color(hex: colorHex) : .secondary)
                                    .frame(width: 44, height: 44)
                                    .background(icon == iconName ? Color(hex: colorHex).opacity(0.2) : Color(.systemGray6))
                                    .cornerRadius(10)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                Section("Keywords (for auto-detection)") {
                    TextField("amazon, shopping, online...", text: $keywords)
                }
            }
            .navigationTitle("New Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        let category = ExpenseCategory(
                            name: name,
                            icon: icon,
                            colorHex: colorHex,
                            isCustom: true,
                            keywords: keywords.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                        )
                        store.addCategory(category)
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}

// MARK: - Account Manager
struct AccountManagerView: View {
    @StateObject private var store = PersistenceController.shared
    @Environment(\.dismiss) var dismiss
    @State private var showingAddAccount = false

    var body: some View {
        NavigationView {
            List {
                let assets = store.accounts.filter { $0.type.isAsset }
                let liabilities = store.accounts.filter { !$0.type.isAsset }

                if !assets.isEmpty {
                    Section("Assets") {
                        ForEach(assets) { account in
                            AccountRow(account: account)
                        }
                        .onDelete { indexSet in
                            indexSet.forEach { idx in store.deleteAccount(assets[idx]) }
                        }
                    }
                }

                if !liabilities.isEmpty {
                    Section("Liabilities") {
                        ForEach(liabilities) { account in
                            AccountRow(account: account)
                        }
                        .onDelete { indexSet in
                            indexSet.forEach { idx in store.deleteAccount(liabilities[idx]) }
                        }
                    }
                }
            }
            .navigationTitle("Accounts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddAccount = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddAccount) {
                AddAccountView()
            }
        }
    }
}

struct AccountRow: View {
    var account: Account

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color(hex: account.colorHex).opacity(0.2))
                    .frame(width: 36, height: 36)
                Image(systemName: account.type.icon)
                    .foregroundColor(Color(hex: account.colorHex))
            }
            VStack(alignment: .leading) {
                Text(account.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                if let institution = account.institution {
                    Text(institution)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            Text(formatAmount(account.balance, currency: account.currency))
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(account.balance >= 0 ? .primary : .red)
        }
    }

    func formatAmount(_ amount: Double, currency: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        return formatter.string(from: NSNumber(value: amount)) ?? "\(amount)"
    }
}

// MARK: - Add Account
struct AddAccountView: View {
    @StateObject private var store = PersistenceController.shared
    @Environment(\.dismiss) var dismiss

    @State private var name = ""
    @State private var accountType: AccountType = .checking
    @State private var balance = ""
    @State private var currency = "USD"
    @State private var institution = ""
    @State private var creditLimit = ""
    @State private var showCurrencyPicker = false
    @State private var colorHex = "#4ECDC4"

    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Account name (e.g. Chase Checking)", text: $name)
                    Picker("Type", selection: $accountType) {
                        ForEach(AccountType.allCases, id: \.self) { type in
                            Label(type.displayName, systemImage: type.icon).tag(type)
                        }
                    }
                    TextField("Institution (optional)", text: $institution)
                }

                Section("Balance") {
                    HStack {
                        Text(Currency.find(currency)?.symbol ?? "$")
                            .foregroundColor(.secondary)
                        TextField("0.00", text: $balance)
                            .keyboardType(.decimalPad)
                    }

                    if accountType == .creditCard || accountType == .loan {
                        HStack {
                            Text("Credit Limit")
                            Spacer()
                            TextField("0.00", text: $creditLimit)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 100)
                        }
                    }
                }

                Section("Currency") {
                    Button {
                        showCurrencyPicker = true
                    } label: {
                        HStack {
                            Text("Currency")
                                .foregroundColor(.primary)
                            Spacer()
                            Text(currency)
                                .foregroundColor(.secondary)
                        }
                    }
                    .sheet(isPresented: $showCurrencyPicker) {
                        CurrencyPickerView(selectedCurrency: $currency)
                    }
                }
            }
            .navigationTitle("Add Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        let account = Account(
                            name: name,
                            type: accountType,
                            balance: (accountType.isAsset ? 1 : -1) * (Double(balance) ?? 0),
                            currency: currency,
                            colorHex: colorHex,
                            institution: institution.isEmpty ? nil : institution,
                            creditLimit: Double(creditLimit)
                        )
                        store.addAccount(account)
                        store.recordNetWorthSnapshot()
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}

// MARK: - Appearance Settings
struct AppearanceSettingsView: View {
    @AppStorage("colorScheme") private var colorSchemePreference = "system"

    var body: some View {
        Form {
            Section("Color Scheme") {
                Picker("Appearance", selection: $colorSchemePreference) {
                    Text("System").tag("system")
                    Text("Light").tag("light")
                    Text("Dark").tag("dark")
                }
                .pickerStyle(.inline)
            }
        }
        .navigationTitle("Appearance")
    }
}

// MARK: - About View
struct AboutView: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // App Icon area
                    ZStack {
                        RoundedRectangle(cornerRadius: 24)
                            .fill(LinearGradient(
                                colors: [Color(hex: "#6C5CE7"), Color(hex: "#a29bfe")],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            ))
                            .frame(width: 100, height: 100)
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 44))
                            .foregroundColor(.white)
                    }

                    VStack(spacing: 8) {
                        Text("ClaritySpend")
                            .font(.title)
                            .fontWeight(.bold)
                        Text("Version 1.0.0")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text("Personal finance that respects your privacy.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    VStack(alignment: .leading, spacing: 16) {
                        FeatureRow(icon: "lock.shield.fill", color: .green,
                                   title: "Privacy-First",
                                   description: "All data lives on your device. No account, no cloud by default, no data selling.")
                        FeatureRow(icon: "briefcase.fill", color: .orange,
                                   title: "Freelancer Mode",
                                   description: "Variable income tracking with automatic tax set-aside calculations.")
                        FeatureRow(icon: "brain.head.profile", color: .indigo,
                                   title: "Behavioral Coaching",
                                   description: "Actionable insights on your spending patterns, not just charts.")
                        FeatureRow(icon: "globe", color: .blue,
                                   title: "Multi-Currency",
                                   description: "25+ currencies with automatic conversion to your base currency.")
                        FeatureRow(icon: "envelope.fill", color: .teal,
                                   title: "Envelope Budgeting",
                                   description: "Classic envelope method with modern design and smart tracking.")
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(16)
                    .padding(.horizontal)
                }
                .padding(.vertical, 24)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct FeatureRow: View {
    var icon: String
    var color: Color
    var title: String
    var description: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .foregroundColor(color)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
