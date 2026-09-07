import SwiftUI


struct PortfolioView: View {
    @EnvironmentObject var store: AppStore
    var explore: () -> Void
    @State private var profile = false
    @State private var wallet = false
    @State private var selling: Instrument?
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                balance
                actions
                notices
                positions
                if !store.portfolio.positions.isEmpty { AllocationView() }
                Text("Dinero virtual · Cuenta en USD").font(.caption).foregroundStyle(Theme.muted)
                    .frame(maxWidth: .infinity).padding(.vertical, 8)
            }.padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 24)
        }.appCanvas().toolbar(.hidden, for: .navigationBar)
            .refreshable { await store.refresh() }
            .sheet(isPresented: $profile) { ProfileView() }
            .sheet(isPresented: $wallet) { WalletView() }
            .sheet(item: $selling) { TradeView(instrument: $0, side: "sell") }
            .onAppear {
                #if DEBUG
                if UserDefaults.standard.bool(forKey: "preview-profile") { profile = true }
                #endif
            }
    }
    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Mi cartera").font(.largeTitle.weight(.bold))
            }
            Spacer()
            Button { profile = true } label: {
                ProfileAvatar()
            }.accessibilityLabel("Perfil y apariencia").accessibilityIdentifier("open-profile")
        }
    }
    private var balance: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                ConceptLabel(title: store.signedIn ? "Valor de mi cartera" : "Tu saldo virtual al empezar", concept: .portfolioValue).font(.subheadline)
                Spacer()
                Pill(text: "Virtual", icon: "sparkles")
            }
            VStack(alignment: .leading, spacing: 10) {
                Text(store.portfolio.equityCents.map(Money.text) ?? "—")
                    .font(.system(.largeTitle, design: .rounded).weight(.bold)).monospacedDigit()
                    .minimumScaleFactor(0.6).lineLimit(1).contentTransition(.numericText())
                if !store.signedIn {
                    Text("Crea tu cuenta y practica tu primera inversión.").font(.subheadline).foregroundStyle(Theme.muted)
                } else if let profit = store.portfolio.profitCents {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 8) { profitBadge(profit); Text("Resultado total").font(.caption).foregroundStyle(Theme.muted) }
                        VStack(alignment: .leading, spacing: 8) { profitBadge(profit); Text("Resultado total").font(.caption).foregroundStyle(Theme.muted) }
                    }
                } else {
                    Label("Faltan cotizaciones para calcular el valor", systemImage: "clock").font(.caption).foregroundStyle(Theme.muted)
                }
            }
            Divider().overlay(Theme.line)
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 24) { balanceMetrics }
                VStack(alignment: .leading, spacing: 18) { balanceMetrics }
            }
            if store.portfolio.hasStaleValuation {
                Label("Valoración con los últimos precios disponibles", systemImage: "clock").font(.caption).foregroundStyle(Theme.muted)
            }
            if !store.signedIn {
                Button { store.showAuth = true } label: {
                    Label("Inicia sesión para activar tu saldo virtual", systemImage: "person.badge.key").font(.subheadline)
                }.frame(minHeight: 44, alignment: .leading)
            }
        }.padding(22).dataCard()
    }
    @ViewBuilder private var balanceMetrics: some View {
        metric("En inversiones", value: store.portfolio.investedCents.map(Money.text) ?? "—", icon: "chart.pie", concept: .investedValue)
        metric("Disponible", value: Money.text(store.portfolio.availableCashCents), icon: "wallet.bifold", concept: .virtualCash)
    }
    private func metric(_ title: String, value: String, icon: String, concept: LearningConcept? = nil) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 5) { if let concept { ConceptLabel(title: title, concept: concept).font(.caption) } else { Label(title, systemImage: icon).font(.caption).foregroundStyle(Theme.muted) } }.frame(minHeight: 44, alignment: .leading)
            Text(value).font(.headline).monospacedDigit().fixedSize(horizontal: true, vertical: false)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
    private func profitBadge(_ value: Int64) -> some View {
        Label(Money.signed(value), systemImage: value < 0 ? "arrow.down.right" : value > 0 ? "arrow.up.right" : "minus")
            .font(.subheadline.weight(.semibold)).monospacedDigit()
            .foregroundStyle(value < 0 ? Theme.loss : value > 0 ? Theme.gain : Theme.muted)
            .padding(.horizontal, 10).padding(.vertical, 6).background(Theme.pale, in: Capsule())
    }
    private var actions: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) { actionButtons }
            VStack(spacing: 12) { actionButtons }
        }
    }
    @ViewBuilder private var actionButtons: some View {
        PrimaryButton(title: "Comprar activos", icon: "plus", action: explore)
        Button { wallet = true } label: {
            Label("Añadir saldo", systemImage: "wallet.bifold").font(.body.weight(.semibold))
                .frame(maxWidth: .infinity).padding(.horizontal, 18).padding(.vertical, 18).flatControl(radius: 16)
        }.buttonStyle(.plain).foregroundStyle(Theme.accent)
    }
    @ViewBuilder private var notices: some View {
        if let notice = store.notice {
            HStack(alignment: .top) {
                Image(systemName: "checkmark.circle").foregroundStyle(Theme.accent)
                Text(notice).font(.subheadline)
                Spacer()
                Button { store.notice = nil } label: { Image(systemName: "xmark").frame(width: 44, height: 44) }.accessibilityLabel("Cerrar aviso")
            }.padding(16).dataCard()
        }
        if store.pendingTrade != nil {
            PrimaryButton(title: "Comprobar operación pendiente", icon: "arrow.clockwise", loading: store.busy) { Task { await store.retryTrade() } }
        }
        if store.pendingPurchase != nil {
            Button("Compra pendiente · comprobar saldo") { Task { await store.refresh() } }.font(.subheadline).frame(minHeight: 44)
        }
    }
    private var positions: some View {
        VStack(alignment: .leading, spacing: 16) {
            ConceptLabel(title: "Tus activos · \(store.portfolio.positions.count) posiciones", concept: .positions).font(.headline)
            if store.portfolio.positions.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "chart.pie").font(.largeTitle).foregroundStyle(Theme.accent)
                        .frame(width: 68, height: 68).background(Theme.pale, in: RoundedRectangle(cornerRadius: 22))
                    ConceptLabel(title: "Tu cartera empieza aquí", concept: .positions).font(.title3.weight(.semibold))
                    Text("Busca tu primera acción o ETF y practica con tu saldo virtual.")
                        .font(.subheadline).foregroundStyle(Theme.muted).multilineTextAlignment(.center)
                    Button("Buscar activos", action: explore).font(.body.weight(.semibold)).frame(minHeight: 44)
                }.frame(maxWidth: .infinity).padding(24).dataCard()
            } else {
                VStack(spacing: 0) {
                    ForEach(store.portfolio.positions) { position in
                        VStack(spacing: 0) {
                            let instrument = store.instrument(position.symbol)
                            NavigationLink { InstrumentView(instrument: instrument) } label: {
                                PositionRow(instrument: instrument, position: position, quote: store.portfolio.quote(position.symbol))
                            }.buttonStyle(.plain)
                            Button { selling = instrument } label: {
                                Label("Vender \(instrument.name)", systemImage: "arrow.up.right")
                                    .font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity, minHeight: 48)
                            }.buttonStyle(.bordered).padding(.bottom, 16)
                                .accessibilityIdentifier("sell-position-\(position.symbol)")
                            if position.id != store.portfolio.positions.last?.id { Divider().overlay(Theme.line) }
                        }
                    }
                }.padding(.horizontal, 18).dataCard()
            }
        }
    }
}

