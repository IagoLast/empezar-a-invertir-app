import SwiftUI

struct ExploreView: View {
    @EnvironmentObject var store: AppStore
    @State private var search = ""
    @State private var filter = "Todo"
    private let filters = ["Todo", "Acciones", "ETF", "Bonos"]
    var filtered: [Instrument] {
        Content.instruments.filter { asset in
            (search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || asset.name.localizedCaseInsensitiveContains(search.trimmingCharacters(in: .whitespacesAndNewlines)) || asset.symbol.localizedCaseInsensitiveContains(search.trimmingCharacters(in: .whitespacesAndNewlines))) &&
            (filter == "Todo" || (filter == "Acciones" && asset.kind == "stock") || (filter == "ETF" && asset.kind != "stock") || (filter == "Bonos" && asset.kind == "bond_etf"))
        }
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Mercados").font(.largeTitle.weight(.bold))
                        Text("Encuentra tu próxima inversión").font(.subheadline).foregroundStyle(Theme.muted)
                    }
                    Spacer(minLength: 0)
                }
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass").foregroundStyle(Theme.accent)
                    TextField("Buscar empresa o símbolo", text: $search).font(.body).autocorrectionDisabled().textInputAutocapitalization(.never)
                        .accessibilityIdentifier("asset-search")
                    if !search.isEmpty {
                        Button { search = "" } label: { Image(systemName: "xmark.circle.fill").frame(width: 44, height: 44) }.accessibilityLabel("Borrar búsqueda")
                    }
                }.padding(.horizontal, 16).frame(minHeight: 58).glassControl(radius: 20)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(filters, id: \.self) { item in
                            Button { filter = item } label: {
                                Text(item).font(.subheadline.weight(.semibold)).padding(.horizontal, 20).padding(.vertical, 13)
                                    .foregroundStyle(filter == item ? .white : Theme.muted)
                                    .background(filter == item ? Theme.button : Theme.surface, in: Capsule())
                                    .overlay { Capsule().strokeBorder(filter == item ? .clear : Theme.line) }
                            }.buttonStyle(.plain).accessibilityAddTraits(filter == item ? .isSelected : [])
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 16) {
                    SectionHeading(title: search.isEmpty ? "Activos disponibles" : "Resultados", detail: "Precio · variación diaria")
                    VStack(spacing: 0) {
                        ForEach(filtered) { asset in
                            NavigationLink { InstrumentView(instrument: asset) } label: {
                                AssetRow(instrument: asset, quote: store.portfolio.quote(asset.symbol))
                            }.buttonStyle(.plain)
                            if asset.id != filtered.last?.id { Divider().overlay(Theme.line) }
                        }
                        if filtered.isEmpty {
                            ContentUnavailableView {
                                Label("Sin resultados", systemImage: "magnifyingglass")
                            } description: {
                                Text("Prueba otro nombre o símbolo, o cambia el filtro. La búsqueda incluye los activos disponibles en este simulador.")
                            } actions: {
                                Button("Ver todos los activos") { search = ""; filter = "Todo" }
                            }
                        }
                    }.padding(.horizontal, 16).dataCard()
                }
                if store.marketLoading { ProgressView("Actualizando precios…").font(.subheadline).frame(maxWidth: .infinity) }
                if !store.signedIn {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "person.badge.key").foregroundStyle(Theme.accent)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Activa tu cartera virtual").font(.headline)
                            Text("Inicia sesión para consultar precios y practicar comprando y vendiendo.").font(.subheadline).foregroundStyle(Theme.muted)
                            Button("Iniciar sesión") { store.showAuth = true }.font(.subheadline.weight(.semibold)).frame(minHeight: 44)
                        }
                    }.padding(20).dataCard()
                }
                VStack(alignment: .leading, spacing: 8) {
                    Link("Datos de mercado por Twelve Data ↗", destination: URL(string: "https://twelvedata.com")!).font(.caption)
                    Text("Activos en USD. La variación compara el precio con el cierre anterior. Consulta la hora y disponibilidad del dato en cada ficha.").font(.caption).foregroundStyle(Theme.muted)
                }
            }.padding(20).padding(.top, 12)
        }.appCanvas().toolbar(.hidden, for: .navigationBar).scrollDismissesKeyboard(.interactively)
            .refreshable { await store.refresh() }
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
            VStack(alignment: .leading, spacing: 24) {
                HStack(spacing: 16) {
                    AssetMark(instrument: instrument, large: true)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(instrument.name).font(.title2.weight(.bold))
                        Text("\(instrument.symbol) · \(instrument.category) · USD").font(.subheadline).foregroundStyle(Theme.muted)
                    }
                }
                quoteCard
                if let position { positionCard(position) }
                VStack(alignment: .leading, spacing: 14) {
                    SectionHeading(title: "Sobre este activo")
                    Text(instrument.summary).font(.body).lineSpacing(4)
                    Link("Información del emisor ↗", destination: URL(string: instrument.source)!).font(.subheadline)
                }.padding(22).dataCard()
                if instrument.kind == "stock" {
                    VStack(alignment: .leading, spacing: 16) {
                        SectionHeading(title: "Fundamentales")
                        ViewThatFits(in: .horizontal) {
                            HStack(alignment: .top, spacing: 18) { fundamentalMetrics }
                            VStack(alignment: .leading, spacing: 18) { fundamentalMetrics }
                        }
                        if let period = fundamentals?.period { Text("Último trimestre reportado: \(period)").font(.caption).foregroundStyle(Theme.muted) }
                        NavigationLink { ValuationView(initialEPS: fundamentals?.eps) } label: {
                            Label("Explorar una valoración", systemImage: "slider.horizontal.3").font(.subheadline.weight(.semibold)).padding(.vertical, 8)
                        }
                    }.padding(22).dataCard()
                }
                ReadingCard(eyebrow: "Riesgos", title: "Antes de invertir", text: instrument.risk)
                ReadingCard(eyebrow: "Para entenderlo mejor", title: instrument.question, text: instrument.learn, dark: true)
                Text("Operaciones simuladas al último precio recibido, con 1 $ de comisión virtual. Sin spread, dividendos, splits ni intereses.")
                    .font(.caption).foregroundStyle(Theme.muted).lineSpacing(3)
            }.padding(20)
        }.appCanvas().navigationTitle(instrument.symbol).navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) { tradeControls }
            .sheet(isPresented: Binding(get: { tradeSide != nil }, set: { if !$0 { tradeSide = nil } })) {
                TradeView(instrument: instrument, side: tradeSide ?? "buy")
            }
            .task {
                guard store.signedIn else { return }
                await updateQuote()
                if instrument.kind == "stock" { fundamentals = try? await store.api.request("fundamentals?symbol=\(instrument.symbol)") }
            }
    }
    private var quoteCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack { Text("Precio por unidad").font(.subheadline).foregroundStyle(Theme.muted); Spacer(); Pill(text: "USD", icon: "dollarsign") }
            Text(quote.map { Money.text($0.priceCents) } ?? "—")
                .font(.system(.largeTitle, design: .rounded).weight(.bold)).monospacedDigit().minimumScaleFactor(0.6).lineLimit(1)
            if let quote {
                HStack { ChangeLabel(percent: quote.changePercent); Text("desde el cierre anterior").font(.caption).foregroundStyle(Theme.muted) }
                Divider().overlay(Theme.line)
                TimelineView(.periodic(from: .now, by: 1)) { _ in
                    Label(quote.status, systemImage: "clock").font(.caption).foregroundStyle(Theme.muted)
                }
                if let date = ISO.date(quote.asOf) {
                    Text("\(date.formatted(date: .abbreviated, time: .shortened)) · Twelve Data").font(.caption).foregroundStyle(Theme.muted)
                }
            } else {
                Text("El precio aparecerá cuando haya una cotización disponible.").font(.subheadline).foregroundStyle(Theme.muted)
            }
            Button { Task { await updateQuote() } } label: {
                Label(refreshing ? "Actualizando…" : "Actualizar precio", systemImage: "arrow.clockwise").font(.subheadline.weight(.semibold)).frame(minHeight: 44)
            }.disabled(refreshing || !store.signedIn)
        }.padding(22).dataCard()
    }
    private func positionCard(_ position: Position) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeading(title: "Tu posición", detail: "\(position.units) unidades")
            detailLine("Precio medio de compra", value: Money.text(position.averageCostCents))
            detailLine("Coste total", value: Money.text(position.costCents))
            if let quote {
                detailLine("Valor actual", value: Money.text(position.marketValueCents(at: quote)))
                let profit = position.profitCents(at: quote)
                HStack {
                    Text("Resultado").font(.subheadline).foregroundStyle(Theme.muted)
                    Spacer()
                    Text(Money.signed(profit)).font(.headline).monospacedDigit().foregroundStyle(profit < 0 ? Theme.loss : Theme.gain)
                }
            }
            Text("El coste incluye las comisiones de compra.").font(.caption).foregroundStyle(Theme.muted)
        }.padding(22).dataCard()
    }
    private var tradeControls: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) { tradeButtons }
            VStack(spacing: 12) { tradeButtons }
        }.padding(.horizontal, 20).padding(.vertical, 12).background(.bar)
    }
    @ViewBuilder private var tradeButtons: some View {
        if position != nil {
            Button { tradeSide = "sell" } label: {
                Text("Vender").font(.body.weight(.semibold)).frame(maxWidth: .infinity).padding(18).glassControl(radius: 20)
            }.buttonStyle(.plain)
        }
        PrimaryButton(title: store.signedIn ? "Comprar" : "Iniciar sesión", icon: store.signedIn ? "plus" : "person") {
            if store.signedIn { tradeSide = "buy" } else { store.showAuth = true }
        }
    }
    @ViewBuilder private var fundamentalMetrics: some View {
        metric("PER · últimos 12 meses", value: fundamentals?.pe.map { $0 > 0 ? $0.formatted(.number.precision(.fractionLength(1))) + "×" : "No aplicable" } ?? "No disponible")
        metric("Beneficio por acción", value: fundamentals?.eps.map { Money.text(Int64(($0 * 100).rounded())) } ?? "No disponible")
    }
    private func detailLine(_ title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).foregroundStyle(Theme.muted); Spacer(); Text(value).fontWeight(.semibold).monospacedDigit()
        }.font(.subheadline)
    }
    private func metric(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.caption).foregroundStyle(Theme.muted)
            Text(value).font(.headline)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
    private func updateQuote() async {
        refreshing = true; defer { refreshing = false }
        do { _ = try await store.refreshQuote(instrument.symbol) } catch { store.error = error.localizedDescription }
    }
}
