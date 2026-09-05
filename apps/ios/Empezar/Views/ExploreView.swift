import SwiftUI

struct ExploreView: View {
    @EnvironmentObject var store: AppStore
    @State private var search = ""
    @State private var filter = "Todo"
    let filters = ["Todo", "Acciones", "ETF", "Bonos"]
    var filtered: [Instrument] {
        Content.instruments.filter { a in
            (search.isEmpty || a.name.localizedCaseInsensitiveContains(search) || a.symbol.localizedCaseInsensitiveContains(search)) &&
            (filter == "Todo" || (filter == "Acciones" && a.kind == "stock") || (filter == "ETF" && a.kind != "stock") || (filter == "Bonos" && a.kind == "bond_etf"))
        }
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 25) {
                Text("Encuentra tu\nprimera idea.").font(.system(.largeTitle, design: .serif)).padding(.top, 12)
                Text("Empresas y fondos reales. Entiende qué hay detrás de cada inversión.").font(.subheadline).foregroundStyle(Theme.muted).lineSpacing(4)
                HStack { Image(systemName: "magnifyingglass"); TextField("Nombre o símbolo", text: $search).autocorrectionDisabled() }.padding(16).background(Theme.surface, in: RoundedRectangle(cornerRadius: 17))
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) { filterButtons }
                    VStack(alignment: .leading, spacing: 8) { filterButtons }
                }
                VStack(spacing: 0) {
                    ForEach(filtered) { a in
                        NavigationLink { InstrumentView(instrument: a) } label: { AssetRow(instrument: a, quote: store.portfolio.quote(a.symbol)) }.buttonStyle(.plain)
                        Divider().overlay(Theme.line)
                    }
                    if filtered.isEmpty { ContentUnavailableView.search(text: search) }
                }
                if store.marketLoading { ProgressView("Actualizando precios…").font(.caption) }
                ReadingCard(eyebrow: "Una buena pregunta", title: "¿Invertirías en esto si la bolsa cerrase cinco años?", text: "Entender lo que compras te ayuda a decidir con más perspectiva.")
                VStack(alignment: .leading, spacing: 8) {
                    Link("Datos de mercado por Twelve Data ↗", destination: URL(string: "https://twelvedata.com")!).font(.caption)
                    Text("Consulta la hora y el tipo de dato en cada ficha. La variación es respecto al cierre anterior. No hay recomendaciones de compra.").font(.caption).foregroundStyle(Theme.muted)
                }
            }.padding(24)
        }.appCanvas().navigationTitle("Explorar").navigationBarTitleDisplayMode(.inline).refreshable { await store.refresh() }
    }
    @ViewBuilder var filterButtons: some View {
        ForEach(filters, id: \.self) { item in
            Button { filter = item } label: { Text(item).font(.subheadline).padding(.horizontal, 16).padding(.vertical, 12).foregroundStyle(filter == item ? Theme.lime : Theme.ink).background(filter == item ? Theme.forest : Theme.pale, in: Capsule()) }.buttonStyle(.plain).accessibilityAddTraits(filter == item ? .isSelected : [])
        }
    }
}
struct InstrumentView: View {
    let instrument: Instrument
    @EnvironmentObject var store: AppStore
    @State private var tradeSide: String?
    @State private var fundamentals: Fundamentals?
    @State private var refreshing = false
    var quote: Quote? { store.portfolio.quote(instrument.symbol) }
    var position: Position? { store.portfolio.positions.first { $0.symbol == instrument.symbol } }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 25) {
                HStack { AssetMark(instrument: instrument, large: true); Spacer(); Pill(text: instrument.category, icon: "square.stack") }
                VStack(alignment: .leading, spacing: 10) {
                    Text(instrument.name).font(.system(.largeTitle, design: .serif))
                    Text("\(instrument.symbol) · USD").font(.caption).foregroundStyle(Theme.muted)
                    Text(quote.map { Money.text($0.priceCents) } ?? "—").font(.system(size: 40, weight: .regular, design: .serif)).monospacedDigit()
                    if let q = quote {
                        Text((q.changePercent > 0 ? "+" : "") + q.changePercent.formatted(.number.precision(.fractionLength(2))) + " % desde el cierre anterior").font(.subheadline).foregroundStyle(q.changePercent < 0 ? Theme.loss : Theme.ink)
                        TimelineView(.periodic(from: .now, by: 1)) { _ in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(q.status).font(.caption.weight(.medium))
                                if let date = ISO.date(q.asOf) { Text("\(date.formatted(date: .abbreviated, time: .shortened)) · Twelve Data").font(.caption).foregroundStyle(Theme.muted) }
                            }
                        }
                    } else { Text("Cotización no disponible. No se puede operar sin un precio real.").font(.subheadline).foregroundStyle(Theme.muted) }
                    Button { Task { await updateQuote() } } label: { Label(refreshing ? "Actualizando…" : "Actualizar precio", systemImage: "arrow.clockwise").font(.subheadline).padding(.vertical, 10) }.disabled(refreshing || !store.signedIn)
                }
                ReadingCard(eyebrow: "El negocio, en una frase", title: instrument.summary, text: instrument.question, dark: true)
                if instrument.kind == "stock" {
                    SectionHeading(title: "Mira los fundamentales")
                    HStack(spacing: 14) {
                        metric("PER · últimos 12 meses", value: fundamentals?.pe.map { $0 > 0 ? $0.formatted(.number.precision(.fractionLength(1))) + "×" : "No aplicable" } ?? "No disponible")
                        metric("Beneficio por acción", value: fundamentals?.eps.map { Money.text(Int64(($0 * 100).rounded())) } ?? "No disponible")
                    }
                    if let period = fundamentals?.period { Text("Último trimestre reportado: \(period)").font(.caption).foregroundStyle(Theme.muted) }
                    NavigationLink { ValuationView(initialEPS: fundamentals?.eps) } label: { Label("Explorar una valoración", systemImage: "slider.horizontal.3").font(.subheadline).padding(.vertical, 6) }
                }
                ReadingCard(eyebrow: "Lo que puede salir mal", title: "Conoce el riesgo.", text: instrument.risk)
                ReadingCard(eyebrow: "Llévate esta idea", title: instrument.question, text: instrument.learn)
                if let p = position {
                    SectionHeading(title: "En tu cartera", detail: "\(p.units) unidades")
                    Text("Coste de adquisición: \(Money.text(p.costCents)), comisiones incluidas.").font(.subheadline).foregroundStyle(Theme.muted)
                }
                Link("Información del emisor ↗", destination: URL(string: instrument.source)!).font(.subheadline)
                Text("Ejecución simulada al último precio recibido, con 1 $ de comisión. Sin spread ni profundidad de mercado. No incluye dividendos, splits ni intereses en esta V0.").font(.caption).foregroundStyle(Theme.muted)
            }.padding(24)
        }.appCanvas().navigationTitle(instrument.symbol).navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                HStack(spacing: 12) {
                    if position != nil { Button("Vender") { tradeSide = "sell" }.font(.body.weight(.semibold)).padding(20).background(Theme.pale, in: RoundedRectangle(cornerRadius: 20)) }
                    PrimaryButton(title: store.signedIn ? "Revisar compra" : "Iniciar sesión", icon: "arrow.right") { if store.signedIn { tradeSide = "buy" } else { store.showAuth = true } }
                }.padding(.horizontal, 20).padding(.vertical, 12).background(Theme.paper)
            }
            .sheet(isPresented: Binding(get: { tradeSide != nil }, set: { if !$0 { tradeSide = nil } })) { TradeView(instrument: instrument, side: tradeSide ?? "buy") }
            .task {
                guard store.signedIn else { return }
                await updateQuote()
                if instrument.kind == "stock" { fundamentals = try? await store.api.request("fundamentals?symbol=\(instrument.symbol)") }
            }
    }
    func updateQuote() async {
        refreshing = true; defer { refreshing = false }
        do { _ = try await store.refreshQuote(instrument.symbol) } catch { store.error = error.localizedDescription }
    }
    func metric(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 12) { Text(title).font(.caption).foregroundStyle(Theme.muted); Text(value).font(.body.weight(.medium)) }.frame(maxWidth: .infinity, alignment: .leading).padding(16).background(Theme.surface, in: RoundedRectangle(cornerRadius: 18))
    }
}