struct PositionRow: View {
    let instrument: Instrument
    let position: Position
    let quote: Quote?
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                AssetMark(instrument: instrument, logoURL: quote?.logoURL)
                VStack(alignment: .leading, spacing: 5) {
                    Text(instrument.name).font(.body.weight(.semibold))
                    Text("\(instrument.symbol) · \(position.units) unidades").font(.caption).foregroundStyle(Theme.muted)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(Theme.muted)
            }
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 12) { metrics }
                VStack(alignment: .leading, spacing: 12) { metrics }
            }
        }.padding(.vertical, 18).contentShape(Rectangle())
    }
    @ViewBuilder private var metrics: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Valor actual").font(.caption).foregroundStyle(Theme.muted)
            Text(quote.map { Money.text(position.marketValueCents(at: $0)) } ?? "—").font(.subheadline.weight(.semibold)).monospacedDigit()
        }.frame(maxWidth: .infinity, alignment: .leading)
        VStack(alignment: .leading, spacing: 5) {
            Text("Resultado").font(.caption).foregroundStyle(Theme.muted)
            if let quote {
                let profit = position.profitCents(at: quote)
                Text(Money.signed(profit)).font(.subheadline.weight(.semibold)).monospacedDigit()
                    .foregroundStyle(profit < 0 ? Theme.loss : profit > 0 ? Theme.gain : Theme.muted)
            } else { Text("—").font(.subheadline) }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct AllocationView: View {
    @EnvironmentObject var store: AppStore
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            ConceptLabel(title: "Distribución", concept: .allocation).font(.headline)
            if let total = store.portfolio.equityCents, total > 0 {
                ForEach(store.portfolio.positions) { position in
                    if let quote = store.portfolio.quote(position.symbol) {
                        allocation(position.symbol, cents: position.marketValueCents(at: quote), total: total, color: Theme.accent)
                    }
                }
                allocation("Efectivo", cents: store.portfolio.cashCents, total: total, color: Theme.muted)
            } else { Text("La distribución estará disponible cuando tengamos todos los precios.").font(.subheadline).foregroundStyle(Theme.muted) }
        }.padding(20).dataCard()
    }
    private func allocation(_ title: String, cents: Int64, total: Int64, color: Color) -> some View {
        let weight = Double(cents) / Double(total)
        return VStack(spacing: 8) {
            HStack { Text(title); Spacer(); Text(weight.formatted(.percent.precision(.fractionLength(1)))).monospacedDigit() }.font(.subheadline)
            GeometryReader { geo in
                Capsule().fill(Theme.pale).overlay(alignment: .leading) {
                    Capsule().fill(color).frame(width: geo.size.width * min(max(weight, 0), 1))
                }
            }.frame(height: 6).accessibilityHidden(true)
        }
    }
}

