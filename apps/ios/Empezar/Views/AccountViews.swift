import SwiftUI
import RevenueCat

struct AuthView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var code = ""
    @State private var sent = false
    @State private var busy = false
    @State private var error: String?
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 25) {
                    Image(systemName: "leaf").font(.largeTitle).padding(.top, 30)
                    Text(sent ? "Mira tu correo." : "Tu aprendizaje,\nsiempre contigo.").font(.system(.largeTitle, design: .serif))
                    Text(sent ? "Introduce el código que hemos enviado a \(email)." : "Guarda tu cartera y tu progreso con un código por correo. Sin contraseñas.").foregroundStyle(Theme.muted).lineSpacing(4)
                    if sent {
                        TextField("Código del correo", text: $code).textContentType(.oneTimeCode).keyboardType(.numberPad).padding(20).background(Theme.surface, in: RoundedRectangle(cornerRadius: 18))
                    } else {
                        TextField("tu@email.com", text: $email).textContentType(.emailAddress).keyboardType(.emailAddress).textInputAutocapitalization(.never).autocorrectionDisabled().padding(20).background(Theme.surface, in: RoundedRectangle(cornerRadius: 18))
                    }
                    if let error { Text(error).font(.subheadline).foregroundStyle(Theme.loss) }
                    PrimaryButton(title: sent ? "Verificar y continuar" : "Recibir un código", disabled: sent ? code.count < 6 : !email.contains("@"), loading: busy) {
                        Task {
                            busy = true; error = nil; defer { busy = false }
                            do {
                                let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                                if sent { try await store.auth.verify(email: cleanEmail, code: code); await store.loggedIn(); dismiss() }
                                else { try await store.auth.sendCode(email: cleanEmail); email = cleanEmail; sent = true }
                            } catch { self.error = error.localizedDescription }
                        }
                    }
                    if sent { Button("Cambiar correo o reenviar") { sent = false; code = "" }.frame(minHeight: 44) }
                    Text("Tu cuenta comienza con 10.000 $ virtuales gratuitos. Ningún saldo se puede retirar o canjear por dinero real.").font(.caption).foregroundStyle(Theme.muted)
                }.padding(25)
            }.appCanvas().navigationTitle("Tu cuenta").navigationBarTitleDisplayMode(.inline).toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Cerrar") { dismiss() } } }
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
                    Text("Más espacio\npara practicar.").font(.system(.largeTitle, design: .serif))
                    Text("Añade saldo virtual si quieres explorar más ideas. Todas las lecciones siguen siendo gratuitas.").foregroundStyle(Theme.muted).lineSpacing(4)
                    ReadingCard(eyebrow: "Tu saldo disponible", title: Money.text(store.portfolio.cashCents), text: "Dinero ficticio. Las recargas no cuentan como ganancias.", dark: true)
                    if !store.signedIn {
                        PrimaryButton(title: "Iniciar sesión") { dismiss(); store.showAuth = true }
                    } else if store.packages.isEmpty {
                        Text("Las recargas no están disponibles ahora. Tu saldo inicial es suficiente para empezar.").font(.subheadline).foregroundStyle(Theme.muted)
                    } else {
                        ForEach(store.packages, id: \.identifier) { package in
                            let cents: Int64 = package.storeProduct.productIdentifier == "ei.cash.10000" ? 1_000_000 : 2_500_000
                            VStack(alignment: .leading, spacing: 15) {
                                Text(Money.text(cents) + " virtuales").font(.title2.weight(.medium))
                                Text("Compra única · sin suscripción").font(.caption).foregroundStyle(Theme.muted)
                                PrimaryButton(title: "Comprar por \(package.storeProduct.localizedPriceString)", icon: "plus", disabled: store.pendingPurchase != nil, loading: store.busy) { Task { await store.purchase(package) } }
                            }.padding(21).background(Theme.surface, in: RoundedRectangle(cornerRadius: 24))
                        }
                    }
                    if store.pendingPurchase != nil { Text("Compra recibida. El saldo aparecerá al confirmarse en el servidor.").font(.subheadline); Button("Comprobar saldo") { Task { await store.refresh() } }.frame(minHeight: 44) }
                    if let notice = store.notice { Text(notice).font(.subheadline) }
                    Text("El precio del botón es dinero real cobrado por Apple. El saldo recibido es ficticio: no se puede retirar, transferir ni canjear. No caduca y se conserva en tu cuenta.").font(.caption).foregroundStyle(Theme.muted).lineSpacing(4)
                }.padding(25)
            }.appCanvas().navigationTitle("Saldo virtual").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Cerrar") { dismiss() }.disabled(store.busy) } }.interactiveDismissDisabled(store.busy)
        }
    }
}
struct ProfileView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var confirmDelete = false
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Aprender es la inversión.").font(.system(.title2, design: .serif)).padding(.vertical, 12)
                    Text("Cuenta en USD · 10.000 $ virtuales de bienvenida").font(.subheadline)
                }
                Section("Tu cuenta") {
                    if store.signedIn {
                        Button("Actualizar cartera") { Task { await store.refresh() } }
                        Button("Cerrar sesión") { Task { await store.signOut(); dismiss() } }
                        Button("Eliminar cuenta", role: .destructive) { confirmDelete = true }
                    } else { Button("Iniciar sesión") { dismiss(); store.showAuth = true } }
                }
                Section("Acerca del simulador") {
                    Text("Precios reales de Twelve Data. Las órdenes y el dinero son simulados. No ofrecemos intermediación ni recomendaciones de inversión.").font(.subheadline)
                    Text("Esta V0 ejecuta unidades enteras con una comisión ficticia de 1 $. Aún no contabiliza dividendos, splits ni intereses. Los ETF de bonos no son bonos individuales.").font(.subheadline)
                    Link("Proveedor de datos ↗", destination: URL(string: "https://twelvedata.com")!)
                }
            }.scrollContentBackground(.hidden).appCanvas().navigationTitle("Tu cuenta").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Cerrar") { dismiss() } } }
                .alert("¿Eliminar tu cuenta?", isPresented: $confirmDelete) {
                    Button("Cancelar", role: .cancel) {}
                    Button("Eliminar", role: .destructive) { Task { await store.deleteAccount(); if !store.signedIn { dismiss() } } }
                } message: { Text("Se borrarán la cartera, el progreso y el saldo virtual, incluido el comprado. Esta acción no tramita reembolsos de Apple y no se puede deshacer.") }
        }
    }
}
