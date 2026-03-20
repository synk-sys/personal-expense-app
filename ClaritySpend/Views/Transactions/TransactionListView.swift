import SwiftUI

struct TransactionListView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var store = PersistenceController.shared
    @StateObject private var viewModel = TransactionViewModel()

    @State private var showingFilterSheet = false
    @State private var transactionToDelete: Transaction? = nil
    @State private var transactionToEdit: Transaction? = nil
    @State private var showingDeleteConfirm = false

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // MARK: - Summary Bar
                summaryBar

                // MARK: - Filter Tabs
                filterTabs

                // MARK: - Transaction List
                if viewModel.filteredTransactions.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(viewModel.groupedTransactions, id: \.0) { group, transactions in
                            Section(header: groupHeader(title: group, transactions: transactions)) {
                                ForEach(transactions) { txn in
                                    TransactionRow(transaction: txn, currency: appState.preferredCurrency)
                                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                                        .listRowBackground(Color(.systemBackground))
                                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                            Button(role: .destructive) {
                                                transactionToDelete = txn
                                                showingDeleteConfirm = true
                                            } label: {
                                                Label("Delete", systemImage: "trash")
                                            }

                                            Button {
                                                transactionToEdit = txn
                                            } label: {
                                                Label("Edit", systemImage: "pencil")
                                            }
                                            .tint(.indigo)
                                        }
                                        .swipeActions(edge: .leading) {
                                            Button {
                                                var updated = txn
                                                updated = Transaction(
                                                    id: txn.id, amount: txn.amount,
                                                    currency: txn.currency,
                                                    amountInBaseCurrency: txn.amountInBaseCurrency,
                                                    exchangeRate: txn.exchangeRate,
                                                    title: txn.title, note: txn.note,
                                                    date: txn.date, type: txn.type,
                                                    categoryId: txn.categoryId,
                                                    categoryName: txn.categoryName,
                                                    categoryIcon: txn.categoryIcon,
                                                    accountId: txn.accountId,
                                                    accountName: txn.accountName,
                                                    isRecurring: txn.isRecurring,
                                                    isImpulse: !txn.isImpulse,
                                                    moodAtPurchase: txn.moodAtPurchase
                                                )
                                                store.updateTransaction(updated)
                                            } label: {
                                                Label(txn.isImpulse ? "Not Impulse" : "Impulse",
                                                      systemImage: "exclamationmark.triangle.fill")
                                            }
                                            .tint(.orange)
                                        }
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Transactions")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showingFilterSheet = true
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .foregroundColor(.indigo)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        appState.showingAddTransaction = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.indigo)
                    }
                }
            }
            .searchable(text: $viewModel.searchText, prompt: "Search transactions")
            .sheet(isPresented: $showingFilterSheet) {
                FilterSheetView(viewModel: viewModel)
            }
            .confirmationDialog("Delete Transaction",
                               isPresented: $showingDeleteConfirm,
                               titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    if let txn = transactionToDelete {
                        store.deleteTransaction(txn)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete the transaction.")
            }
        }
        .onAppear {
            viewModel.objectWillChange.send()
        }
    }

    // MARK: - Summary Bar
    var summaryBar: some View {
        HStack(spacing: 0) {
            SummaryPill(label: "Out", amount: viewModel.totalExpenses, color: .red, currency: appState.preferredCurrency)
            Divider().frame(height: 30)
            SummaryPill(label: "In", amount: viewModel.totalIncome, color: .green, currency: appState.preferredCurrency)
            Divider().frame(height: 30)
            SummaryPill(label: "Net", amount: viewModel.netFlow, color: viewModel.netFlow >= 0 ? .green : .red, currency: appState.preferredCurrency)
        }
        .padding(.vertical, 10)
        .background(Color(.systemBackground))
    }

    // MARK: - Filter Tabs
    var filterTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(TransactionViewModel.TransactionFilter.allCases, id: \.self) { filter in
                    FilterChipButton(
                        title: filter.rawValue,
                        isSelected: viewModel.selectedFilter == filter
                    ) {
                        viewModel.selectedFilter = filter
                    }
                }
                Divider().frame(height: 24)
                ForEach(TransactionViewModel.DateRange.allCases, id: \.self) { range in
                    FilterChipButton(
                        title: range.rawValue,
                        isSelected: viewModel.selectedDateRange == range
                    ) {
                        viewModel.selectedDateRange = range
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(Color(.systemBackground))
    }

    // MARK: - Group Header
    func groupHeader(title: String, transactions: [Transaction]) -> some View {
        let total = transactions.reduce(0) { sum, txn in
            sum + (txn.type == .expense ? -txn.amountInBaseCurrency : txn.amountInBaseCurrency)
        }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = appState.preferredCurrency

        return HStack {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
            Spacer()
            Text(formatter.string(from: NSNumber(value: total)) ?? "")
                .font(.caption)
                .foregroundColor(total >= 0 ? .green : .red)
        }
    }

    // MARK: - Empty State
    var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 50))
                .foregroundColor(.secondary)
            Text("No transactions found")
                .font(.headline)
                .foregroundColor(.secondary)
            Text("Try adjusting your filters or adding a new transaction.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button("Add Transaction") {
                appState.showingAddTransaction = true
            }
            .buttonStyle(.borderedProminent)
            .tint(.indigo)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Summary Pill
struct SummaryPill: View {
    var label: String
    var amount: Double
    var color: Color
    var currency: String

    var body: some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(formatted)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
    }

    var formatted: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        if abs(amount) >= 1000 {
            formatter.maximumFractionDigits = 0
        }
        return formatter.string(from: NSNumber(value: amount)) ?? "\(amount)"
    }
}

// MARK: - Filter Chip Button
struct FilterChipButton: View {
    var title: String
    var isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.indigo : Color(.systemGray6))
                .cornerRadius(20)
        }
    }
}

// MARK: - Filter Sheet
struct FilterSheetView: View {
    @ObservedObject var viewModel: TransactionViewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section("Sort By") {
                    Picker("Sort Order", selection: $viewModel.sortOrder) {
                        ForEach(TransactionViewModel.SortOrder.allCases, id: \.self) { order in
                            Text(order.rawValue).tag(order)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
            }
            .navigationTitle("Filters & Sort")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
