import SwiftUI

@main struct EmpezarApp: App {
    @StateObject private var store = AppStore()
    var body: some Scene { WindowGroup { RootView().environmentObject(store).tint(Theme.ink) } }
}
struct RootView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("has-onboarded-v0") private var onboarded = false
    @State private var selected = 0
    var body: some View {
        Group {
            if onboarded || store.signedIn {
                TabView(selection: $selected) {
                    NavigationStack { PortfolioView(explore: { selected = 1 }) }.tabItem { Label("Cartera", systemImage: "square.stack.3d.up") }.tag(0)
                    NavigationStack { ExploreView() }.tabItem { Label("Explorar", systemImage: "circle.grid.2x2") }.tag(1)
                    NavigationStack { LearnView() }.tabItem { Label("Aprender", systemImage: "book.closed") }.tag(2)
                }.toolbarBackground(Theme.paper, for: .tabBar).toolbarBackground(.visible, for: .tabBar)
            } else { WelcomeView { onboarded = true; if Configuration.configured { store.showAuth = true } } }
        }
        .sheet(isPresented: $store.showAuth) { AuthView() }
        .alert("Un momento", isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })) {
            Button("Entendido", role: .cancel) { store.error = nil }
        } message: { Text(store.error ?? "") }
        .task { await store.start() }
        .onChange(of: scenePhase) { _, phase in if phase == .active { Task { await store.refresh() } } }
    }
}
struct WelcomeView: View {
    var start: () -> Void
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                Text("empezar.").font(.system(.title, design: .serif)).padding(.top, 12)
                HStack { Spacer(); OrbitMark(); Spacer() }.padding(.vertical, 20)
                Text("Dinero virtual.\nLo que aprendes,\nes real.").font(.system(.largeTitle, design: .serif)).fixedSize(horizontal: false, vertical: true)
                Text("Tu primer paso para entender la bolsa. Invierte 10.000 $ virtuales en empresas y fondos reales, a tu ritmo.").font(.body).lineSpacing(5).foregroundStyle(Theme.lime.opacity(0.85))
                VStack(alignment: .leading, spacing: 18) {
                    Label("Precios reales y operaciones simuladas", systemImage: "globe")
                    Label("Negocios, bonos y valoración", systemImage: "book")
                    Label("Sin depósitos ni dinero retirable", systemImage: "leaf")
                }.font(.subheadline)
                Button(action: start) {
                    HStack { Text(Configuration.configured ? "Empezar a aprender" : "Explorar la V0"); Spacer(); Image(systemName: "arrow.right") }
                        .font(.body.weight(.semibold)).padding(21).foregroundStyle(Theme.forest).background(Theme.lime, in: RoundedRectangle(cornerRadius: 20))
                }.padding(.top, 10)
            }.padding(28)
        }.foregroundStyle(Theme.lime).background(Theme.forest)
    }
}
