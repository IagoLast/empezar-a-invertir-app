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
    @State private var introductionCompleted = UserDefaults.standard.bool(forKey: "has-seen-introduction")
    @State private var selected: Int = {
        #if DEBUG
        return UserDefaults.standard.integer(forKey: "preview-tab")
        #else
        return 0
        #endif
    }()
    private var showsIntroduction: Bool {
        #if DEBUG
        if UserDefaults.standard.bool(forKey: "preview-introduction") { return !introductionCompleted }
        #endif
        return !store.signedIn && !introductionCompleted
    }
    var body: some View {
        Group {
            if showsIntroduction {
                OnboardingView {
                    UserDefaults.standard.set(true, forKey: "has-seen-introduction")
                    introductionCompleted = true
                }
            } else if !store.signedIn {
                AuthView(required: true)
            } else {
                TabView(selection: $selected) {
                    NavigationStack { portfolioRoot }
                        .tabItem { Label("Inicio", systemImage: "chart.pie.fill") }.tag(0)
                    NavigationStack { ExploreView() }
                        .tabItem { Label("Invertir", systemImage: "magnifyingglass") }.tag(1)
                    NavigationStack { ActivityView() }
                        .tabItem { Label("Operaciones", systemImage: "arrow.left.arrow.right") }.tag(3)
                    NavigationStack { LearnView() }
                        .tabItem { Label("Aprender", systemImage: "book.closed") }.tag(2)
                }
            }
        }
        .sheet(isPresented: $store.showAuth) { AuthView() }
        .alert("Un momento", isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })) {
            Button("Entendido", role: .cancel) { store.error = nil }
        } message: { Text(store.error ?? "") }
        .task { await store.start() }
        .onReceive(NotificationCenter.default.publisher(for: .showOrders)) { _ in selected = 3 }
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3))
                if Task.isCancelled { break }
                if !store.portfolio.queuedOrders.isEmpty { await store.refreshOrderState() }
            }
        }
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
