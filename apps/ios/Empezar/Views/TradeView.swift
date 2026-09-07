import SwiftUI

struct TradeView: View {
    let instrument: Instrument
    let side: String
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var quantity = "1"
    @State private var orderType = PurchaseOrderType.market
    @State private var limitPrice = ""
    @State private var choosingOrderType = false
    private var isLimit: Bool { side == "buy" && orderType == .limit }
    private var limitCents: Int64 {
        let normalized = limitPrice.replacingOccurrences(of: ",", with: ".")
        guard normalized.range(of: #"^[0-9]{1,8}(\.[0-9]{1,2})?$"#, options: .regularExpression) != nil,
              let value = Decimal(string: normalized), value > 0, value <= 10_000_000 else { return 0 }
        return NSDecimalNumber(decimal: value * 100).int64Value
    }
    @State private var quote: Quote?
    @State private var reviewing = false
    @State private var success = false
    @State private var loading = false
    @State private var issue: String?
    @State private var request: TradeRequest?
    @FocusState private var quantityFocused: Bool
    @FocusState private var limitFocused: Bool
    @ScaledMetric(relativeTo: .largeTitle) private var quantityFontSize = 54.0
    @ScaledMetric(relativeTo: .largeTitle) private var priceFontSize = 38.0
    var units: Int { Int(quantity) ?? 0 }
    var ownedUnits: Int { store.portfolio.positions.first { $0.symbol == instrument.symbol }?.units ?? 0 }
    var maximumUnits: Int {
        let price = isLimit ? limitCents : (quote?.priceCents ?? 0)
        guard price > 0 else { return 0 }
        return side == "buy" ? Int(min(100000, max(0, store.portfolio.cashCents - fee) / price)) : min(100000, ownedUnits)
    }
    var subtotal: Int64 { (isLimit ? limitCents : (quote?.priceCents ?? 0)) * Int64(max(0, min(units, 100000))) }
    let fee: Int64 = 100
    var total: Int64 { side == "buy" ? subtotal + fee : subtotal - fee }
    var validation: String? {
        if store.pendingTrade != nil && request == nil { return "Hay una operación pendiente. Compruébala desde tu cartera antes de continuar." }
        if isLimit {
            guard quote != nil else { return "Necesitamos una cotización del activo antes de guardar la orden." }
            if units < 1 || units > 100000 { return "Introduce entre 1 y 100.000 unidades enteras." }
            if limitCents <= 0 { return "Introduce un precio límite válido en USD." }
            if total > store.portfolio.cashCents { return "Saldo insuficiente para esta orden. Reduce las unidades o el precio límite." }
            return nil
        }
        guard let quote else { return "Necesitamos el precio del activo para calcular la operación." }
        if !quote.marketOpen { return side == "buy" ? "Mercado cerrado. Puedes guardar una orden limitada y comprobarla cuando abra." : "Mercado cerrado. Podrás vender cuando abra la sesión." }
        if !quote.canTrade { return "Desliza hacia abajo para obtener un precio actualizado." }
        if units < 1 || units > 100000 { return "Introduce entre 1 y 100.000 unidades enteras." }
        if side == "buy" && total > store.portfolio.cashCents { return "Saldo insuficiente. Prueba con menos unidades." }
        if side == "sell" && units > (store.portfolio.positions.first { $0.symbol == instrument.symbol }?.units ?? 0) { return "No tienes tantas unidades para vender." }
        if side == "sell" && total < 0 { return "El importe no cubre la comisión." }
        return nil
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 25) {
                    if success {
                        Image(systemName: "checkmark").font(.largeTitle).foregroundStyle(Color.white).frame(width: 88, height: 88).background(Theme.button, in: Circle()).padding(.top, 30)
                        Text(isLimit ? "Orden guardada" : side == "buy" ? "Compra completada" : "Venta completada").font(.system(.largeTitle, design: .rounded))
                        Text(isLimit ? "Tu orden de \(units) unidades de \(instrument.name) está en Movimientos. Compruébala allí para ejecutarla cuando el precio cumpla tu límite." : "\(units) unidades de \(instrument.name). La operación y la comisión ya están reflejadas en tu cartera.").lineSpacing(4).foregroundStyle(Theme.muted)
                        ReadingCard(eyebrow: "Operación virtual", title: Money.text(total), text: isLimit ? "Importe máximo con comisión. Todavía no se ha descontado saldo." : side == "buy" ? "Descontado de tu saldo, con la comisión incluida." : "Añadido a tu saldo, con la comisión descontada.", concept: isLimit ? .limitOrder : .marketOrder)
                        PrimaryButton(title: "Listo", icon: "checkmark") { dismiss() }
                    } else {
                        HStack { AssetMark(instrument: instrument, logoURL: quote?.logoURL); VStack(alignment: .leading, spacing: 5) { Text(instrument.name).font(.title3.weight(.medium)); Text(instrument.symbol).font(.caption).foregroundStyle(Theme.muted) }; Spacer(); Pill(text: "Virtual", icon: "sparkles") }
                        if reviewing { Text("Revisa tu operación").font(.title.weight(.bold)) }
                        else { Text(side == "buy" ? "1. Elige cuántas unidades comprar" : "1. Elige cuántas unidades vender").font(.headline) }
                        if let quote {
                            Text("Precio por unidad: \(Money.text(quote.priceCents))").font(.subheadline.weight(.semibold))
                            if quote.usesConversion {
                                Text("Cotiza a \(quote.nativePriceText). Tu cartera paga y recibe USD; el cambio ya está incluido en este precio.").font(.caption).foregroundStyle(Theme.muted)
                                if let rate = quote.exchangeRate, let currency = quote.nativeCurrency {
                                    Text("1 \(currency) = \(rate.formatted(.number.precision(.fractionLength(4)))) USD").font(.caption).foregroundStyle(Theme.muted)
                                }
                            }
                        }
                        if side == "buy" && !reviewing {
                            Button { quantityFocused = false; limitFocused = false; choosingOrderType = true } label: {
                                HStack(spacing: 14) {
                                    Image(systemName: orderType.icon).font(.title3).foregroundStyle(Theme.accent)
                                        .frame(width: 44, height: 44).background(Theme.pale, in: Circle())
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Tipo de compra").font(.caption).foregroundStyle(Theme.muted)
                                        Text(orderType.title).font(.body.weight(.semibold)).foregroundStyle(Theme.ink)
                                    }.frame(maxWidth: .infinity, alignment: .leading)
                                    Image(systemName: "chevron.down").font(.subheadline.weight(.semibold)).foregroundStyle(Theme.muted)
                                }.padding(18).dataCard()
                            }.buttonStyle(.plain).accessibilityIdentifier("purchase-order-type")
                            .onChange(of: orderType) { _, _ in request = nil; issue = nil }
                            if isLimit {
                                VStack(alignment: .leading, spacing: 14) {
                                    ConceptLabel(title: "Precio máximo por unidad", concept: .limitOrder).font(.subheadline)
                                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                                        TextField("0", text: $limitPrice).keyboardType(.decimalPad).focused($limitFocused).textFieldStyle(.plain)
                                            .font(.system(size: priceFontSize, weight: .semibold, design: .rounded)).monospacedDigit()
                                            .accessibilityLabel("Precio máximo por unidad (USD)").accessibilityIdentifier("limit-price")
                                        Text("USD").font(.subheadline.weight(.semibold)).foregroundStyle(Theme.muted)
                                    }
                                    Rectangle().fill(limitFocused ? Theme.accent : Theme.line).frame(height: 1)
                                    Text("Se guardará en Movimientos. Allí podrás comprobarla y ejecutarla.").font(.caption).foregroundStyle(Theme.muted)
                                }.padding(20).dataCard()
                            }
                        }
                        if !reviewing {
                            VStack(spacing: 18) {
                                ConceptLabel(title: "Número de unidades", concept: .positions).font(.subheadline)
                                HStack(spacing: 12) {
                                    quantityButton("minus", label: "Quitar una unidad", disabled: units <= 1) { quantity = String(max(1, units - 1)) }
                                    TextField("1", text: $quantity).keyboardType(.numberPad).focused($quantityFocused)
                                        .font(.system(size: quantityFontSize, weight: .semibold, design: .rounded)).monospacedDigit().multilineTextAlignment(.center).textFieldStyle(.plain).minimumScaleFactor(0.6)
                                        .accessibilityLabel("Número de unidades").accessibilityIdentifier("trade-quantity")
                                        .onChange(of: quantity) { _, _ in request = nil; issue = nil }
                                    quantityButton("plus", label: "Añadir una unidad", disabled: units >= maximumUnits) { quantity = String(min(maximumUnits, units + 1)) }
                                }
                                Text(side == "buy" ? "Disponible: \(Money.text(store.portfolio.cashCents)) virtuales" : "Tienes \(ownedUnits) unidades para vender")
                                    .font(.subheadline).foregroundStyle(Theme.muted)
                                Button("Usar máximo · \(maximumUnits) unidades") { quantity = String(maximumUnits); quantityFocused = false }
                                    .font(.subheadline.weight(.semibold)).foregroundStyle(Theme.accent).padding(.horizontal, 18).frame(minHeight: 44)
                                    .background(Theme.pale, in: Capsule()).disabled(maximumUnits == 0)
                            }.padding(22).dataCard()
                        }
                        if reviewing { orderSummary }
                        else {
                            VStack(alignment: .leading, spacing: 12) {
                                line(isLimit ? "Total máximo" : "Total estimado", (!isLimit && quote == nil) ? "—" : Money.text(total), prominent: true)
                                HStack {
                                    ConceptLabel(title: "Comisión incluida", concept: .commission).font(.caption)
                                    Spacer()
                                    Text(Money.text(fee)).font(.subheadline).foregroundStyle(Theme.muted)
                                }
                            }.padding(20).dataCard()
                        }
                        if let q = quote, let date = ISO.date(q.asOf) { Text("Precio de \(date.formatted(.dateTime.day().month(.abbreviated).year().hour().minute().locale(Locale(identifier: "es_ES")))) · \(q.source)").font(.caption).foregroundStyle(Theme.muted) }
                        if reviewing { Button(isLimit ? "Cambiar orden" : "Cambiar unidades") { reviewing = false; request = nil }.frame(minHeight: 44) }
                        Text("Esta operación utiliza dinero ficticio. Revisa la cantidad y la comisión antes de confirmar.").font(.caption).foregroundStyle(Theme.muted).lineSpacing(3)
                    }
                }.frame(maxWidth: .infinity, alignment: .leading).padding(20)
            }.scrollDismissesKeyboard(.interactively).refreshable {
                guard !store.busy, store.pendingTrade == nil, !success else { return }
                await refresh()
            }.appCanvas().navigationTitle(success ? (isLimit ? "Orden guardada" : "Operación completada") : (side == "buy" ? "Comprar" : "Vender")).navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) { Button("Cerrar") { dismiss() }.disabled(store.busy) }
                    ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Listo") { quantityFocused = false; limitFocused = false } }
                }
                .safeAreaInset(edge: .bottom) {
                    if !success { tradeFooter.padding(.horizontal, 20).padding(.vertical, 12).background(.bar) }
                }
                .sheet(isPresented: $choosingOrderType) {
                    OrderTypeSheet(selected: orderType) { orderType = $0 }
                }
                .interactiveDismissDisabled(store.busy)
                .task { await refresh() }
        }
    }
    private var orderSummary: some View {
        VStack(spacing: 18) {
            ConceptLabel(title: isLimit ? "Resumen de la orden limitada" : "Resumen de la operación", concept: .orderType).font(.headline)
            line("Unidades", "\(units)")
            line(isLimit ? "Precio límite por unidad" : "Precio por unidad", isLimit ? Money.text(limitCents) : quote.map { Money.text($0.priceCents) } ?? "—")
            line("Importe", (!isLimit && quote == nil) ? "—" : Money.text(subtotal))
            HStack {
                ConceptLabel(title: "Comisión simulada", concept: .commission).font(.subheadline)
                Spacer()
                Text(Money.text(fee)).font(.subheadline).monospacedDigit()
            }
            Divider()
            line(isLimit ? "Total máximo al ejecutar" : side == "buy" ? "Total a descontar" : "Total a recibir", (!isLimit && quote == nil) ? "—" : Money.text(total), prominent: true)
        }.padding(22).dataCard()
    }
    private var tradeFooter: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            VStack(alignment: .leading, spacing: 12) {
                if let message = issue ?? validation {
                    Text(message).font(.caption).foregroundStyle(issue != nil ? Theme.loss : Theme.muted).accessibilityAddTraits(.updatesFrequently)
                }
                if isLimit {
                    PrimaryButton(title: reviewing ? "Guardar orden de compra" : "Revisar orden", disabled: validation != nil, loading: store.busy, action: proceed)
                } else if quote?.marketOpen == false && side == "buy" {
                    PrimaryButton(title: "Crear orden limitada", icon: "slider.horizontal.3") {
                        orderType = .limit
                        if let quote { limitPrice = String(format: "%.2f", Double(quote.priceCents) / 100) }
                    }
                } else {
                    PrimaryButton(title: reviewing ? (side == "buy" ? "Confirmar compra virtual" : "Confirmar venta virtual") : (side == "buy" ? "Revisar compra" : "Revisar venta"), disabled: validation != nil, loading: store.busy || loading, action: proceed)
                }
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    private func proceed() {
        if reviewing { Task { await submit() } }
        else { quantityFocused = false; limitFocused = false; reviewing = true }
    }
    func quantityButton(_ icon: String, label: String, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).font(.title3.weight(.semibold)).frame(width: 48, height: 48).background(Theme.pale, in: Circle())
        }.buttonStyle(.plain).accessibilityLabel(label).disabled(disabled).opacity(disabled ? 0.4 : 1)
    }
    func line(_ key: String, _ value: String, prominent: Bool = false) -> some View {
        HStack(alignment: .firstTextBaseline) { Text(key).foregroundStyle(prominent ? Theme.ink : Theme.muted); Spacer(); Text(value).monospacedDigit() }.font(prominent ? .headline : .subheadline)
    }
    func refresh() async {
        guard !loading else { return }
        loading = true; issue = nil; defer { loading = false }
        do { quote = try await store.refreshQuote(instrument.symbol); reviewing = false; request = nil }
        catch { issue = UserMessage.describe(error) }
    }
    func submit() async {
        guard validation == nil else { return }
        if isLimit {
            do { try store.saveLimitOrder(symbol: instrument.symbol, units: units, limitCents: limitCents); success = true }
            catch { issue = UserMessage.describe(error) }
            return
        }
        guard let quote else { return }
        let order = request ?? TradeRequest(requestId: UUID().uuidString, symbol: instrument.symbol, side: side, units: units, quoteId: quote.id)
        request = order
        do { try await store.trade(order); success = true }
        catch { issue = UserMessage.describe(error) }
    }
}
