import SwiftUI

struct TradeView: View {
    let instrument: Instrument
    let side: String
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var quantity = "1"
    @State private var quote: Quote?
    @State private var reviewing = false
    @State private var success = false
    @State private var loading = false
    @State private var issue: String?
    @State private var request: TradeRequest?
    @FocusState private var quantityFocused: Bool
    var units: Int { Int(quantity) ?? 0 }
    var ownedUnits: Int { store.portfolio.positions.first { $0.symbol == instrument.symbol }?.units ?? 0 }
    var maximumUnits: Int {
        guard let quote, quote.priceCents > 0 else { return 0 }
        return side == "buy" ? Int(min(100000, max(0, store.portfolio.cashCents - fee) / quote.priceCents)) : min(100000, ownedUnits)
    }
    var subtotal: Int64 { (quote?.priceCents ?? 0) * Int64(max(0, min(units, 100000))) }
    let fee: Int64 = 100
    var total: Int64 { side == "buy" ? subtotal + fee : subtotal - fee }
    var validation: String? {
        if store.pendingTrade != nil && request == nil { return "Hay una operación pendiente. Compruébala desde tu cartera antes de continuar." }
        guard let quote else { return "Necesitamos una cotización real para continuar." }
        if !quote.marketOpen { return "Mercado cerrado. Vuelve cuando abra la sesión." }
        if !quote.canTrade { return "Actualiza el precio para continuar." }
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
                        Text(side == "buy" ? "Compra completada" : "Venta completada").font(.system(.largeTitle, design: .rounded))
                        Text("\(units) unidades de \(instrument.name). La operación y la comisión ya están reflejadas en tu cartera.").lineSpacing(4).foregroundStyle(Theme.muted)
                        ReadingCard(eyebrow: "Operación virtual", title: Money.text(total), text: side == "buy" ? "Descontado de tu saldo, con la comisión incluida." : "Añadido a tu saldo, con la comisión descontada.")
                        PrimaryButton(title: "Listo", icon: "checkmark") { dismiss() }
                    } else {
                        HStack { AssetMark(instrument: instrument); VStack(alignment: .leading, spacing: 5) { Text(instrument.name).font(.title3.weight(.medium)); Text(instrument.symbol).font(.caption).foregroundStyle(Theme.muted) }; Spacer(); Pill(text: "Virtual", icon: "sparkles") }
                        Text(reviewing ? "Revisa tu operación" : (side == "buy" ? "Comprar " : "Vender ") + instrument.symbol).font(.system(.largeTitle, design: .rounded))
                        if !reviewing {
                            VStack(spacing: 18) {
                                Text("Número de unidades").font(.subheadline).foregroundStyle(Theme.muted)
                                HStack(spacing: 12) {
                                    quantityButton("minus", label: "Quitar una unidad", disabled: units <= 1) { quantity = String(max(1, units - 1)) }
                                    TextField("1", text: $quantity).keyboardType(.numberPad).focused($quantityFocused)
                                        .font(.system(.largeTitle, design: .rounded).weight(.bold)).multilineTextAlignment(.center)
                                        .accessibilityLabel("Número de unidades").accessibilityIdentifier("trade-quantity")
                                        .onChange(of: quantity) { _, _ in request = nil; issue = nil }
                                    quantityButton("plus", label: "Añadir una unidad", disabled: units >= maximumUnits) { quantity = String(min(maximumUnits, units + 1)) }
                                }
                                Text(side == "buy" ? "Disponible: \(Money.text(store.portfolio.cashCents)) virtuales" : "Tienes \(ownedUnits) unidades para vender")
                                    .font(.subheadline).foregroundStyle(Theme.muted)
                                Button("Usar máximo: \(maximumUnits) unidades") { quantity = String(maximumUnits); quantityFocused = false }
                                    .font(.subheadline.weight(.semibold)).frame(minHeight: 44).disabled(maximumUnits == 0)
                            }.padding(22).dataCard()
                        }
                        VStack(spacing: 18) {
                            line("Unidades", "\(units)")
                            line("Precio por unidad", quote.map { Money.text($0.priceCents) } ?? "—")
                            line("Importe", quote == nil ? "—" : Money.text(subtotal))
                            line("Comisión simulada", Money.text(fee))
                            Divider()
                            line(side == "buy" ? "Total a descontar" : "Total a recibir", quote == nil ? "—" : Money.text(total), prominent: true)
                        }.padding(22).dataCard()
                        if let q = quote, let date = ISO.date(q.asOf) { Text("Precio de \(date.formatted(date: .abbreviated, time: .shortened)) · Twelve Data").font(.caption).foregroundStyle(Theme.muted) }
                        TimelineView(.periodic(from: .now, by: 1)) { _ in
                            VStack(alignment: .leading, spacing: 16) {
                                if let message = issue ?? validation { Text(message).font(.subheadline).foregroundStyle(Theme.loss).accessibilityAddTraits(.updatesFrequently) }
                                if quote?.canTrade != true {
                                    PrimaryButton(title: "Actualizar precio", icon: "arrow.clockwise", loading: loading) { Task { await refresh() } }
                                } else {
                                    PrimaryButton(title: reviewing ? (side == "buy" ? "Confirmar compra virtual" : "Confirmar venta virtual") : "Revisar operación", disabled: validation != nil, loading: store.busy) {
                                        if reviewing { Task { await submit() } } else { quantityFocused = false; reviewing = true }
                                    }
                                }
                            }
                        }
                        if reviewing { Button("Cambiar unidades") { reviewing = false; request = nil }.frame(minHeight: 44) }
                        Text("Solo dinero virtual. La ejecución usa el último precio del feed, no una cotización bid/ask. No se reserva ni bloquea el precio del mercado.").font(.caption).foregroundStyle(Theme.muted).lineSpacing(3)
                    }
                }.padding(24)
            }.scrollDismissesKeyboard(.interactively).appCanvas().navigationTitle(success ? "Operación completada" : (side == "buy" ? "Comprar" : "Vender")).navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) { Button("Cerrar") { dismiss() }.disabled(store.busy) }
                    ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Listo") { quantityFocused = false } }
                }
                .interactiveDismissDisabled(store.busy)
                .task { await refresh() }
        }
    }
    func quantityButton(_ icon: String, label: String, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).font(.title3.weight(.semibold)).frame(width: 48, height: 48).glassControl(radius: 24)
        }.buttonStyle(.plain).accessibilityLabel(label).disabled(disabled).opacity(disabled ? 0.4 : 1)
    }
    func line(_ key: String, _ value: String, prominent: Bool = false) -> some View {
        HStack(alignment: .firstTextBaseline) { Text(key).foregroundStyle(prominent ? Theme.ink : Theme.muted); Spacer(); Text(value).monospacedDigit() }.font(prominent ? .headline : .subheadline)
    }
    func refresh() async {
        guard !loading else { return }
        loading = true; issue = nil; defer { loading = false }
        do { quote = try await store.refreshQuote(instrument.symbol); reviewing = false; request = nil }
        catch { issue = error.localizedDescription }
    }
    func submit() async {
        guard validation == nil, let quote else { return }
        let order = request ?? TradeRequest(requestId: UUID().uuidString, symbol: instrument.symbol, side: side, units: units, quoteId: quote.id)
        request = order
        do { try await store.trade(order); success = true }
        catch { issue = error.localizedDescription }
    }
}
