import SwiftUI
import RevenueCat
import AuthenticationServices

struct AuthView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var busy = false
    @State private var error: String?
    @State private var appleNonce = ""
    @StateObject private var access = AuthAccessState()
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 25) {
                    Image(systemName: "person.crop.circle").font(.largeTitle).foregroundStyle(Theme.accent).padding(.top, 8)
                    Text("Tu aprendizaje,\nsiempre contigo.").font(.system(.largeTitle, design: .rounded).weight(.bold))
                    Text("Guarda tus inversiones de práctica y las lecciones completadas. Podrás retomarlas cuando quieras.")
                        .foregroundStyle(Theme.muted).lineSpacing(4)
                    if let error { Text(error).font(.subheadline).foregroundStyle(Theme.loss) }

                    VStack(spacing: 12) {
                        if access.providers?.appleEnabled == true {
                            SignInWithAppleButton(.continue) { request in
                                appleNonce = AuthStore.nonce()
                                request.requestedScopes = [.fullName, .email]
                                request.nonce = AuthStore.sha256(appleNonce)
                            } onCompletion: { result in
                                switch result {
                                case .failure(let failure):
                                    if (failure as? ASAuthorizationError)?.code != .canceled { error = "No hemos podido continuar con Apple. Vuelve a intentarlo." }
                                case .success(let authorization):
                                    guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                                          let tokenData = credential.identityToken,
                                          let token = String(data: tokenData, encoding: .utf8),
                                          !appleNonce.isEmpty else {
                                        error = "No hemos podido completar el acceso con Apple. Vuelve a intentarlo."
                                        return
                                    }
                                    finishLogin { try await store.auth.signInWithApple(identityToken: token, nonce: appleNonce) }
                                }
                            }
                            .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                            .frame(height: 56)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .disabled(busy)
                            .accessibilityIdentifier("sign-in-apple")
                        }

                        if access.providers?.googleEnabled == true {
                            Button {
                                finishLogin { try await store.auth.signInWithGoogle() }
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "g.circle.fill").font(.title3)
                                    Text("Continuar con Google").font(.body.weight(.semibold))
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 54)
                                .foregroundStyle(Theme.ink)
                                .flatControl(radius: 16)
                            }
                            .buttonStyle(.plain)
                            .disabled(busy)
                            .accessibilityIdentifier("sign-in-google")
                        }
                    }

                    if busy {
                        HStack(spacing: 10) { ProgressView(); Text("Conectando…") }
                            .font(.subheadline).foregroundStyle(Theme.muted).frame(maxWidth: .infinity)
                    }
                    if access.phase == .loading {
                        HStack(spacing: 12) {
                            ProgressView()
                            Text("Preparando el acceso…").font(.subheadline)
                        }.foregroundStyle(Theme.muted).frame(maxWidth: .infinity, alignment: .leading)
                            .accessibilityIdentifier("auth-loading")
                    } else if access.phase == .failed {
                        VStack(alignment: .leading, spacing: 10) {
                            Label("No hemos podido conectar", systemImage: "wifi.exclamationmark").font(.headline)
                            Text("Desliza hacia abajo para volver a intentarlo. También puedes seguir explorando y entrar más tarde.")
                                .font(.subheadline).foregroundStyle(Theme.muted)
                        }.padding(20).dataCard().accessibilityIdentifier("auth-load-error")
                    } else if let providers = access.providers, !providers.appleEnabled && !providers.googleEnabled {
                        Text("El acceso no está disponible ahora. Puedes seguir explorando y volver más tarde.")
                            .font(.subheadline).foregroundStyle(Theme.muted).accessibilityIdentifier("auth-unavailable")
                    }
                    Button("Seguir explorando") { dismiss() }
                        .font(.subheadline.weight(.semibold)).frame(minHeight: 44)
                        .accessibilityIdentifier("auth-explore")
                    Text("Tu cuenta comienza con 10.000 US$ virtuales gratuitos. Ningún saldo puede retirarse ni canjearse por dinero real.")
                        .font(.caption).foregroundStyle(Theme.muted)
                }.padding(25)
            }.refreshable { await checkProviders() }.task { await checkProviders() }.onDisappear { access.cancel() }.appCanvas().navigationTitle("Tu cuenta").navigationBarTitleDisplayMode(.inline).toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Cerrar") { dismiss() } } }
        }
    }

    private func checkProviders() async {
        guard !busy else { return }
        await access.load { try await store.auth.availableProviders() }
    }

    private func finishLogin(_ operation: @escaping () async throws -> Void) {
        guard !busy else { return }
        Task {
            busy = true; error = nil; defer { busy = false }
            do {
                try await operation()
                await store.loggedIn()
                dismiss()
            } catch {
                self.error = "No hemos podido iniciar sesión. Vuelve a intentarlo más tarde; mientras tanto puedes explorar la app."
            }
        }
    }
}
struct WalletView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 25) {
                    Pill(text: "Opcional", icon: "leaf")
                    Text("Más espacio\npara practicar.").font(.system(.largeTitle, design: .rounded))
                    Text("Añade saldo virtual si quieres explorar más ideas. Las recargas son compras adicionales al acceso a Empezar Plus.").foregroundStyle(Theme.muted).lineSpacing(4)
                    ConceptLabel(title: "Saldo virtual", concept: .virtualCash).font(.headline)
                    ReadingCard(eyebrow: "Tu saldo disponible", title: Money.text(store.portfolio.cashCents), text: "Dinero ficticio. Las recargas no cuentan como ganancias.", dark: true, concept: .virtualCash)
                    if !store.signedIn {
                        PrimaryButton(title: "Iniciar sesión") { dismiss(); store.showAuth = true }
                    } else if store.packages.isEmpty {
                        Text("Las recargas no están disponibles ahora. Puedes seguir consultando activos y haciendo las lecciones.").font(.subheadline).foregroundStyle(Theme.muted)
                    } else {
                        ForEach(store.packages, id: \.identifier) { package in
                            let cents: Int64 = package.storeProduct.productIdentifier == "ei.cash.10000" ? 1_000_000 : 2_500_000
                            VStack(alignment: .leading, spacing: 15) {
                                Text(Money.text(cents) + " virtuales").font(.title2.weight(.medium))
                                Text("Recarga de compra única").font(.caption).foregroundStyle(Theme.muted)
                                PrimaryButton(title: "Comprar por \(package.storeProduct.localizedPriceString)", icon: "plus", disabled: store.pendingPurchase != nil, loading: store.busy) { Task { await store.purchase(package) } }
                            }.padding(20).dataCard()
                        }
                    }
                    if store.pendingPurchase != nil { Text("Estamos añadiendo tu saldo. Desliza hacia abajo para comprobarlo; no necesitas volver a comprar.").font(.subheadline) }
                    if let notice = store.notice { Text(notice).font(.subheadline) }
                    Text("El precio del botón es dinero real cobrado por Apple. El saldo recibido es ficticio: no se puede retirar, transferir ni canjear. No caduca y se conserva en tu cuenta.").font(.caption).foregroundStyle(Theme.muted).lineSpacing(4)
                }.padding(25)
            }.refreshable {
                guard !store.busy else { return }
                await store.refresh()
                await store.preparePurchases()
            }.appCanvas().navigationTitle("Saldo virtual").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Cerrar") { dismiss() }.disabled(store.busy) } }.interactiveDismissDisabled(store.busy)
        }
    }
}
struct ProfileView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var confirmDelete = false
    @State private var showPaywall = false
    @State private var showAppearance = false
    @AppStorage("app-appearance") private var appearance = AppAppearance.light.rawValue
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack(spacing: 16) {
                        ProfileAvatar()
                        VStack(alignment: .leading, spacing: 6) {
                            Text(store.auth.session?.user.displayName ?? "Tu perfil").font(.title2.weight(.bold))
                            Text("Cuenta virtual · USD").font(.subheadline).foregroundStyle(Theme.muted)
                        }
                    }.padding(.vertical, 8)
                    VStack(alignment: .leading, spacing: 16) {
                        ConceptLabel(title: "Tu cuenta virtual", concept: .virtualCash).font(.headline)
                        Text(Money.text(store.portfolio.cashCents)).font(.largeTitle.weight(.bold)).monospacedDigit()
                        Text("Saldo disponible para seguir practicando.").font(.subheadline).foregroundStyle(Theme.muted)
                    }.padding(20).dataCard()
                    VStack(spacing: 0) {
                        Button { showPaywall = true } label: {
                            SettingsRow(title: "Empezar Plus", subtitle: store.hasSubscription ? "Suscripción activa" : Configuration.freePreviewEnabled ? "Acceso gratuito" : "Ver plan mensual", icon: "sparkles")
                        }
                        Divider()
                        Button { showAppearance = true } label: {
                            SettingsRow(title: "Apariencia", subtitle: (AppAppearance(rawValue: appearance) ?? .light).title, icon: "circle.lefthalf.filled")
                        }.accessibilityIdentifier("appearance-picker")
                        if store.signedIn {
                            Divider()
                            Button { Task { await store.restorePurchases() } } label: {
                                SettingsRow(title: "Restaurar compras", subtitle: "Recupera las compras de tu cuenta de Apple", icon: "arrow.clockwise")
                            }.disabled(store.busy || store.purchasesLoading)
                            Divider()
                            Link(destination: URL(string: "https://apps.apple.com/account/subscriptions")!) {
                                SettingsRow(title: "Gestionar suscripción", subtitle: "Abrir las opciones de Apple", icon: "creditcard")
                            }
                        }
                    }.buttonStyle(.plain).padding(.horizontal, 18).dataCard()
                    if let message = store.purchasesError { Text(message).font(.caption).foregroundStyle(Theme.loss) }
                    VStack(alignment: .leading, spacing: 14) {
                        ConceptLabel(title: "Sobre el simulador", concept: .virtualCash).font(.headline)
                        Text("Aprendes con precios de mercado y dinero ficticio. Cada compra o venta tiene una comisión virtual de 1 US$.").font(.subheadline).foregroundStyle(Theme.muted).lineSpacing(4)
                        Link("Proveedor de datos ↗", destination: URL(string: "https://finance.yahoo.com")!).font(.subheadline)
                    }.padding(20).dataCard()
                    if store.signedIn {
                        Button { Task { await store.signOut(); dismiss() } } label: {
                            SettingsRow(title: "Cerrar sesión", subtitle: "Puedes volver cuando quieras", icon: "rectangle.portrait.and.arrow.right")
                        }.buttonStyle(.plain).padding(.horizontal, 18).dataCard().disabled(store.busy || store.purchasesLoading)
                        Button("Eliminar cuenta", role: .destructive) { confirmDelete = true }.frame(minHeight: 44).disabled(store.busy || store.purchasesLoading)
                    } else {
                        PrimaryButton(title: "Iniciar sesión", icon: "person") { dismiss(); store.showAuth = true }
                    }
                }.padding(20)
            }.appCanvas().navigationTitle("Perfil").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Cerrar") { dismiss() } } }
                .sheet(isPresented: $showPaywall) { PaywallView() }
                .sheet(isPresented: $showAppearance) { AppearanceSheet(appearance: $appearance) }
                .alert("¿Eliminar tu cuenta?", isPresented: $confirmDelete) {
                    Button("Cancelar", role: .cancel) {}
                    Button("Eliminar", role: .destructive) { Task { await store.deleteAccount(); if !store.signedIn { dismiss() } } }
                } message: { Text("Se borrarán la cartera, el progreso y el saldo virtual, incluido el comprado. Eliminar la cuenta no cancela la suscripción: gestiónala antes en Apple. Esta acción no tramita reembolsos y no se puede deshacer.") }
        }
    }
}

