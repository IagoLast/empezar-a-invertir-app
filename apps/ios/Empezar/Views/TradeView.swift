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
    var units: Int { Int(quantity) ?? 0 }
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
                        Image(systemName: "checkmark").font(.largeTitle).foregroundStyle(Theme.lime).frame(width: 88, height: 88).background(Theme.forest, in: Circle()).padding(.top, 30)
                        Text(side == "buy" ? "Ya tienes una\nnueva inversión." : "Venta completada.").font(.system(.largeTitle, design: .serif))
                        Text("\(units) unidades de \(instrument.name). La operación y la comisión ya están reflejadas en tu cartera.").lineSpacing(4).foregroundStyle(Theme.muted)
                        ReadingCard(eyebrow: "El siguiente paso", title: "Escribe por qué has invertido.", text: "Entender tu decisión te ayudará a aprender cuando cambien las cosas.")
                        PrimaryButton(title: "Volver a la cartera", icon: "checkmark") { dismiss() }
                    } else {
                        HStack { AssetMark(instrument: instrument); VStack(alignment: .leading, spacing: 5) { Text(instrument.name).font(.title3.weight(.medium)); Text(instrument.symbol).font(.caption).foregroundStyle(Theme.muted) }; Spacer(); Pill(text: "Virtual", icon: "leaf") }
                        Text(reviewing ? "Todo claro.\nTú decides." : "¿Cuántas unidades?").font(.system(.largeTitle, design: .serif))
                        if !reviewing {
                            TextField("Unidades", text: $quantity).keyboardType(.numberPad).font(.system(size: 52, weight: .regular, design: .serif)).padding(22).background(Theme.surface, in: RoundedRectangle(cornerRadius: 22)).accessibilityLabel("Número de unidades")
                                .onChange(of: quantity) { _, _ in request = nil; issue = nil }
                            Text("Disponible: \(Money.text(store.portfolio.cashCents)) virtuales").font(.subheadline).foregroundStyle(Theme.muted)
                        }
                        VStack(spacing: 18) {
                            line("Unidades", "\(units)")
                            line("Precio por unidad", quote.map { Money.text($0.priceCents) } ?? "—")
                            line("Importe", quote == nil ? "—" : Money.text(subtotal))
                            line("Comisión simulada", Money.text(fee))
                            Divider()
                            line(side == "buy" ? "Total a descontar" : "Total a recibir", quote == nil ? "—" : Money.text(total), prominent: true)
                        }.padding(22).background(Theme.surface, in: RoundedRectangle(cornerRadius: 23))
                        if let q = quote, let date = ISO.date(q.asOf) { Text("Precio de \(date.formatted(date: .abbreviated, time: .shortened)) · Twelve Data").font(.caption).foregroundStyle(Theme.muted) }
                        TimelineView(.periodic(from: .now, by: 1)) { _ in
                            VStack(alignment: .leading, spacing: 16) {
                                if let message = issue ?? validation { Text(message).font(.subheadline).foregroundStyle(Theme.loss).accessibilityAddTraits(.updatesFrequently) }
                                if quote?.canTrade != true {
                                    PrimaryButton(title: "Actualizar precio", icon: "arrow.clockwise", loading: loading) { Task { await refresh() } }
                                } else {
                                    PrimaryButton(title: reviewing ? (side == "buy" ? "Confirmar compra virtual" : "Confirmar venta virtual") : "Revisar operación", disabled: validation != nil, loading: store.busy) {
                                        if reviewing { Task { await submit() } } else { reviewing = true }
                                    }
                                }
                            }
                        }
                        if reviewing { Button("Cambiar unidades") { reviewing = false; request = nil }.frame(minHeight: 44) }
                        Text("Solo dinero virtual. La ejecución usa el último precio del feed, no una cotización bid/ask. No se reserva ni bloquea el precio del mercado.").font(.caption).foregroundStyle(Theme.muted).lineSpacing(3)
                    }
                }.padding(24)
            }.appCanvas().navigationTitle(success ? "Operación completada" : (side == "buy" ? "Comprar" : "Vender")).navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Cerrar") { dismiss() }.disabled(store.busy) } }
                .interactiveDismissDisabled(store.busy)
                .task { await refresh() }
        }
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
