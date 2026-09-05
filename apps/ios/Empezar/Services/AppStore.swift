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
    @Published var pendingPurchase: String?
    @Published var pendingTrade: TradeRequest?
    let auth = AuthStore()
    lazy var api = APIClient(auth: auth)
    private var revenueCatReady = false
    private var userKey: String { auth.session?.user.id.lowercased() ?? "guest" }
    private var pendingKey: String { "pending-purchase-\(userKey)" }
    private var tradeKey: String { "pending-trade-\(userKey)" }
    init() { signedIn = auth.session != nil }
    func start() async {
        guard signedIn else { return }
        pendingPurchase = UserDefaults.standard.string(forKey: pendingKey)
        if let data = UserDefaults.standard.data(forKey: tradeKey) { pendingTrade = try? JSONDecoder().decode(TradeRequest.self, from: data) }
        await refresh()
        await preparePurchases()
    }
    func loggedIn() async { signedIn = true; showAuth = false; await start() }
    func refresh() async {
        guard signedIn, !marketLoading else { return }
        marketLoading = true; defer { marketLoading = false }
        do {
            portfolio = try await api.request("state")
            for instrument in Content.instruments {
                if let quote: Quote = try? await api.request("quote?symbol=\(instrument.symbol)") { upsert(quote) }
            }
            reconcilePending()
        } catch { self.error = error.localizedDescription }
    }
    func refreshQuote(_ symbol: String) async throws -> Quote {
        guard signedIn else { throw AppError.message("Inicia sesión para obtener una cotización real.") }
        let q: Quote = try await api.request("quote?symbol=\(symbol)"); upsert(q); return q
    }
    private func upsert(_ q: Quote) { portfolio.quotes.removeAll { $0.symbol == q.symbol }; portfolio.quotes.append(q) }
    func trade(_ request: TradeRequest) async throws {
        guard !busy else { return }
        busy = true; defer { busy = false }
        pendingTrade = request
        UserDefaults.standard.set(try JSONEncoder().encode(request), forKey: tradeKey)
        do {
            portfolio = try await api.request("trade", method: "POST", body: JSONEncoder().encode(request))
            clearPendingTrade()
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } catch let problem as APIProblem {
            if ["STALE_QUOTE", "INSUFFICIENT_CASH", "INSUFFICIENT_UNITS", "MARKET_CLOSED", "QUOTE_UNAVAILABLE", "INVALID_INPUT"].contains(problem.error) { clearPendingTrade() }
            throw problem
        }
    }
    func retryTrade() async {
        guard let pendingTrade else { return }
        do { try await trade(pendingTrade); notice = "Operación confirmada. Tu cartera está actualizada." }
        catch { self.error = error.localizedDescription }
    }
    private func clearPendingTrade() { pendingTrade = nil; UserDefaults.standard.removeObject(forKey: tradeKey) }
    func complete(_ lesson: Lesson) async {
        guard !portfolio.completedLessons.contains(lesson.id) else { return }
        if !signedIn { portfolio.completedLessons.append(lesson.id); return }
        do {
            portfolio = try await api.request("lesson", method: "POST", body: JSONSerialization.data(withJSONObject: ["lessonId": lesson.id]))
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        } catch { self.error = error.localizedDescription }
    }
    private func preparePurchases() async {
        guard Configuration.purchasesConfigured else { return }
        do {
            if !Purchases.isConfigured { Purchases.configure(withAPIKey: Configuration.value("REVENUECAT_PUBLIC_KEY"), appUserID: userKey) }
            else { _ = try await Purchases.shared.logIn(userKey) }
            revenueCatReady = true
            let offerings = try await Purchases.shared.offerings()
            packages = (offerings["virtual-cash"]?.availablePackages ?? []).filter { ["ei.cash.10000", "ei.cash.25000"].contains($0.storeProduct.productIdentifier) }.sorted { $0.storeProduct.price < $1.storeProduct.price }
        } catch { notice = "Las recargas no están disponibles ahora. Puedes seguir con tu saldo inicial." }
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
        } catch { self.error = error.localizedDescription }
    }
    private func reconcilePending() {
        if let id = pendingPurchase, let receipt = portfolio.purchases.first(where: { $0.transactionId == id }), receipt.credited || receipt.refunded {
            pendingPurchase = nil; UserDefaults.standard.removeObject(forKey: pendingKey)
            notice = receipt.refunded ? "La compra ha sido reembolsada." : "Tu saldo virtual ya está disponible."
        }
        if let trade = pendingTrade, portfolio.orders.contains(where: { $0.requestId.lowercased() == trade.requestId.lowercased() }) { clearPendingTrade() }
    }
    func signOut() async {
        await auth.signOut()
        signedIn = false; portfolio = .empty; packages = []; pendingPurchase = nil; pendingTrade = nil; revenueCatReady = false
        if Purchases.isConfigured { _ = try? await Purchases.shared.logOut() }
    }
    func deleteAccount() async {
        struct Result: Decodable { let deleted: Bool }
        do { let _: Result = try await api.request("account", method: "DELETE"); await signOut() }
        catch { self.error = error.localizedDescription }
    }
}