struct OrderHistory: View {
    @EnvironmentObject var store: AppStore
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ConceptLabel(title: "Operaciones realizadas", concept: .activity).font(.headline)
            if store.portfolio.orders.isEmpty {
                VStack(spacing: 14) {
                    Image(systemName: "arrow.left.arrow.right").font(.title).foregroundStyle(Theme.accent)
                    ConceptLabel(title: "Aún no hay operaciones", concept: .activity).font(.headline)
                    Text("Tus compras y ventas aparecerán aquí, con su importe y comisión.").font(.subheadline).foregroundStyle(Theme.muted).multilineTextAlignment(.center)
                }.frame(maxWidth: .infinity).padding(28).dataCard()
            } else {
                VStack(spacing: 0) {
                    ForEach(store.portfolio.orders) { order in
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 12) {
                                Image(systemName: order.side == "buy" ? "arrow.down.left" : "arrow.up.right")
                                    .foregroundStyle(Theme.accent).frame(width: 42, height: 42).background(Theme.pale, in: Circle())
                                VStack(alignment: .leading, spacing: 5) {
                                    Text("\(order.side == "buy" ? "Compra" : "Venta") de \(order.symbol)").font(.body.weight(.semibold))
                                    Text("\(order.units) unidades · comisión \(Money.text(order.feeCents))").font(.caption).foregroundStyle(Theme.muted)
                                }
                            }
                            HStack {
                                Text(ISO.date(order.createdAt)?.formatted(.dateTime.day().month(.abbreviated).year().hour().minute().locale(Locale(identifier: "es_ES"))) ?? "").font(.caption).foregroundStyle(Theme.muted)
                                Spacer()
                                Text(Money.text(order.priceCents * Int64(order.units))).font(.subheadline.weight(.semibold)).monospacedDigit()
                            }
                        }.padding(.vertical, 16)
                        if order.id != store.portfolio.orders.last?.id { Divider().overlay(Theme.line) }
                    }
                }.padding(.horizontal, 18).dataCard()
            }
        }
    }
}

