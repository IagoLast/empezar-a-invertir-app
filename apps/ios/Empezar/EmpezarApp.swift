import SwiftUI

@main struct EmpezarApp: App {
    @StateObject private var store = AppStore()
    @AppStorage("app-appearance") private var appearance = AppAppearance.light.rawValue
    var body: some Scene {
        WindowGroup {
            RootView().environmentObject(store).tint(Theme.accent)
                .preferredColorScheme((AppAppearance(rawValue: appearance) ?? .light).colorScheme)
        }
    }
}

struct RootView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("has-onboarded-v0") private var onboarded = false
    @State private var selected: Int = {
        #if DEBUG
        return UserDefaults.standard.integer(forKey: "preview-tab")
        #else
        return 0
        #endif
    }()
    var body: some View {
        Group {
            if (onboarded || store.signedIn) && !store.canAccessApp {
                PaywallView(required: true)
            } else if onboarded || store.signedIn {
                TabView(selection: $selected) {
                    NavigationStack { portfolioRoot }
                        .tabItem { Label("Cartera", systemImage: "chart.pie.fill") }.tag(0)
                    NavigationStack { ExploreView() }
                        .tabItem { Label("Mercados", systemImage: "magnifyingglass") }.tag(1)
                    NavigationStack { ActivityView() }
                        .tabItem { Label("Movimientos", systemImage: "arrow.left.arrow.right") }.tag(3)
                    NavigationStack { LearnView() }
                        .tabItem { Label("Aprender", systemImage: "book.closed") }.tag(2)
                }
            } else {
                OnboardingView { authenticate in
                    onboarded = true
                    if authenticate { store.showAuth = true }
                }
            }
        }
        .sheet(isPresented: $store.showAuth) { AuthView() }
        .alert("Un momento", isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })) {
            Button("Entendido", role: .cancel) { store.error = nil }
        } message: { Text(store.error ?? "") }
        .task { await store.start() }
        .onChange(of: scenePhase) { _, phase in if phase == .active { Task { await store.preparePurchases(); await store.refresh() } } }
    }
    @ViewBuilder private var portfolioRoot: some View {
        #if DEBUG
        if ["asset", "trade"].contains(UserDefaults.standard.string(forKey: "preview-screen") ?? ""), let instrument = Content.instruments.first {
            InstrumentView(instrument: instrument)
        } else { PortfolioView(explore: { selected = 1 }) }
        #else
        PortfolioView(explore: { selected = 1 })
        #endif
    }
}
