import SwiftUI

enum MarketRegion: String, CaseIterable {
    case all, spain, unitedStates, europe, other
    var title: String {
        switch self {
        case .all: return "Todos los mercados"
        case .spain: return "España"
        case .unitedStates: return "Estados Unidos"
        case .europe: return "Otros mercados europeos"
        case .other: return "Otros mercados"
        }
    }
    func includes(_ symbol: String) -> Bool {
        let suffix = symbol.split(separator: ".").dropFirst().last.map(String.init)
        let european = ["L", "PA", "DE", "F", "AS", "MI", "SW", "ST", "HE", "CO", "OL", "BR", "LS", "VI", "IR"]
        switch self {
        case .all: return true
        case .spain: return suffix == "MC"
        case .unitedStates: return suffix == nil
        case .europe: return suffix.map { european.contains($0) } ?? false
        case .other: return suffix != nil && suffix != "MC" && !(suffix.map { european.contains($0) } ?? false)
        }
    }
}

struct ExploreView: View {
    @EnvironmentObject var store: AppStore
    @State private var search = ""
    @FocusState private var searchFocused: Bool
    @State private var searchResults: [MarketSearchResult] = []
    @State private var searching = false
    @State private var searchError: String?
    @State private var searchNotice: String?
    private var results: [MarketSearchResult] { searchResults }

    private func resultLink(_ asset: MarketSearchResult) -> some View {
        NavigationLink { MarketSearchDetail(asset: asset) } label: {
            MarketSearchRow(asset: asset, quote: store.portfolio.quote(asset.symbol))
        }.buttonStyle(.plain)
            .accessibilityIdentifier("search-result-\(asset.symbol)")
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if searching { ProgressView("Buscando en los mercados…").font(.subheadline) }
                if let searchNotice { Text(searchNotice).font(.subheadline).foregroundStyle(Theme.muted) }
                if let searchError {
                    Text(searchError).font(.subheadline).foregroundStyle(Theme.loss)
                    Text("Desliza hacia abajo para volver a buscar.").font(.caption).foregroundStyle(Theme.muted)
                }
                if !results.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Resultados").font(.headline)
                    LazyVStack(spacing: 0) {
                        ForEach(results) { asset in
                            resultLink(asset)
                            if asset.symbol != results.last?.symbol { Divider() }
                        }
                    }.padding(.horizontal, 16).dataCard()
                }
                }
                if search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    ContentUnavailableView("Busca tu próxima inversión", systemImage: "magnifyingglass", description: Text("Escribe el nombre de una empresa o su símbolo para consultar acciones y fondos."))
                } else if results.isEmpty && !searching && searchError == nil {
                    ContentUnavailableView {
                        Label("Sin resultados", systemImage: "magnifyingglass")
                    } description: {
                        Text("Prueba con el nombre de la empresa o su símbolo.")
                    } actions: {
                        Button("Nueva búsqueda") { search = "" }
                    }
                }
                if store.marketLoading { ProgressView("Actualizando precios…").font(.subheadline).frame(maxWidth: .infinity) }
                if !store.signedIn {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "person.badge.key").foregroundStyle(Theme.accent)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Activa tu cartera virtual").font(.headline)
                            Text("Inicia sesión para guardar tu cartera y practicar comprando y vendiendo.").font(.subheadline).foregroundStyle(Theme.muted)
                            Button("Iniciar sesión") { store.showAuth = true }.font(.subheadline.weight(.semibold)).frame(minHeight: 44)
                        }
                    }.padding(20).dataCard()
                }
                Text("Dinero virtual · Precios de mercado que pueden tener retraso.")
                    .font(.caption).foregroundStyle(Theme.muted)

            }.padding(20).padding(.top, 12)
        }.appCanvas().scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .top, spacing: 0) { searchHeader }
            .toolbar(.hidden, for: .navigationBar)
            .refreshable {
                await store.refresh()
                if !search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { await searchMarkets() }
            }
            .task(id: search) { await searchMarkets() }
    }
    private var searchHeader: some View {
        VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Invertir").font(.largeTitle.weight(.bold))
                        Text("Busca una acción y practica tu primera compra").font(.subheadline).foregroundStyle(Theme.muted)
                    }
                    Spacer(minLength: 0)
                }
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass").foregroundStyle(Theme.accent)
                    TextField("Buscar empresa o símbolo", text: $search).textFieldStyle(.plain).font(.body).autocorrectionDisabled().textInputAutocapitalization(.never)
                        .accessibilityIdentifier("asset-search")
                        .focused($searchFocused).submitLabel(.search)
                        .onSubmit { searchFocused = false }
                    Button { search = "" } label: { Image(systemName: "xmark.circle.fill").frame(width: 44, height: 44) }
                        .accessibilityLabel("Borrar búsqueda").opacity(search.isEmpty ? 0 : 1)
                        .disabled(search.isEmpty).accessibilityHidden(search.isEmpty)
                }.padding(.horizontal, 18).frame(maxWidth: .infinity, minHeight: 54).background(Theme.surface, in: Capsule())
        }.frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 16)
            .background(Theme.paper).foregroundStyle(Theme.ink)
    }
    private func searchMarkets() async {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        searchResults = []; searchError = nil; searchNotice = nil
        guard !query.isEmpty else { searching = false; return }
        searching = true
        do {
            try await Task.sleep(for: .milliseconds(800))
            let encoded = query.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? query
            let response: MarketSearchResponse = try await store.api.request("search?q=\(encoded)", authenticated: false)
            try Task.checkCancellation()
            guard query == search.trimmingCharacters(in: .whitespacesAndNewlines) else { return }
            searchResults = response.results; searchNotice = response.notice; searching = false
        } catch {
            guard !Task.isCancelled, query == search.trimmingCharacters(in: .whitespacesAndNewlines) else { return }
            searchError = "No hemos podido buscar. Comprueba tu conexión y vuelve a intentarlo."; searching = false
        }
    }
}

