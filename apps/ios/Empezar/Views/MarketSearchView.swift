import SwiftUI

struct MarketSearchResult: Decodable, Identifiable {
    let symbol, name, kind, exchange: String
    var id: String { symbol }
    static let suggestions: [MarketSearchResult] = [
        .init(symbol: "GOOGL", name: "Alphabet", kind: "stock", exchange: "NASDAQ"),
        .init(symbol: "META", name: "Meta Platforms", kind: "stock", exchange: "NASDAQ"),
        .init(symbol: "TSLA", name: "Tesla", kind: "stock", exchange: "NASDAQ"),
        .init(symbol: "NVDA", name: "NVIDIA", kind: "stock", exchange: "NASDAQ"),
        .init(symbol: "AMZN", name: "Amazon", kind: "stock", exchange: "NASDAQ"),
        .init(symbol: "ASML", name: "ASML", kind: "stock", exchange: "NASDAQ"),
        .init(symbol: "SPY", name: "SPDR S&P 500 ETF", kind: "etf", exchange: "NYSE Arca"),
    ]
}
struct MarketSearchResponse: Decodable {
    let results: [MarketSearchResult]
    var notice: String? = nil
}
struct MarketSearchRow: View {
    let asset: MarketSearchResult
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: asset.kind == "etf" ? "square.stack.3d.up" : "building.2")
                .foregroundStyle(Theme.accent).frame(width: 46, height: 46).background(Theme.pale, in: RoundedRectangle(cornerRadius: 15))
            VStack(alignment: .leading, spacing: 5) {
                Text(asset.name).font(.body.weight(.semibold)).fixedSize(horizontal: false, vertical: true)
                Text("\(asset.symbol) · \(asset.exchange)").font(.caption).foregroundStyle(Theme.muted)
            }.frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(Theme.muted)
        }.padding(.vertical, 15).contentShape(Rectangle())
    }
}

struct MarketSearchDetail: View {
    let asset: MarketSearchResult
    var body: some View {
        InstrumentView(instrument: .market(symbol: asset.symbol, name: asset.name, kind: asset.kind, exchange: asset.exchange))
    }
}
