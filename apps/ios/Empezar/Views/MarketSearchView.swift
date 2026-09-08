import SwiftUI

struct MarketSearchResult: Decodable, Identifiable {
    let symbol, name, kind, exchange: String
    var quoteAvailability: String? = nil
    var id: String { symbol }
    var category: SearchCategory { kind == "stock" ? .stocks : kind == "bond_etf" ? .bonds : .funds }
    static let suggestions: [MarketSearchResult] = [
        .init(symbol: "GOOGL", name: "Alphabet", kind: "stock", exchange: "NASDAQ"),
        .init(symbol: "META", name: "Meta Platforms", kind: "stock", exchange: "NASDAQ"),
        .init(symbol: "TSLA", name: "Tesla", kind: "stock", exchange: "NASDAQ"),
        .init(symbol: "NVDA", name: "NVIDIA", kind: "stock", exchange: "NASDAQ"),
        .init(symbol: "AMZN", name: "Amazon", kind: "stock", exchange: "NASDAQ"),
        .init(symbol: "ASML", name: "ASML", kind: "stock", exchange: "NASDAQ"),
        .init(symbol: "SPY", name: "SPDR S&P 500 ETF", kind: "etf", exchange: "NYSE Arca"),
        .init(symbol: "TSCO.LON", name: "Tesco", kind: "stock", exchange: "Londres"),
        .init(symbol: "ITX.MC", name: "Inditex · Industria de Diseño Textil", kind: "stock", exchange: "Madrid", quoteAvailability: "check_on_open"),
    ]
}
enum SearchCategory: String, CaseIterable, Identifiable {
    case stocks, funds, bonds
    var id: String { rawValue }
    var title: String {
        switch self {
        case .stocks: return "Acciones"
        case .funds: return "ETF y ETP"
        case .bonds: return "ETF de bonos"
        }
    }
}
struct MarketSearchResponse: Decodable {
    let results: [MarketSearchResult]
    var notice: String? = nil
}
struct MarketSearchRow: View {
    let asset: MarketSearchResult
    var quote: Quote? = nil
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: asset.kind != "stock" ? "square.stack.3d.up" : "building.2")
                .foregroundStyle(Theme.accent).frame(width: 46, height: 46).background(Theme.pale, in: RoundedRectangle(cornerRadius: 15))
            VStack(alignment: .leading, spacing: 5) {
                Text(asset.name).font(.body.weight(.semibold)).fixedSize(horizontal: false, vertical: true)
                Text("\(asset.symbol) · \(asset.exchange)").font(.caption).foregroundStyle(Theme.muted)
                if asset.quoteAvailability == "check_on_open" && quote == nil {
                    Text("Cotización según cobertura").font(.caption2).foregroundStyle(Theme.muted)
                }
            }.frame(maxWidth: .infinity, alignment: .leading)
            if let quote {
                VStack(alignment: .trailing, spacing: 5) {
                    Text(quote.nativePriceText).font(.subheadline.weight(.semibold))
                    Text(quote.changePercent / 100, format: .percent.precision(.fractionLength(2)))
                        .font(.caption).foregroundStyle(quote.changePercent >= 0 ? Theme.gain : Theme.loss)
                }
            } else { Image(systemName: "chevron.right").font(.caption).foregroundStyle(Theme.muted) }
        }.padding(.vertical, 15).contentShape(Rectangle())
    }
}

struct MarketSearchDetail: View {
    let asset: MarketSearchResult
    var body: some View {
        InstrumentView(instrument: .market(symbol: asset.symbol, name: asset.name, kind: asset.kind, exchange: asset.exchange))
    }
}