struct InstrumentView: View {
    let instrument: Instrument
    @EnvironmentObject var store: AppStore
    @Environment(\.scenePhase) private var scenePhase
    @State private var tradeSide: String?
    @State private var refreshing = false
    @State private var historyReload = 0
    @State private var quoteIssue: String?
    @ScaledMetric(relativeTo: .caption) private var metadataHeight = 16
    var quote: Quote? { store.portfolio.quote(instrument.symbol) }
    var position: Position? { store.portfolio.positions.first { $0.symbol == instrument.symbol } }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(spacing: 16) {
                    AssetMark(instrument: instrument, large: true, logoURL: quote?.logoURL)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(instrument.name).font(.title2.weight(.bold))
                        Text("\(instrument.symbol) · \(instrument.category)").font(.subheadline).foregroundStyle(Theme.muted)
                    }
                }
                quoteCard
                AssetChartView(symbol: instrument.symbol, reloadID: historyReload)
                if let position { positionCard(position) }
                Text("Practica con dinero ficticio. Cada compra o venta tiene una comisión simulada de 1 US$.")
                    .font(.caption).foregroundStyle(Theme.muted).lineSpacing(3)
            }.padding(20)
        }.appCanvas().navigationTitle(instrument.symbol).navigationBarTitleDisplayMode(.inline)
            .refreshable { await refreshDetail() }
            .safeAreaInset(edge: .bottom) { tradeControls }
            .sheet(isPresented: Binding(get: { tradeSide != nil }, set: { if !$0 { tradeSide = nil } })) {
                TradeView(instrument: instrument, side: tradeSide ?? "buy")
            }
            .onAppear {
                #if DEBUG
                if UserDefaults.standard.string(forKey: "preview-screen") == "trade" { tradeSide = "buy" }
                #endif
            }
            .task(id: scenePhase) {
                guard scenePhase == .active else { return }
                await refreshDetail()
                while !Task.isCancelled {
                    do { try await Task.sleep(for: .seconds(15)) } catch { return }
                    guard !Task.isCancelled else { return }
                    _ = try? await store.refreshQuote(instrument.symbol)
                }
            }
    }
    private var quoteCard: some View {
        let waiting = quote == nil && quoteIssue == nil
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                ConceptLabel(title: instrument.kind == "stock" ? "Precio por acción" : "Precio por participación", concept: .cachedPrice).font(.subheadline)
                Spacer()
                Text(quote?.nativeCurrency ?? "USD").font(.caption.weight(.semibold)).foregroundStyle(Theme.muted)
                    .redacted(reason: waiting ? .placeholder : [])
            }
            Text(quote?.nativePriceText ?? (waiting ? "000,00 US$" : "—"))
                .font(.system(.largeTitle, design: .rounded).weight(.bold)).monospacedDigit()
                .minimumScaleFactor(0.6).lineLimit(1)
                .redacted(reason: waiting ? .placeholder : [])
                .accessibilityLabel(quote?.nativePriceText ?? "Cargando precio")
            // Reserve the conversion line before the provider establishes the currency.
            Text(quote?.usesConversion == true ? "En USD: \(Money.text(quote!.priceCents)) por unidad" : "Operaciones en USD")
                .font(.caption).foregroundStyle(Theme.muted).lineLimit(2)
                .frame(minHeight: metadataHeight, alignment: .topLeading)
            HStack(spacing: 8) {
                if let quote { ChangeLabel(percent: quote.changePercent) }
                else { Text("0,00 %").font(.caption).redacted(reason: .placeholder).accessibilityHidden(true) }
                ConceptLabel(title: "Variación diaria", concept: .dailyChange).font(.caption)
            }
            Divider().overlay(Theme.line)
            TimelineView(.periodic(from: .now, by: 1)) { _ in
                Label(quoteIssue ?? quote?.status ?? "Consultando precio…", systemImage: "clock")
                    .font(.caption).foregroundStyle(Theme.muted).lineLimit(2)
                    .frame(minHeight: metadataHeight, alignment: .topLeading)
            }
            Text(quote.map { item in
                let date = ISO.date(item.asOf)?.formatted(.dateTime.day().month(.abbreviated).year().hour().minute().locale(Locale(identifier: "es_ES"))) ?? ""
                return "\(date) · \(item.source)"
            } ?? "Fecha y fuente del precio")
                .font(.caption).foregroundStyle(Theme.muted).lineLimit(2)
                .frame(minHeight: metadataHeight, alignment: .topLeading)
                .redacted(reason: waiting ? .placeholder : [])
                .opacity(quote != nil || waiting ? 1 : 0).accessibilityHidden(quote == nil)
        }.padding(22).frame(maxWidth: .infinity, alignment: .leading).dataCard()
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("detail-quote-card")
    }
    private func positionCard(_ position: Position) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            ConceptLabel(title: "Tu inversión · \(position.units) unidades", concept: .positions).font(.headline)
            detailLine("Precio medio de compra", value: Money.text(position.averageCostCents))
            detailLine("Coste total", value: Money.text(position.costCents))
            detailLine("Valor actual", value: quote.map { Money.text(position.marketValueCents(at: $0)) } ?? "—")
            HStack {
                Text("Resultado").font(.subheadline).foregroundStyle(Theme.muted)
                Spacer()
                let profit = quote.map { position.profitCents(at: $0) }
                Text(profit.map(Money.signed) ?? "—").font(.headline).monospacedDigit()
                    .foregroundStyle(profit.map { $0 < 0 ? Theme.loss : Theme.gain } ?? Theme.muted)
            }
            Text("El coste incluye las comisiones de compra.").font(.caption).foregroundStyle(Theme.muted)
        }.padding(22).dataCard()
    }
    private var tradeControls: some View {
        VStack(spacing: 6) {
            Text(position.map { "Tienes \($0.units) unidades · Elige comprar más o vender" } ?? "Compra con saldo virtual. Podrás vender desde aquí cuando tengas unidades.")
                .font(.caption).foregroundStyle(Theme.muted)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) { tradeButtons }
                VStack(spacing: 12) { tradeButtons }
            }
        }.padding(.horizontal, 20).padding(.vertical, 12).background(.bar)
    }
    @ViewBuilder private var tradeButtons: some View {
        if store.signedIn && position != nil {
            Button { tradeSide = "sell" } label: {
                Text("Vender").font(.body.weight(.semibold)).frame(maxWidth: .infinity).padding(18).flatControl(radius: 16)
            }.buttonStyle(.plain).disabled(position == nil).accessibilityIdentifier("detail-sell")
        }
        PrimaryButton(title: store.signedIn ? "Comprar" : "Iniciar sesión para comprar", icon: store.signedIn ? "plus" : "person") {
            if store.signedIn { tradeSide = "buy" } else { store.showAuth = true }
        }.accessibilityIdentifier("detail-buy")
    }
    private func detailLine(_ title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).foregroundStyle(Theme.muted); Spacer(); Text(value).fontWeight(.semibold).monospacedDigit()
        }.font(.subheadline)
    }
    private func refreshDetail() async {
        historyReload += 1
        await updateQuote()
    }

    private func updateQuote() async {
        guard !refreshing else { return }
        refreshing = true; defer { refreshing = false }
        do { _ = try await store.refreshQuote(instrument.symbol); quoteIssue = nil } catch { quoteIssue = UserMessage.describe(error) }
    }
}
