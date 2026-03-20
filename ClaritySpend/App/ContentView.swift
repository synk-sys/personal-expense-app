import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        TabView(selection: $appState.selectedTab) {
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "house.fill")
                }
                .tag(AppState.Tab.dashboard)

            TransactionListView()
                .tabItem {
                    Label("Transactions", systemImage: "list.bullet.rectangle")
                }
                .tag(AppState.Tab.transactions)

            BudgetView()
                .tabItem {
                    Label("Budget", systemImage: "chart.pie.fill")
                }
                .tag(AppState.Tab.budget)

            InsightsView()
                .tabItem {
                    Label("Insights", systemImage: "brain.head.profile")
                }
                .tag(AppState.Tab.insights)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(AppState.Tab.settings)
        }
        .sheet(isPresented: $appState.showingAddTransaction) {
            AddTransactionView()
        }
        .tint(.indigo)
    }
}
