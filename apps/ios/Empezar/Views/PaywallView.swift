import SwiftUI

struct PaywallView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var showProfile = false
    @State private var authenticate = false
    var required = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Pill(text: "Empezar Plus", icon: "sparkles")
                    Text("Aprende y practica\ncon Empezar Plus.")
                        .font(.system(.largeTitle, design: .rounded).weight(.bold))
                    Text("Tu espacio para entender el mercado y practicar con dinero ficticio.")
                        .foregroundStyle(Theme.muted)
                    VStack(alignment: .leading, spacing: 18) {
                        Label("Todas las lecciones y el laboratorio", systemImage: "book.closed")
                        Label("Simulador con precios de mercado", systemImage: "chart.line.uptrend.xyaxis")
                        Label("10.000 US$ virtuales de bienvenida", systemImage: "chart.pie")
                    }.font(.subheadline.weight(.medium)).padding(22)
                        .frame(maxWidth: .infinity, alignment: .leading).dataCard()

                    if Configuration.freePreviewEnabled {
                        Text("Ahora puedes acceder gratis a las lecciones y al simulador. No necesitas suscribirte.")
                            .font(.subheadline).foregroundStyle(Theme.accent)
                    }
                    if store.hasSubscription {
                        Label("Empezar Plus está activo", systemImage: "checkmark.seal.fill")
                        manageSubscription
                    } else if !store.signedIn {
                        PrimaryButton(title: "Iniciar sesión para continuar", icon: "person.crop.circle") {
                            authenticate = true
                        }
                    } else if store.purchasesLoading {
                        ProgressView("Cargando opciones…").frame(maxWidth: .infinity)
                    } else if let package = store.monthlyPackage {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Plan mensual").font(.headline)
                            Text("\(package.storeProduct.localizedPriceString) / mes")
                                .font(.title.weight(.semibold))
                            if let trial = store.trialDescription {
                                Text("\(trial) gratis; después, \(package.storeProduct.localizedPriceString) al mes.")
                                    .font(.subheadline).foregroundStyle(Theme.muted)
                            }
                            PrimaryButton(title: store.trialDescription.map { "Probar \($0) gratis" } ?? "Suscribirme",
                                          loading: store.busy) {
                                Task { await store.subscribe() }
                            }
                            Text("Suscripción con renovación automática. Apple cobrará el importe al confirmar o al terminar la prueba gratuita, si corresponde. Puedes cancelar en Ajustes de App Store antes de la renovación. Las recargas de saldo se compran por separado.")
                                .font(.caption).foregroundStyle(Theme.muted).lineSpacing(3)
                        }.padding(22).dataCard()
                    } else {
                        Text("La suscripción todavía no está disponible en App Store.")
                            .foregroundStyle(Theme.muted)
                    }
                    if let message = store.purchasesError {
                        Text(message).font(.subheadline).foregroundStyle(Theme.loss)
                            .accessibilityIdentifier("purchase-error")
                    }
                    if store.signedIn {
                        Button("Restaurar compras") { Task { await store.restorePurchases() } }
                            .disabled(store.busy || store.purchasesLoading).frame(minHeight: 44)
                        if !store.hasSubscription { manageSubscription }
                    }
                    Link("Condiciones de uso", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                        .frame(minHeight: 44)
                    if let url = URL(string: Configuration.value("PRIVACY_POLICY_URL")), url.scheme == "https" {
                        Link("Política de privacidad", destination: url).frame(minHeight: 44)
                    }
                    Text("Las operaciones y el saldo son ficticios. No se puede retirar ni canjear saldo por dinero real.")
                        .font(.caption).foregroundStyle(Theme.muted)
                }.padding(25)
            }.refreshable {
                guard !store.busy else { return }
                await store.preparePurchases()
            }.appCanvas().navigationTitle("Empezar Plus").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        if required {
                            Button("Mi cuenta") { showProfile = true }.disabled(store.busy || store.purchasesLoading)
                        } else {
                            Button("Cerrar") { dismiss() }.disabled(store.busy)
                        }
                    }
                }
        }
        .onChange(of: store.hasSubscription) { _, active in if active && !required { dismiss() } }
        .interactiveDismissDisabled(store.busy)
        .sheet(isPresented: $authenticate) { AuthView() }
        .sheet(isPresented: $showProfile) { ProfileView() }
        .task { await store.preparePurchases() }
    }

    private var manageSubscription: some View {
        Link("Gestionar suscripción en Apple", destination: URL(string: "https://apps.apple.com/account/subscriptions")!)
            .frame(minHeight: 44)
    }
}