private struct SettingsRow: View {
    let title, subtitle, icon: String
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon).font(.title3).foregroundStyle(Theme.accent).frame(width: 34)
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.body.weight(.semibold)).foregroundStyle(Theme.ink)
                Text(subtitle).font(.caption).foregroundStyle(Theme.muted)
            }.frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(Theme.muted)
        }.padding(.vertical, 18).contentShape(Rectangle())
    }
}

private struct AppearanceSheet: View {
    @Binding var appearance: String
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("A tu manera").font(.title.weight(.bold))
                    Text("Elige cómo quieres ver Empezar.").foregroundStyle(Theme.muted)
                    VStack(spacing: 20) {
                        ForEach(AppAppearance.allCases) { option in
                            ChoiceRow(title: option.title, subtitle: subtitle(option), icon: icon(option), selected: appearance == option.rawValue) {
                                appearance = option.rawValue; dismiss()
                            }
                        }
                    }.padding(20).dataCard()
                }.padding(20)
            }.appCanvas().navigationTitle("Apariencia").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Cerrar") { dismiss() } } }
        }.presentationDetents([.medium, .large]).presentationDragIndicator(.visible)
    }
    private func icon(_ option: AppAppearance) -> String {
        switch option { case .light: return "sun.max"; case .dark: return "moon"; case .system: return "iphone" }
    }
    private func subtitle(_ option: AppAppearance) -> String {
        switch option { case .light: return "Fondos claros y texto oscuro"; case .dark: return "Una lectura cómoda con poca luz"; case .system: return "Sigue la apariencia de tu iPhone" }
    }
}

struct ProfileAvatar: View {
    @EnvironmentObject var store: AppStore
    var body: some View {
        Group {
            if let user = store.auth.session?.user {
                AsyncImage(url: user.avatarURL) { image in image.resizable().scaledToFill() } placeholder: {
                    Text(user.initials).font(.headline).foregroundStyle(Theme.accent)
                        .frame(maxWidth: .infinity, maxHeight: .infinity).background(Theme.pale)
                }
            } else {
                Image(systemName: "person.crop.circle").font(.title2).foregroundStyle(Theme.accent)
            }
        }.frame(width: 48, height: 48).background(Theme.pale).clipShape(Circle()).accessibilityHidden(true)
    }
}
