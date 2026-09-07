import SwiftUI
import RevenueCat

@MainActor final class AppStore: ObservableObject {
    @Published var portfolio = Portfolio.empty
    @Published var busy = false
    @Published var marketLoading = false
    @Published var error: String?
    @Published var notice: String?
    @Published var signedIn = false
    @Published var showAuth = false
    @Published var packages: [Package] = []
    @Published var monthlyPackage: Package?
    @Published var hasSubscription = false
    @Published var purchasesLoading = false
    @Published var purchasesError: String?
    @Published var trialDescription: String?
    private var customerInfoTask: Task<Void, Never>?
    var canAccessApp: Bool { Configuration.freePreviewEnabled || hasSubscription }

    @Published var pendingPurchase: String?
    @Published var pendingTrade: TradeRequest?
    @Published private(set) var limitOrders: [LocalLimitOrder] = []
    private var limitKey: String { "limit-orders-\(userKey)" }
    let auth = AuthStore()
    lazy var api = APIClient(auth: auth)
    private var revenueCatReady = false
    private var userKey: String { auth.session?.user.id.lowercased() ?? "guest" }
    private var pendingKey: String { "pending-purchase-\(userKey)" }
    private var tradeKey: String { "pending-trade-\(userKey)" }
    init() {
        #if DEBUG && targetEnvironment(simulator)
        if MaestroEnvironment.enabled {
            UserDefaults.standard.removeObject(forKey: "limit-orders-maestro-user")
            UserDefaults.standard.removeObject(forKey: "pending-trade-maestro-user")
            UserDefaults.standard.removeObject(forKey: "pending-purchase-maestro-user")
        }
        #endif
        signedIn = auth.session != nil
    }
    func start() async {
        guard signedIn else { await refresh(); return }
        limitOrders = UserDefaults.standard.data(forKey: limitKey).flatMap { try? JSONDecoder().decode([LocalLimitOrder].self, from: $0) } ?? []
        pendingPurchase = UserDefaults.standard.string(forKey: pendingKey)
        if let data = UserDefaults.standard.data(forKey: tradeKey) { pendingTrade = try? JSONDecoder().decode(TradeRequest.self, from: data) }
        try? await auth.refreshProfile()
        objectWillChange.send()
        await preparePurchases()
        await refresh()
    }
    func loggedIn() async { signedIn = true; showAuth = false; await start() }
    func refresh() async {
        guard !marketLoading else { return }
        marketLoading = true; defer { marketLoading = false }
        if signedIn {
            do { portfolio = try await api.request("state"); reconcilePending() }
            catch { self.error = UserMessage.describe(error) }
        }
        var quoteError: Error?
        let symbols = Set(Content.instruments.map(\.symbol) + portfolio.positions.map(\.symbol))
        for symbol in symbols.sorted() {
            do { let _: Quote = try await refreshQuote(symbol) }
            catch { quoteError = error }
        }
        if let quoteError, portfolio.quotes.isEmpty { self.error = UserMessage.describe(quoteError) }
    }
    func refreshQuote(_ symbol: String) async throws -> Quote {
        let encoded = symbol.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? symbol
        let q: Quote = try await api.request("quote?symbol=\(encoded)", authenticated: false)
        upsert(q)
        return q
    }
    func instrument(_ symbol: String) -> Instrument {
        let quote = portfolio.quote(symbol)
        return .market(symbol: symbol, name: quote?.name, kind: quote?.kind ?? "stock")
    }
    private func upsert(_ q: Quote) { portfolio.quotes.removeAll { $0.symbol == q.symbol }; portfolio.quotes.append(q) }
    func trade(_ request: TradeRequest) async throws {
        guard !busy else { throw AppError.message("Espera a que termine la operación en curso.") }
        busy = true; defer { busy = false }
        pendingTrade = request
        UserDefaults.standard.set(try JSONEncoder().encode(request), forKey: tradeKey)
        do {
            portfolio = try await api.request("orders", method: "POST", body: JSONEncoder().encode(request))
            clearPendingTrade()
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } catch let problem as APIProblem {
            if ["STALE_QUOTE", "INSUFFICIENT_CASH", "INSUFFICIENT_UNITS", "MARKET_CLOSED", "QUOTE_UNAVAILABLE", "INVALID_INPUT", "ORDER_CHANGED", "ORDER_FINISHED"].contains(problem.error) { clearPendingTrade() }
            throw problem
        }
    }
    func refreshOrderState() async {
        guard signedIn, !busy else { return }
        do { portfolio = try await api.request("state"); reconcilePending() }
        catch { self.error = UserMessage.describe(error) }
    }
    func cancelOrder(_ order: SimulatedOrder) async {
        guard !busy else { return }
        busy = true; defer { busy = false }
        do {
            let data = try JSONSerialization.data(withJSONObject: ["requestId": order.id, "revision": order.revision])
            portfolio = try await api.request("orders", method: "DELETE", body: data)
            notice = "Orden cancelada. La reserva se ha liberado."
        } catch { self.error = UserMessage.describe(error) }
    }
    func saveLimitOrder(symbol: String, units: Int, limitCents: Int64) throws {
        guard signedIn, !busy, units > 0, units <= 100000, limitCents > 0, limitCents <= 1_000_000_000,
              portfolio.quote(symbol) != nil else { throw AppError.message("Necesitamos una cotización del activo. Revisa las unidades y el precio límite.") }
        let order = LocalLimitOrder(id: UUID().uuidString, symbol: symbol, units: units, limitCents: limitCents, createdAt: .now)
        limitOrders.insert(order, at: 0)
        persistLimitOrders()
    }
    func cancelLimitOrder(_ order: LocalLimitOrder) {
        guard !busy, pendingTrade?.requestId != order.id else { return }
        limitOrders.removeAll { $0.id == order.id }
        persistLimitOrders()
    }
    private func persistLimitOrders() {
        if let data = try? JSONEncoder().encode(limitOrders) { UserDefaults.standard.set(data, forKey: limitKey) }
    }
    func executeLimitOrder(_ order: LocalLimitOrder) async {
        guard signedIn, !busy, pendingTrade == nil, limitOrders.contains(where: { $0.id == order.id }) else { return }
        let account = userKey
        do {
            let quote = try await refreshQuote(order.symbol)
            guard signedIn, userKey == account, !busy, pendingTrade == nil,
                  limitOrders.contains(where: { $0.id == order.id }) else { return }
            guard order.accepts(quote) else {
                notice = "La orden sigue pendiente: necesita un precio válido de \(Money.text(order.limitCents)) o menos con el mercado abierto."
                return
            }
            try await trade(TradeRequest(requestId: order.id, symbol: order.symbol, side: "buy", units: order.units, quoteId: quote.id))
            reconcilePending()
            limitOrders.removeAll { $0.id == order.id }; persistLimitOrders()
            notice = "Orden enviada. Se ejecutará automáticamente en la simulación."
        } catch { self.error = UserMessage.describe(error) }
    }
    func retryTrade() async {
        guard let pendingTrade else { return }
        do { try await trade(pendingTrade); reconcilePending(); notice = "Operación confirmada. Tu cartera está actualizada." }
        catch { self.error = UserMessage.describe(error) }
    }
    private func clearPendingTrade() { pendingTrade = nil; UserDefaults.standard.removeObject(forKey: tradeKey) }
    func complete(_ lesson: Lesson) async {
        guard !portfolio.completedLessons.contains(lesson.id) else { return }
        if !signedIn { portfolio.completedLessons.append(lesson.id); return }
        do {
            portfolio = try await api.request("lesson", method: "POST", body: JSONSerialization.data(withJSONObject: ["lessonId": lesson.id]))
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        } catch { self.error = UserMessage.describe(error) }
    }
    func preparePurchases() async {
        #if DEBUG && targetEnvironment(simulator)
        if MaestroEnvironment.enabled { return }
        #endif
        guard signedIn, !purchasesLoading, !busy else { return }
        guard Configuration.purchasesConfigured else {
            purchasesError = "Las compras todavía no están disponibles. Vuelve a intentarlo más tarde."
            return
        }
        purchasesLoading = true; purchasesError = nil
        defer { purchasesLoading = false }
        let account = userKey
        do {
            if !Purchases.isConfigured {
                Purchases.configure(withAPIKey: Configuration.value("REVENUECAT_PUBLIC_KEY"), appUserID: account)
            } else if Purchases.shared.appUserID != account {
                _ = try await Purchases.shared.logIn(account)
            }
            guard signedIn, userKey == account else { return }
            revenueCatReady = true
            updateAccess(try await Purchases.shared.customerInfo())
            if customerInfoTask == nil {
                customerInfoTask = Task { [weak self] in
                    for await info in Purchases.shared.customerInfoStream {
                        guard !Task.isCancelled else { return }
                        guard let self, self.signedIn, self.userKey == account else { return }
                        self.updateAccess(info)
                    }
                }
            }
            let offerings = try await Purchases.shared.offerings()
            guard signedIn, userKey == account else { return }
            packages = (offerings["virtual-cash"]?.availablePackages ?? []).filter { ["ei.cash.10000", "ei.cash.25000"].contains($0.storeProduct.productIdentifier) }.sorted { $0.storeProduct.price < $1.storeProduct.price }
            let monthly = offerings["plus"]?.monthly
            monthlyPackage = monthly?.storeProduct.productIdentifier == "ei.plus.monthly" ? monthly : nil
            trialDescription = nil
            if let product = monthlyPackage?.storeProduct,
               let offer = product.introductoryDiscount, offer.paymentMode == .freeTrial {
                let eligibility = await Purchases.shared.checkTrialOrIntroDiscountEligibility(product: product)
                guard signedIn, userKey == account else { return }
                if eligibility == .eligible {
                    trialDescription = Self.periodDescription(offer.subscriptionPeriod, count: offer.numberOfPeriods)
                }
            }
        } catch {
            purchasesError = "No hemos podido cargar las compras. Comprueba tu conexión e inténtalo de nuevo."
        }
    }
    private func updateAccess(_ info: CustomerInfo) {
        hasSubscription = info.entitlements["plus"]?.isActive == true
    }
    private static func periodDescription(_ period: SubscriptionPeriod, count: Int) -> String {
        let value = period.value * count
        let unit: String
        switch period.unit {
        case .day: unit = value == 1 ? "día" : "días"
        case .week: unit = value == 1 ? "semana" : "semanas"
        case .month: unit = value == 1 ? "mes" : "meses"
        case .year: unit = value == 1 ? "año" : "años"
        @unknown default: return "un periodo de prueba"
        }
        return "\(value) \(unit)"
    }
    func subscribe() async {
        guard signedIn, revenueCatReady, let package = monthlyPackage, !busy else { return }
        busy = true; purchasesError = nil; defer { busy = false }
        do {
            let result = try await Purchases.shared.purchase(package: package)
            guard !result.userCancelled else { return }
            updateAccess(result.customerInfo)
            if !hasSubscription { purchasesError = "Tu suscripción está pendiente de confirmación por Apple. Puedes restaurar las compras cuando se apruebe." }
        } catch { purchasesError = UserMessage.describe(error) }
    }
    func restorePurchases() async {
        guard signedIn, !busy else { return }
        if !revenueCatReady { await preparePurchases() }
        guard revenueCatReady else { return }
        busy = true; purchasesError = nil; defer { busy = false }
        do {
            updateAccess(try await Purchases.shared.restorePurchases())
            if !hasSubscription { purchasesError = "No se ha encontrado una suscripción activa para esta cuenta de Apple." }
        } catch { purchasesError = UserMessage.describe(error) }
    }
    func purchase(_ package: Package) async {
        guard signedIn, revenueCatReady, !busy, pendingPurchase == nil else { return }
        busy = true; defer { busy = false }
        do {
            let result = try await Purchases.shared.purchase(package: package)
            guard !result.userCancelled else { return }
            guard let id = result.transaction?.transactionIdentifier else {
                notice = "La compra está pendiente. Actualiza tu cartera en unos instantes."; return
            }
            pendingPurchase = id; UserDefaults.standard.set(id, forKey: pendingKey)
            notice = "Compra recibida. Estamos confirmando tu saldo."
            // Only the server webhook can credit funds; CustomerInfo is not a balance.
            for _ in 0..<12 {
                try await Task.sleep(for: .seconds(2))
                portfolio = try await api.request("state")
                reconcilePending()
                if pendingPurchase == nil { break }
            }
        } catch { self.error = UserMessage.describe(error) }
    }
    private func reconcilePending() {
        let completed = Set(portfolio.orders.map { $0.requestId.lowercased() })
        limitOrders.removeAll { completed.contains($0.id.lowercased()) }
        persistLimitOrders()
        if let id = pendingPurchase, let receipt = portfolio.purchases.first(where: { $0.transactionId == id }), receipt.credited || receipt.refunded {
            pendingPurchase = nil; UserDefaults.standard.removeObject(forKey: pendingKey)
            notice = receipt.refunded ? "La compra ha sido reembolsada." : "Tu saldo virtual ya está disponible."
        }
        if let trade = pendingTrade, portfolio.orders.contains(where: { $0.requestId.lowercased() == trade.requestId.lowercased() }) { clearPendingTrade() }
    }
    func signOut() async {
        guard !busy, !purchasesLoading else { return }
        customerInfoTask?.cancel(); customerInfoTask = nil
        await auth.signOut()
        hasSubscription = false; monthlyPackage = nil; trialDescription = nil; purchasesError = nil
        signedIn = false; limitOrders = []; portfolio = .empty; packages = []; pendingPurchase = nil; pendingTrade = nil; revenueCatReady = false
        if Purchases.isConfigured { _ = try? await Purchases.shared.logOut() }
    }
    func deleteAccount() async {
        struct Result: Decodable { let deleted: Bool }
        do { let _: Result = try await api.request("account", method: "DELETE"); await signOut() }
        catch { self.error = UserMessage.describe(error) }
    }
}
