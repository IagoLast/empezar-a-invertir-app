import SwiftUI

struct TradeView: View {
    let instrument: Instrument
    let side: String
    var editing: SimulatedOrder? = nil
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var quantity = "1"
    @State private var orderType = PurchaseOrderType.market
    @State private var explainingOrder = false
    @State private var limitPrice = ""
    @State private var originalLimitText: String?
    @State private var quote: Quote?
    @State private var reviewing = false
    @State private var sent = false
    @State private var loading = false
    @State private var issue: String?
    @State private var request: TradeRequest?
    @FocusState private var fieldFocused: Bool
    private var executed: Bool {
        guard let request else { return false }
        return store.portfolio.orders.contains { $0.requestId == request.requestId }
            || store.portfolio.simulatedOrders?.contains { $0.id == request.requestId && $0.status == "executed" } == true
    }
    private var isLimit: Bool { orderType == .limit }
    private var units: Int { Int(quantity) ?? 0 }
    @State private var currencySnapshot: CurrencyMoney?
    private var money: CurrencyMoney { currencySnapshot ?? store.money }
    private var limitCents: Int64 {
        if limitPrice == originalLimitText, let original = editing?.limitCents { return original }
        return money.settlementCents(limitPrice, buying: side == "buy") ?? 0
    }
    private var price: Int64 {
        guard let quote else { return 0 }
        return isLimit ? (side == "buy" ? min(quote.priceCents, limitCents) : max(quote.priceCents, limitCents)) : quote.priceCents
    }
    private var total: Int64 { price * Int64(max(0, min(units, 100000))) + (side == "buy" ? 100 : -100) }
    private var availableCash: Int64 { store.portfolio.availableCashCents + (editing?.side == "buy" ? editing!.totalCents : 0) }
    private var availableUnits: Int {
        let owned = store.portfolio.positions.first { $0.symbol == instrument.symbol }?.units ?? 0
        let reserved = store.portfolio.queuedOrders.filter { $0.side == "sell" && $0.symbol == instrument.symbol && $0.id != editing?.id }.reduce(0) { $0 + $1.units }
        return max(0, owned - reserved)
    }
    private var maximum: Int { side == "sell" ? availableUnits : (price > 0 ? Int(min(100000, max(0, availableCash - 100) / price)) : 0) }
    private var validation: String? {
        if !money.available { return "Cambio no disponible. Desliza hacia abajo para actualizar." }
        if let editing, !editing.editable { return "Esta orden ya está en ejecución. Consulta Operaciones." }
        if store.pendingTrade != nil && request == nil { return "Comprueba primero la operación pendiente desde Operaciones." }
        guard let quote else { return "Estamos consultando el precio de referencia." }
        if quote.expired { return "Desliza hacia abajo para actualizar el precio." }
        if units < 1 || units > 100000 { return "Introduce entre 1 y 100.000 unidades." }
        if isLimit && limitCents <= 0 { return "Introduce un precio válido en \(money.currency)." }
        if side == "buy" && total > availableCash { return "Saldo disponible insuficiente. Reduce la cantidad." }
        if side == "sell" && units > availableUnits { return "No tienes suficientes unidades disponibles." }
        if total < 0 { return "El importe no cubre la comisión de \(money.text(100))." }
        return nil
    }
    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    HStack {
                        AssetMark(instrument: instrument, logoURL: quote?.logoURL)
                        VStack(alignment: .leading) { Text(instrument.name).font(.headline); Text(instrument.symbol).foregroundStyle(Theme.muted) }
                        Spacer(); Pill(text: "Simulación", icon: "sparkles")
                    }
                    if sent {
                        Label(executed ? "Operación completada" : "Orden recibida", systemImage: executed ? "checkmark.circle.fill" : "clock").font(.title.bold())
                        Text(executed ? "Tu saldo y tus inversiones ya están actualizados." : "Puedes consultar el estado en Operaciones.").foregroundStyle(Theme.muted)
                        PrimaryButton(title: "Ver operaciones", icon: "list.bullet") { dismiss(); NotificationCenter.default.post(name: .showOrders, object: nil) }
                        Button("Listo") { dismiss() }.frame(maxWidth: .infinity, minHeight: 44)
                    } else {
                        Text(reviewing ? "Revisa tu orden" : editing == nil ? "Prepara tu \(side == "buy" ? "compra" : "venta")" : "Editar orden").font(.title.bold())
                        if !reviewing {
                            VStack(alignment: .leading, spacing: 14) {
                                Text("Cantidad de acciones o participaciones").font(.subheadline.weight(.semibold))
                                HStack {
                                    Button { quantity = String(max(1, units - 1)) } label: { Image(systemName: "minus.circle.fill").font(.title) }.accessibilityLabel("Quitar una unidad")
                                    TextField("1", text: $quantity).keyboardType(.numberPad).focused($fieldFocused)
                                        .font(.largeTitle).multilineTextAlignment(.center).accessibilityIdentifier("trade-quantity")
                                    Button { quantity = String(min(maximum, units + 1)) } label: { Image(systemName: "plus.circle.fill").font(.title) }.accessibilityLabel("Añadir una unidad").disabled(units >= maximum)
                                }
                                Text(side == "buy" ? "Disponible: \(money.text(availableCash))" : "Disponibles: \(availableUnits) unidades").font(.caption).foregroundStyle(Theme.muted)
                                Button("Usar máximo · \(maximum) unidades") { quantity = String(maximum) }.disabled(maximum == 0)
                            }.padding(20).dataCard()
                            VStack(alignment: .leading, spacing: 10) {
                                Picker("Tipo de orden", selection: $orderType) {
                                    Text("A mercado").tag(PurchaseOrderType.market)
                                    Text("Limitada").tag(PurchaseOrderType.limit)
                                }.pickerStyle(.segmented).accessibilityIdentifier("purchase-order-type")
                                Text(isLimit
                                     ? (side == "buy" ? "Fijas el precio máximo que aceptarías pagar." : "Fijas el precio mínimo que aceptarías recibir.")
                                     : "Operas al precio disponible. En el mercado real puede cambiar antes de ejecutarse.")
                                    .font(.subheadline).foregroundStyle(Theme.muted)
                                Button("¿Cómo funciona?") { explainingOrder = true }
                                    .font(.subheadline.weight(.semibold)).frame(minHeight: 44)
                                    .accessibilityIdentifier("explain-order-type")
                            }
                            if isLimit {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text(side == "buy" ? "Precio máximo por unidad (\(money.currency))" : "Precio mínimo por unidad (\(money.currency))").font(.subheadline.bold())
                                    TextField("0,00", text: $limitPrice).keyboardType(.decimalPad).focused($fieldFocused).font(.title2).accessibilityIdentifier("limit-price")
                                    Text("En esta práctica simulamos que se alcanza tu precio. En una bolsa real una orden limitada podría no ejecutarse.").font(.caption).foregroundStyle(Theme.muted)
                                }.padding(20).dataCard()
                            }
                        }
                        VStack(spacing: 12) {
                            summaryLine("Tipo de orden", isLimit ? "Limitada" : "A mercado")
                            summaryLine("Unidades", "\(units)")
                            summaryLine("Precio simulado por unidad", price > 0 ? money.text(price) : "—")
                            summaryLine("Comisión", money.text(100))
                            Divider()
                            summaryLine(side == "buy" ? "Total a pagar" : "Total a recibir", price > 0 ? money.text(total) : "—")
                        }.padding(20).dataCard()
                        if let quote {
                            Text("Referencia: \(money.text(quote.priceCents)) · \(quote.source)").font(.caption).foregroundStyle(Theme.muted)
                            if let date = ISO.date(quote.asOf) { Text(date.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(Theme.muted) }
                            if quote.mode == "eod" { Text("Practicas con un precio de cierre diario, no con una cotización en tiempo real.").font(.subheadline) }
                            else if !quote.marketOpen { Text("Puedes practicar con el último precio disponible.").font(.subheadline) }
                        }
                        Text("Al confirmar se ejecuta tu operación virtual al precio mostrado. Incluye una comisión simulada de \(money.text(100)).")
                            .font(.caption).foregroundStyle(Theme.muted)


                    }
                }.padding(20).id("trade-top")
            }.appCanvas().scrollDismissesKeyboard(.interactively)
                .navigationTitle(side == "buy" ? "Comprar" : "Vender").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) { Button("Cerrar") { dismiss() }.disabled(store.busy) }
                    ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Listo") { fieldFocused = false } }
                }
                .safeAreaInset(edge: .bottom) {
                    if !sent {
                        TimelineView(.periodic(from: .now, by: 1)) { _ in
                            VStack(alignment: .leading, spacing: 8) {
                                if let message = issue ?? validation { Text(message).font(.caption).foregroundStyle(Theme.muted) }
                                if reviewing { Button("Editar orden") { reviewing = false; request = nil }.frame(minHeight: 44).accessibilityIdentifier("edit-order") }
                                PrimaryButton(title: reviewing ? (editing == nil ? "Confirmar operación" : "Guardar cambios") : "Revisar orden", disabled: validation != nil, loading: loading || store.busy) {
                                    if reviewing { Task { await submit() } } else { fieldFocused = false; reviewing = true }
                                }
                            }.padding(20).background(.bar)
                        }
                    }
                }
                .onChange(of: reviewing) { _, _ in withAnimation { proxy.scrollTo("trade-top", anchor: .top) } }
                .sheet(isPresented: $explainingOrder) {
                    ConceptInfoSheet(concept: isLimit ? .limitOrder : .marketOrder)
                }
                .interactiveDismissDisabled(store.busy)
                .refreshable { if !sent && !store.busy && request == nil { await refresh() } }
                .task {
                    await store.refreshCurrencies()
                    currencySnapshot = store.money
                    if let editing { quantity = String(editing.units); orderType = editing.limitCents == nil ? .market : .limit; limitPrice = editing.limitCents.map { money.inputText($0) } ?? "" }
                    originalLimitText = limitPrice
                    await refresh()
                }
            }
        }
    }
    private func summaryLine(_ label: String, _ value: String) -> some View { HStack { Text(label); Spacer(); Text(value).fontWeight(.semibold).monospacedDigit() } }
    private func refresh() async {
        loading = true; defer { loading = false }
        if !money.available { await store.refreshCurrencies(); currencySnapshot = store.money }
        do { quote = try await store.refreshQuote(instrument.symbol); issue = nil; reviewing = false }
        catch { issue = UserMessage.describe(error) }
    }
    private func submit() async {
        guard validation == nil, let quote else { return }
        let order = request ?? TradeRequest(requestId: editing?.id ?? UUID().uuidString, symbol: instrument.symbol, side: side, units: units, quoteId: quote.id, limitCents: isLimit ? limitCents : nil, revision: editing?.revision)
        request = order
        do { try await store.trade(order); sent = true }
        catch { issue = UserMessage.describe(error); if store.pendingTrade == nil { request = nil } }
    }
}
extension Notification.Name { static let showOrders = Notification.Name("showOrders") }
