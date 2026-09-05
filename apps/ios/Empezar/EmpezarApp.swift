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
            if onboarded || store.signedIn {
                TabView(selection: $selected) {
                    NavigationStack { portfolioRoot }
                        .tabItem { Label("Cartera", systemImage: "chart.pie.fill") }.tag(0)
                    NavigationStack { ExploreView() }
                        .tabItem { Label("Mercados", systemImage: "magnifyingglass") }.tag(1)
                    NavigationStack { LearnView() }
                        .tabItem { Label("Aprender", systemImage: "book.closed") }.tag(2)
                }
            } else { WelcomeView { onboarded = true; if Configuration.configured { store.showAuth = true } } }
        }
        .sheet(isPresented: $store.showAuth) { AuthView() }
        .alert("Un momento", isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })) {
            Button("Entendido", role: .cancel) { store.error = nil }
        } message: { Text(store.error ?? "") }
        .task { await store.start() }
        .onChange(of: scenePhase) { _, phase in if phase == .active { Task { await store.refresh() } } }
    }
    @ViewBuilder private var portfolioRoot: some View {
        #if DEBUG
        if UserDefaults.standard.string(forKey: "preview-screen") == "asset", let instrument = Content.instruments.first {
            InstrumentView(instrument: instrument)
        } else if UserDefaults.standard.string(forKey: "preview-screen") == "trade", let instrument = Content.instruments.first {
            TradeView(instrument: instrument, side: "buy")
        } else { PortfolioView(explore: { selected = 1 }) }
        #else
        PortfolioView(explore: { selected = 1 })
        #endif
    }
}

struct WelcomeView: View {
    var start: () -> Void
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                HStack {
                    Image(systemName: "chart.line.uptrend.xyaxis").foregroundStyle(Theme.accent)
                    Text("empezar").font(.title2.weight(.bold))
                    Spacer()
                    Pill(text: "Dinero virtual", icon: "sparkles")
                }.padding(.top, 16)
                VStack(alignment: .leading, spacing: 16) {
                    Text("Tu primera cartera.\nA tu ritmo.").font(.largeTitle.weight(.bold))
                    Text("Busca empresas, compra acciones con dinero virtual y descubre cómo evoluciona tu cartera.")
                        .font(.body).foregroundStyle(Theme.muted).lineSpacing(4)
                }.padding(.top, 30)
                VStack(alignment: .leading, spacing: 20) {
                    Label("Tu punto de partida", systemImage: "wallet.bifold").font(.subheadline).foregroundStyle(Theme.accent)
                    Text(Money.text(1_000_000)).font(.system(.largeTitle, design: .rounded).weight(.bold)).minimumScaleFactor(0.6).lineLimit(1)
                    Text("Saldo virtual de bienvenida").font(.subheadline).foregroundStyle(Theme.muted)
                    Divider().overlay(Theme.line)
                    Label("Compra y vende sin arriesgar tu dinero", systemImage: "arrow.left.arrow.right")
                    Label("Empresas y fondos reales", systemImage: "building.2")
                    Label("Todo lo que necesitas para aprender", systemImage: "book.closed")
                }.font(.subheadline).padding(24).dataCard()
                PrimaryButton(title: "Crear mi primera cartera", icon: "plus") { start() }
                Text("Las operaciones son simuladas. El saldo virtual no se puede retirar ni canjear por dinero real.")
                    .font(.caption).foregroundStyle(Theme.muted).lineSpacing(3)
            }.padding(24)
        }.appCanvas()
    }
}
