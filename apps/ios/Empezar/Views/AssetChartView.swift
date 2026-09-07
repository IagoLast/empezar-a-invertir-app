import SwiftUI
import Charts

private enum ChartStyle: String, CaseIterable { case line, candles
    var title: String { self == .line ? "Línea" : "Velas" }
}

struct PriceHistory: Decodable {
    let currency, source: String
    let points: [HistoryPoint]
}

struct HistoryPoint: Decodable, Identifiable {
    let date: String
    let open, high, low, close: Double
    var id: String { date }
    var timestamp: Date { ISO.date(date) ?? .distantPast }
}

private enum HistoryRange: String, CaseIterable {
    case week = "1w", month = "1m", quarter = "3m", year = "1y", fiveYears = "5y"
    var title: String {
        switch self {
        case .week: return "1 sem."
        case .month: return "1 mes"
        case .quarter: return "3 meses"
        case .year: return "1 año"
        case .fiveYears: return "5 años"
        }
    }
}

struct AssetChartView: View {
    let symbol: String
    var reloadID = 0
    @EnvironmentObject private var store: AppStore
    @State private var style = ChartStyle.line
    @State private var range = HistoryRange.month
    @State private var history: PriceHistory?
    @State private var loading = false
    @State private var issue: String?
    private var domain: ClosedRange<Double> {
        let low = history?.points.map(\.low).min() ?? 0
        let high = history?.points.map(\.high).max() ?? 1
        let padding = max((high - low) * 0.1, high * 0.005, 0.01)
        return max(0, low - padding)...(high + padding)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Histórico de precios").font(.headline)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(HistoryRange.allCases, id: \.self) { option in
                        Button { range = option } label: {
                            Text(option.title).font(.caption.weight(.semibold)).padding(.horizontal, 12).frame(minHeight: 44)
                                .foregroundStyle(range == option ? Color.white : Theme.muted)
                                .background(range == option ? Theme.button : Theme.pale, in: Capsule())
                        }.buttonStyle(.plain).accessibilityIdentifier("history-\(option.rawValue)")
                            .accessibilityAddTraits(range == option ? .isSelected : [])
                    }
                }
            }
            Picker("Tipo de gráfica", selection: $style) {
                ForEach(ChartStyle.allCases, id: \.self) { Text($0.title).tag($0) }
            }.pickerStyle(.segmented)
            if loading { ProgressView("Cargando histórico…").frame(maxWidth: .infinity, minHeight: 210) }
            else if let issue { Text(issue).font(.subheadline).foregroundStyle(Theme.muted).frame(minHeight: 120) }
            else if let history, !history.points.isEmpty {
                Chart(history.points) { point in
                    if style == .line {
                        LineMark(x: .value("Fecha", point.timestamp), y: .value("Precio", point.close)).foregroundStyle(Theme.accent)
                        if history.points.count == 1 {
                            PointMark(x: .value("Fecha", point.timestamp), y: .value("Precio", point.close)).foregroundStyle(Theme.accent)
                        }
                    } else {
                        RuleMark(x: .value("Fecha", point.timestamp), yStart: .value("Mínimo", point.low), yEnd: .value("Máximo", point.high))
                            .foregroundStyle(point.close >= point.open ? Theme.gain : Theme.loss)
                        RuleMark(x: .value("Fecha", point.timestamp), yStart: .value("Apertura", point.open), yEnd: .value("Cierre", point.close))
                            .lineStyle(StrokeStyle(lineWidth: 4)).foregroundStyle(point.close >= point.open ? Theme.gain : Theme.loss)
                    }
                }.chartYScale(domain: domain)
                    .chartXAxis { AxisMarks(values: .automatic(desiredCount: 3)) { _ in AxisValueLabel(format: .dateTime.day().month(.abbreviated)) } }
                    .chartYAxis { AxisMarks(position: .trailing, values: .automatic(desiredCount: 4)) }
                    .frame(height: 210).accessibilityIdentifier("asset-chart")
                    .accessibilityLabel("Histórico de \(symbol), \(range.title), en \(history.currency)")
                Text("\(history.currency) · \(history.source) · Precios históricos, no en tiempo real")
                    .font(.caption).foregroundStyle(Theme.muted)
            } else {
                ContentUnavailableView("Sin histórico disponible", systemImage: "chart.xyaxis.line", description: Text("Prueba con otro periodo."))
            }
        }.padding(20).dataCard()
            .task(id: "\(symbol):\(range.rawValue):\(reloadID)") { await load() }
    }
    private func load() async {
        loading = true; issue = nil; history = nil
        do {
            let encoded = symbol.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? symbol
            let result: PriceHistory = try await store.api.request("history?symbol=\(encoded)&range=\(range.rawValue)", authenticated: false)
            try Task.checkCancellation()
            history = result; loading = false
        } catch {
            guard !Task.isCancelled else { return }
            issue = "No hemos podido cargar el histórico. Desliza hacia abajo para volver a intentarlo."; loading = false
        }
    }
}
