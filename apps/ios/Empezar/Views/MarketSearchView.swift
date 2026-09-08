import SwiftUI

struct MarketSearchResult: Decodable, Identifiable {
    let symbol, name, kind, exchange: String
    var quoteAvailability: String? = nil
    var id: String { symbol }
    var category: SearchCategory { kind == "stock" ? .stocks : kind == "bond_etf" ? .bonds : .funds }
    static func ranked(_ results: [MarketSearchResult], query: String) -> [MarketSearchResult] {
        func normalized(_ value: String) -> String {
            value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
        }
        let term = normalized(query.trimmingCharacters(in: .whitespacesAndNewlines))
        guard !term.isEmpty else { return results }
        func score(_ row: MarketSearchResult) -> Int {
            let symbol = normalized(row.symbol), name = normalized(row.name)
            if symbol == term { return 0 }
            if symbol.split(separator: ".").first.map(String.init) == term { return 1 }
            if name == term { return 2 }
            if name.hasPrefix(term) { return 3 }
            return 4
        }
        return results.enumerated().sorted {
            let left = score($0.element), right = score($1.element)
            return left == right ? $0.offset < $1.offset : left < right
        }.map(\.element)
    }

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
            AssetMark(instrument: .market(symbol: asset.symbol, name: asset.name, kind: asset.kind), logoURL: quote?.logoURL)
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
