import SwiftUI

private enum MarketFilter: CaseIterable, Hashable {
    case all, stocks, etfs, bonds
    var title: String {
        switch self {
        case .all: return "Todo"
        case .stocks: return "Acciones"
        case .etfs: return "ETF"
        case .bonds: return "ETF de bonos"
        }
    }
}

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
    @State private var filter = MarketFilter.all
    @State private var expandedCategories: Set<SearchCategory> = []
    @State private var searchResults: [MarketSearchResult] = []
    @State private var searching = false
    @State private var searchError: String?
    @State private var searchNotice: String?
    private let filters = MarketFilter.allCases
    private var results: [MarketSearchResult] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        let local = Content.instruments.filter {
            query.isEmpty || $0.name.localizedStandardContains(query) || $0.symbol.localizedStandardContains(query)
        }.map { MarketSearchResult(symbol: $0.symbol, name: $0.name, kind: $0.kind, exchange: "EE. UU.") }
        let suggestions = MarketSearchResult.suggestions.filter {
            query.isEmpty || $0.name.localizedStandardContains(query) || $0.symbol.localizedStandardContains(query)
        }
        var combined: [MarketSearchResult] = []
        for var asset in searchResults + local + suggestions {
            if let bundled = Content.instruments.first(where: { $0.symbol == asset.symbol }) {
                asset = MarketSearchResult(symbol: asset.symbol, name: asset.name, kind: bundled.kind, exchange: asset.exchange)
            }
            if !combined.contains(where: { $0.symbol == asset.symbol }) { combined.append(asset) }
        }
        return combined.filter {
            filter == .all || (filter == .stocks && $0.category == .stocks) ||
            (filter == .etfs && $0.category != .stocks) || (filter == .bonds && $0.category == .bonds)
        }
    }
    private func resultLink(_ asset: MarketSearchResult) -> some View {
        NavigationLink { MarketSearchDetail(asset: asset) } label: {
            MarketSearchRow(asset: asset, quote: store.portfolio.quote(asset.symbol))
        }.buttonStyle(.plain)
            .accessibilityIdentifier(Content.instruments.contains(where: { $0.symbol == asset.symbol }) ? "asset-\(asset.symbol)" : "search-result-\(asset.symbol)")
    }
    private func categorySection(_ category: SearchCategory) -> some View {
        let assets = results.filter { $0.category == category }
        let visible = expandedCategories.contains(category) ? assets : Array(assets.prefix(5))
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(category.title).font(.title3.weight(.semibold)).accessibilityIdentifier("search-category-\(category.rawValue)")
                Spacer()
                if assets.count > 5 {
                    Button(expandedCategories.contains(category) ? "Mostrar menos" : "Mostrar más") {
                        if expandedCategories.contains(category) { expandedCategories.remove(category) }
                        else { expandedCategories.insert(category) }
                    }.font(.subheadline).accessibilityIdentifier("expand-search-\(category.rawValue)")
                }
            }
            VStack(spacing: 0) {
                ForEach(visible) { asset in
                    resultLink(asset)
                    if asset.id != visible.last?.id { Divider().overlay(Theme.line) }
                }
            }.padding(.horizontal, 16).dataCard()
        }
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if search.isEmpty {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Mercados").font(.largeTitle.weight(.bold))
                        Text("Busca una empresa, un fondo o su símbolo").font(.subheadline).foregroundStyle(Theme.muted)
                    }
                    Spacer(minLength: 0)
                }
                }
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass").foregroundStyle(Theme.accent)
                    TextField("Buscar empresa o símbolo", text: $search).textFieldStyle(.plain).font(.body).autocorrectionDisabled().textInputAutocapitalization(.never)
                        .accessibilityIdentifier("asset-search")
                        .focused($searchFocused).submitLabel(.search)
                        .onSubmit { searchFocused = false }
                    if !search.isEmpty {
                        Button { search = "" } label: { Image(systemName: "xmark.circle.fill").frame(width: 44, height: 44) }.accessibilityLabel("Borrar búsqueda")
                    }
                }.padding(.horizontal, 18).frame(minHeight: 54).background(Theme.surface, in: Capsule())
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(filters, id: \.self) { item in
                            Button { filter = item } label: {
                                Text(item.title).font(.subheadline.weight(.semibold)).padding(.horizontal, 20).padding(.vertical, 13)
                                    .foregroundStyle(filter == item ? .white : Theme.muted)
                                    .background(filter == item ? Theme.button : Theme.surface, in: Capsule())
                                    .overlay { Capsule().strokeBorder(filter == item ? .clear : Theme.line) }
                            }.buttonStyle(.plain).accessibilityAddTraits(filter == item ? .isSelected : [])
                        }
                    }
                }
                if search.isEmpty {
                    Label("Buscar en mercados de todo el mundo", systemImage: "globe")
                        .font(.subheadline).foregroundStyle(Theme.muted)
                }
                if !search.isEmpty, let best = results.first {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Mejor coincidencia").font(.caption.weight(.semibold)).foregroundStyle(Theme.muted)
                        NavigationLink { MarketSearchDetail(asset: best) } label: {
                            MarketSearchRow(asset: best, quote: store.portfolio.quote(best.symbol))
                        }.buttonStyle(.plain).accessibilityIdentifier("search-best-match")
                    }.padding(.horizontal, 18).padding(.top, 16).dataCard()
                }
                if searching { ProgressView("Buscando en los mercados…").font(.subheadline) }
                if let searchNotice { Text(searchNotice).font(.subheadline).foregroundStyle(Theme.muted) }
                if let searchError {
                    Text(searchError).font(.subheadline).foregroundStyle(Theme.loss)
                    Text("Desliza hacia abajo para volver a buscar.").font(.caption).foregroundStyle(Theme.muted)
                }
                ForEach(SearchCategory.allCases.filter { category in results.contains { $0.category == category } }) { category in
                    categorySection(category)
                }
                if results.isEmpty && !searching && searchError == nil {
                    ContentUnavailableView {
                        Label("Sin resultados", systemImage: "magnifyingglass")
                    } description: {
                        Text("Prueba con el nombre legal de la empresa, su símbolo o un filtro diferente. La cobertura varía según el mercado.")
                    } actions: {
                        Button("Ver todos los activos") { search = ""; filter = .all }
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
                VStack(alignment: .leading, spacing: 8) {
                    Link("Finnhub ↗", destination: URL(string: "https://finnhub.io")!).font(.caption)
                    Link("Alpha Vantage ↗", destination: URL(string: "https://www.alphavantage.co")!).font(.caption)
                    Text("La cobertura depende del activo. Algunos precios se actualizan al cierre de la sesión.").font(.caption).foregroundStyle(Theme.muted)
                    Text("Puedes comprar y vender las acciones y ETF del buscador con dinero virtual. Busca por nombre o símbolo; los filtros se aplican a los resultados de esa búsqueda.").font(.caption).foregroundStyle(Theme.muted)
                }
            }.padding(20).padding(.top, 12)
        }.appCanvas().scrollDismissesKeyboard(.interactively)
            .refreshable {
                await store.refresh()
                if !search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { await searchMarkets() }
            }
            .task(id: search) { await searchMarkets() }
    }
    private func searchMarkets() async {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        searchResults = []; searchError = nil; searchNotice = nil; expandedCategories = []
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
    @State private var fundamentals: Fundamentals?
    @State private var refreshing = false
    @State private var historyReload = 0
    @State private var quoteIssue: String?
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
                VStack(alignment: .leading, spacing: 14) {
                    ConceptLabel(title: "Qué estás comprando", concept: .asset).font(.headline)
                    if instrument.kind != "stock" { ConceptLabel(title: "Fondo cotizado (ETF)", concept: .etf).font(.subheadline) }
                    Text(instrument.summary).font(.body).lineSpacing(4)
                    Link(Content.instruments.contains(where: { $0.symbol == instrument.symbol }) ? "Información del emisor ↗" : "Información del activo ↗", destination: URL(string: instrument.source)!).font(.subheadline)
                }.padding(22).dataCard()
                if instrument.kind == "stock" {
                    VStack(alignment: .leading, spacing: 16) {
                        ConceptLabel(title: "Cómo entender su precio", concept: .pe).font(.headline)
                        Text("Relaciona el precio con los beneficios de la empresa.").font(.subheadline).foregroundStyle(Theme.muted)
                        if fundamentals?.pe != nil || fundamentals?.eps != nil {
                            ViewThatFits(in: .horizontal) {
                                HStack(alignment: .top, spacing: 18) { fundamentalMetrics }
                                VStack(alignment: .leading, spacing: 18) { fundamentalMetrics }
                            }
                        } else {
                            VStack(alignment: .leading, spacing: 4) {
                                ConceptLabel(title: "PER: precio frente a beneficios", concept: .pe).font(.subheadline)
                                ConceptLabel(title: "BPA: beneficio por acción", concept: .eps).font(.subheadline)
                            }
                            Text("Aprende estos conceptos y prueba una valoración con cifras de ejemplo.").font(.subheadline).foregroundStyle(Theme.muted)
                        }
                        if let period = fundamentals?.period { Text("Periodo: \(period == "TTM" ? "últimos doce meses" : period)").font(.caption).foregroundStyle(Theme.muted) }
                        NavigationLink { ValuationView(initialEPS: fundamentals?.eps) } label: {
                            Label("Explorar una valoración", systemImage: "slider.horizontal.3").font(.subheadline.weight(.semibold)).padding(.vertical, 8)
                        }
                    }.padding(22).dataCard()
                }
                ReadingCard(eyebrow: "Riesgos", title: "Antes de invertir", text: instrument.risk, concept: .risk)
                ReadingCard(eyebrow: "Para entenderlo mejor", title: instrument.question, text: instrument.learn, dark: true)
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
        VStack(alignment: .leading, spacing: 14) {
            HStack { ConceptLabel(title: instrument.kind == "stock" ? "Precio por acción" : "Precio por participación", concept: .cachedPrice).font(.subheadline); Spacer(); Text(quote?.nativeCurrency ?? "USD").font(.caption.weight(.semibold)).foregroundStyle(Theme.muted) }
            Text(quote?.nativePriceText ?? "—")
                .font(.system(.largeTitle, design: .rounded).weight(.bold)).monospacedDigit().minimumScaleFactor(0.6).lineLimit(1)
            if let quote {
                if quote.usesConversion {
                    Text("Equivalente: \(Money.text(quote.priceCents)) por unidad. Las operaciones se calculan en USD.").font(.caption).foregroundStyle(Theme.muted)
                }
                HStack(spacing: 8) { ChangeLabel(percent: quote.changePercent); ConceptLabel(title: "Variación diaria", concept: .dailyChange).font(.caption) }
                Divider().overlay(Theme.line)
                TimelineView(.periodic(from: .now, by: 1)) { _ in
                    Label(quote.status, systemImage: "clock").font(.caption).foregroundStyle(Theme.muted)
                }
                if let date = ISO.date(quote.asOf) {
                    Text("\(date.formatted(.dateTime.day().month(.abbreviated).year().hour().minute().locale(Locale(identifier: "es_ES")))) · \(quote.source)").font(.caption).foregroundStyle(Theme.muted)
                }
            } else {
                Text(quoteIssue ?? "Consultando precio…").font(.subheadline).foregroundStyle(Theme.muted)
            }

        }.padding(22).dataCard()
    }
    private func positionCard(_ position: Position) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            ConceptLabel(title: "Tu inversión · \(position.units) unidades", concept: .positions).font(.headline)
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
        if store.signedIn {
            Button { tradeSide = "sell" } label: {
                Text("Vender").font(.body.weight(.semibold)).frame(maxWidth: .infinity).padding(18).flatControl(radius: 16)
            }.buttonStyle(.plain).disabled(position == nil).accessibilityIdentifier("detail-sell")
        }
        PrimaryButton(title: store.signedIn ? "Comprar" : "Iniciar sesión para comprar", icon: store.signedIn ? "plus" : "person") {
            if store.signedIn { tradeSide = "buy" } else { store.showAuth = true }
        }.accessibilityIdentifier("detail-buy")
    }
    @ViewBuilder private var fundamentalMetrics: some View {
        metric("PER", concept: .pe, value: fundamentals?.pe.map { $0 > 0 ? $0.formatted(.number.precision(.fractionLength(1))) + "×" : "No aplicable" } ?? "No disponible")
        metric("Beneficio por acción", concept: .eps, value: fundamentals?.eps.map { Money.text(Int64(($0 * 100).rounded())) } ?? "No disponible")
    }
    private func detailLine(_ title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).foregroundStyle(Theme.muted); Spacer(); Text(value).fontWeight(.semibold).monospacedDigit()
        }.font(.subheadline)
    }
    private func metric(_ title: String, concept: LearningConcept, value: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ConceptLabel(title: title, concept: concept).font(.caption)
            Text(value).font(.headline)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
    private func refreshDetail() async {
        historyReload += 1
        await updateQuote()
        if store.signedIn && instrument.kind == "stock" && Content.instruments.contains(where: { $0.symbol == instrument.symbol }) {
            fundamentals = try? await store.api.request("fundamentals?symbol=\(instrument.symbol)")
        }
    }
    private func updateQuote() async {
        guard !refreshing else { return }
        refreshing = true; defer { refreshing = false }
        do { _ = try await store.refreshQuote(instrument.symbol); quoteIssue = nil } catch { quoteIssue = UserMessage.describe(error) }
    }
}