struct ActivityView: View {
    @EnvironmentObject var store: AppStore
    @State private var editing: SimulatedOrder?
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if let notice = store.notice { Text(notice).font(.subheadline).foregroundStyle(Theme.accent) }
                if store.pendingTrade != nil {
                    PrimaryButton(title: "Comprobar operación pendiente", loading: store.busy) { Task { await store.retryTrade() } }
                }
                if !store.portfolio.queuedOrders.isEmpty {
                    Text("En marcha").font(.title2.bold())
                    Text("Se ejecutan automáticamente, también con la app cerrada.").font(.subheadline).foregroundStyle(Theme.muted)
                    ForEach(store.portfolio.queuedOrders) { order in
                        TimelineView(.periodic(from: .now, by: 1)) { _ in
                            VStack(alignment: .leading, spacing: 12) {
                                Label("\(order.side == "buy" ? "Compra" : "Venta") de \(order.symbol)", systemImage: "clock").font(.headline)
                                Text("\(order.units) unidades · \(Money.text(order.priceCents)) por unidad").font(.subheadline)
                                Text(order.editable ? "Pendiente · ejecución prevista a las \((ISO.date(order.executeAt) ?? .now).formatted(date: .omitted, time: .standard))" : "Procesando la ejecución…").font(.caption).foregroundStyle(Theme.muted)
                                Text(order.side == "buy" ? "Reservado: \(Money.text(order.totalCents))" : "Unidades reservadas: \(order.units)").font(.caption)
                                HStack {
                                    Button("Editar orden") { editing = order }.accessibilityIdentifier("edit-pending-order")
                                    Spacer()
                                    Button("Cancelar orden", role: .destructive) { Task { await store.cancelOrder(order) } }
                                }.frame(minHeight: 44).disabled(store.busy || !order.editable)
                            }.padding(20).dataCard()
                        }
                    }
                }
                if !store.limitOrders.isEmpty {
                    ConceptLabel(title: "Órdenes antiguas guardadas en este dispositivo", concept: .orderType).font(.headline)
                    ForEach(store.limitOrders) { order in
                        VStack(alignment: .leading, spacing: 12) {
                            ConceptLabel(title: "Compra de \(order.symbol)", concept: .orderType).font(.headline)
                            Text("\(order.units) unidades · máximo \(Money.text(order.limitCents)) por unidad").font(.subheadline)
                            Text("Pendiente · no se ha reservado saldo").font(.caption).foregroundStyle(Theme.muted)
                            PrimaryButton(title: "Comprobar y ejecutar", disabled: store.pendingTrade != nil, loading: store.busy) {
                                Task { await store.executeLimitOrder(order) }
                            }
                            Button("Cancelar orden", role: .destructive) { store.cancelLimitOrder(order) }
                                .frame(minHeight: 44).disabled(store.busy || store.pendingTrade?.requestId == order.id)
                        }.padding(20).dataCard()
                    }
                }
                if let orders = store.portfolio.simulatedOrders, orders.contains(where: { $0.status == "cancelled" }) {
                    Text("Canceladas").font(.headline)
                    ForEach(orders.filter { $0.status == "cancelled" }) { order in
                        VStack(alignment: .leading, spacing: 6) {
                            Text("\(order.side == "buy" ? "Compra" : "Venta") de \(order.symbol) · \(order.units) unidades").font(.subheadline)
                            Text("Cancelada · reserva liberada, sin comisión").font(.caption).foregroundStyle(Theme.muted)
                        }.padding(16).dataCard()
                    }
                }
                OrderHistory()
            }.padding(20)
        }
            .appCanvas().navigationTitle("Movimientos").navigationBarTitleDisplayMode(.inline)
            .refreshable { await store.refresh() }
            .sheet(item: $editing) { order in TradeView(instrument: store.instrument(order.symbol), side: order.side, editing: order) }
    }
}
