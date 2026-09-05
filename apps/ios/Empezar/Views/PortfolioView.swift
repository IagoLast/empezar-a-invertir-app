import SwiftUI

struct PortfolioView: View {
    @EnvironmentObject var store: AppStore
    var explore: () -> Void
    @State private var profile = false
    @State private var wallet = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                HStack {
                    Text("empezar.").font(.system(.title2, design: .serif))
                    Spacer()
                    Pill(text: "Simulador", icon: "leaf")
                    Button { profile = true } label: { Image(systemName: "person.crop.circle").font(.title2).frame(width: 44, height: 44) }.accessibilityLabel("Tu cuenta")
                }
                VStack(alignment: .leading, spacing: 10) {
                    Text("Tu dinero, aprendiendo.").font(.subheadline).foregroundStyle(Theme.muted)
                    Text(store.portfolio.equityCents.map(Money.text) ?? "—").font(.system(size: 43, weight: .regular, design: .serif)).minimumScaleFactor(0.65).lineLimit(1).contentTransition(.numericText())
                    HStack(spacing: 6) {
                        if let profit = store.portfolio.profitCents {
                            Image(systemName: profit < 0 ? "arrow.down.right" : "arrow.up.right")
                            Text(Money.signed(profit)).monospacedDigit()
                            Text("de resultado total").foregroundStyle(Theme.muted)
                        } else { Text("Faltan precios para valorar la cartera").foregroundStyle(Theme.muted) }
                    }.font(.caption).foregroundStyle((store.portfolio.profitCents ?? 0) < 0 ? Theme.loss : Theme.ink)
                    if store.portfolio.hasStaleValuation { Text("Valoración con los últimos datos disponibles").font(.caption).foregroundStyle(Theme.muted) }
                    if !store.signedIn { Text("Vista previa · inicia sesión para operar").font(.caption).foregroundStyle(Theme.muted) }
                }.padding(.top, 8)
                HStack {
                    VStack(alignment: .leading, spacing: 7) {
                        Text("Disponible para invertir").font(.caption).foregroundStyle(Theme.muted)
                        Text(Money.text(store.portfolio.cashCents)).font(.title3.weight(.medium)).monospacedDigit()
                    }
                    Spacer()
                    Button { wallet = true } label: { Image(systemName: "plus").font(.title3).frame(width: 48, height: 48).background(Theme.surface, in: Circle()) }.accessibilityLabel("Añadir saldo virtual")
                }.padding(20).background(Theme.pale, in: RoundedRectangle(cornerRadius: 23))
                if let notice = store.notice {
                    HStack(alignment: .top) {
                        Text(notice).font(.subheadline)
                        Spacer()
                        Button { store.notice = nil } label: { Image(systemName: "xmark").frame(width: 44, height: 44) }.accessibilityLabel("Cerrar aviso")
                    }.padding(16).background(Theme.surface, in: RoundedRectangle(cornerRadius: 20))
                }
                if store.pendingTrade != nil {
                    PrimaryButton(title: "Comprobar operación pendiente", icon: "arrow.clockwise", loading: store.busy) { Task { await store.retryTrade() } }
                }
                if store.pendingPurchase != nil {
                    Button("Compra pendiente · comprobar saldo") { Task { await store.refresh() } }.font(.subheadline)
                }
                if store.portfolio.positions.isEmpty {
                    VStack(alignment: .leading, spacing: 18) {
                        HStack { Text("TU PRIMER PASO").font(.caption).tracking(1.5); Spacer(); Image(systemName: "arrow.up.right") }
                        Text("Antes de comprar,\nentiende el negocio.").font(.system(.title, design: .serif))
                        Text("Encuentra una empresa que conozcas. Descubre cómo gana dinero y qué riesgos tiene.").font(.subheadline).lineSpacing(4).opacity(0.85)
                        Button(action: explore) { HStack { Text("Explorar empresas").font(.body.weight(.medium)); Spacer(); Image(systemName: "arrow.right") }.padding(.top, 8) }
                    }.padding(24).foregroundStyle(Theme.lime).background(Theme.forest, in: RoundedRectangle(cornerRadius: 28))
                } else {
                    SectionHeading(title: "Tus inversiones", detail: "Valor actual")
                    VStack(spacing: 0) {
                        ForEach(store.portfolio.positions) { position in
                            if let instrument = Content.instruments.first(where: { $0.symbol == position.symbol }) {
                                NavigationLink { InstrumentView(instrument: instrument) } label: { AssetRow(instrument: instrument, quote: store.portfolio.quote(instrument.symbol), units: position.units) }.buttonStyle(.plain)
                                Divider().overlay(Theme.line)
                            }
                        }
                    }
                    AllocationView()
                }
                SectionHeading(title: "Una idea para hoy", detail: "3 min")
                NavigationLink { LessonView(lesson: Content.lessons[0]) } label: {
                    HStack(spacing: 16) {
                        Image(systemName: "book.closed").font(.title2).frame(width: 52, height: 62).background(Theme.pale, in: RoundedRectangle(cornerRadius: 14))
                        VStack(alignment: .leading, spacing: 5) { Text("Una acción es un trocito\nde una empresa.").font(.body.weight(.medium)); Text("Empieza por lo esencial").font(.caption).foregroundStyle(Theme.muted) }
                        Spacer(); Image(systemName: "chevron.right").font(.caption)
                    }
                }.buttonStyle(.plain)
                if !store.portfolio.orders.isEmpty { OrderHistory() }
                Text("Saldo y operaciones virtuales · Cuenta en USD").font(.caption).foregroundStyle(Theme.muted).frame(maxWidth: .infinity).padding(.top, 6)
            }.padding(.horizontal, 24).padding(.bottom, 24)
        }.appCanvas().toolbar(.hidden, for: .navigationBar)
            .refreshable { await store.refresh() }
            .sheet(isPresented: $profile) { ProfileView() }
            .sheet(isPresented: $wallet) { WalletView() }
    }
}
struct AllocationView: View {
    @EnvironmentObject var store: AppStore
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeading(title: "Cómo se reparte")
            ForEach(store.portfolio.positions) { p in
                if let q = store.portfolio.quote(p.symbol), let total = store.portfolio.equityCents, total > 0 {
                    let weight = Double(q.priceCents * Int64(p.units)) / Double(total)
                    VStack(spacing: 7) {
                        HStack { Text(p.symbol); Spacer(); Text(weight.formatted(.percent.precision(.fractionLength(1)))) }.font(.caption)
                        GeometryReader { geo in
                            Capsule().fill(Theme.pale).overlay(alignment: .leading) { Capsule().fill(Theme.ink).frame(width: geo.size.width * min(max(weight,0),1)) }
                        }.frame(height: 5).accessibilityHidden(true)
                    }
                }
            }
            Text("El efectivo también forma parte de tu cartera.").font(.caption).foregroundStyle(Theme.muted)
        }
    }
}
struct OrderHistory: View {
    @EnvironmentObject var store: AppStore
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeading(title: "Últimos movimientos")
            ForEach(store.portfolio.orders.prefix(10)) { o in
                HStack {
                    Image(systemName: o.side == "buy" ? "arrow.down.left" : "arrow.up.right").frame(width: 38, height: 38).background(Theme.pale, in: Circle())
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(o.side == "buy" ? "Compra" : "Venta") de \(o.symbol)").font(.subheadline)
                        Text("\(o.units) unidades · comisión \(Money.text(o.feeCents))").font(.caption).foregroundStyle(Theme.muted)
                    }
                    Spacer(); Text(Money.text(o.priceCents * Int64(o.units))).font(.subheadline).monospacedDigit()
                }
            }
        }
    }
}
