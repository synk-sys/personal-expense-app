import SwiftUI

@main
struct ClaritySpendApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(AppState())
        }
    }
}

class AppState: ObservableObject {
    @Published var selectedTab: Tab = .dashboard
    @Published var showingAddTransaction = false
    @Published var preferredCurrency: String = UserDefaults.standard.string(forKey: "preferredCurrency") ?? "USD"
    @Published var isFreelancerMode: Bool = UserDefaults.standard.bool(forKey: "isFreelancerMode")
    @Published var taxRate: Double = UserDefaults.standard.double(forKey: "taxRate") == 0 ? 0.25 : UserDefaults.standard.double(forKey: "taxRate")
    @Published var iCloudSyncEnabled: Bool = UserDefaults.standard.bool(forKey: "iCloudSyncEnabled")

    enum Tab {
        case dashboard, transactions, budget, insights, settings
    }
}
