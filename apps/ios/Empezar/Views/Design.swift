import SwiftUI

enum AppAppearance: String, CaseIterable, Identifiable {
    case light, dark, system
    var id: String { rawValue }
    var title: String {
        switch self { case .light: return "Claro"; case .dark: return "Oscuro"; case .system: return "Sistema" }
    }
    var colorScheme: ColorScheme? {
        switch self { case .light: return .light; case .dark: return .dark; case .system: return nil }
    }
}

enum Theme {
    static func adaptive(_ light: UInt32, _ dark: UInt32) -> Color {
        Color(UIColor { trait in
            let value = trait.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: CGFloat((value >> 16) & 255) / 255, green: CGFloat((value >> 8) & 255) / 255, blue: CGFloat(value & 255) / 255, alpha: 1)
        })
    }
    static let paper = adaptive(0xF5F6F8, 0x0C1017)
    static let surface = adaptive(0xFFFFFF, 0x181E28)
    static let ink = adaptive(0x15213B, 0xF1F5FF)
    static let muted = adaptive(0x596A84, 0xACB9CF)
    static let line = adaptive(0xDDE7F5, 0x2B3850)
    static let pale = adaptive(0xEAF1FF, 0x1D2C47)
    static let accent = adaptive(0x165DDE, 0x80B2FF)
    static let button = Color(red: 0.09, green: 0.34, blue: 0.88)
    static let gain = adaptive(0x087C60, 0x63DDB9)
    static let loss = adaptive(0xBD3349, 0xFF93A5)
}

private struct AppCanvas: ViewModifier {
    func body(content: _ViewModifier_Content<Self>) -> some View {
        content.background(Theme.paper.ignoresSafeArea()).foregroundStyle(Theme.ink)
    }
}

private struct FlatControl: ViewModifier {
    var radius: CGFloat
    func body(content: _ViewModifier_Content<Self>) -> some View {
        content.background(Theme.surface, in: RoundedRectangle(cornerRadius: radius))
            .overlay { RoundedRectangle(cornerRadius: radius).strokeBorder(Theme.line, lineWidth: 1) }
    }
}

private struct PressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: ButtonStyleConfiguration) -> some View {
        configuration.label.opacity(configuration.isPressed ? 0.8 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct PrimaryButton: View {
    let title: String
    var icon = "arrow.right"
    var disabled = false
    var loading = false
    var backgroundColor: Color = Theme.button
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Spacer(minLength: 0)
                if loading { ProgressView().tint(.white) }
                Text(title).font(.body.weight(.semibold)).multilineTextAlignment(.center)
                if !loading { Image(systemName: icon).font(.subheadline.weight(.semibold)) }
                Spacer(minLength: 0)
            }.padding(.horizontal, 18).padding(.vertical, 18)
                .foregroundStyle(.white).background(backgroundColor, in: RoundedRectangle(cornerRadius: 16))
        }.buttonStyle(PressStyle()).disabled(disabled || loading).opacity(disabled ? 0.45 : 1)
    }
}

struct Pill: View {
    let text: String
    var icon = "circle.fill"
    var body: some View {
        Label(text, systemImage: icon).font(.caption.weight(.semibold))
            .padding(.horizontal, 11).padding(.vertical, 8)
            .foregroundStyle(Theme.accent).background(Theme.pale, in: Capsule())
    }
}

struct SectionHeading: View {
    let title: String
    var detail: String? = nil
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.title3.weight(.bold)); Spacer(minLength: 8)
            if let detail { Text(detail).font(.caption).foregroundStyle(Theme.muted) }
        }.foregroundStyle(Theme.ink)
    }
}

struct AssetMark: View {
    @EnvironmentObject private var store: AppStore
    @State private var fetchedLogo: String?
    private struct LogoResponse: Decodable { let symbol: String; let logoURL: String? }
    private func trustedURL(_ value: String?) -> URL? {
        guard let value, let url = URL(string: value), url.scheme == "https",
              ["static.finnhub.io", "static2.finnhub.io"].contains(url.host ?? "") else { return nil }
        return url
    }
    let instrument: Instrument
    var large = false
    var logoURL: String? = nil
    var body: some View {
        Group {
            if let url = trustedURL(logoURL) ?? trustedURL(fetchedLogo) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFit().padding(large ? 12 : 8)
                    } else { fallback }
                }
            } else { fallback }
        }.foregroundStyle(Theme.accent).frame(width: large ? 72 : 46, height: large ? 72 : 46)
            .background(Theme.pale, in: RoundedRectangle(cornerRadius: large ? 24 : 15))
            .overlay { RoundedRectangle(cornerRadius: large ? 24 : 15).strokeBorder(Theme.accent.opacity(0.08)) }
            .accessibilityHidden(true)
            .task(id: instrument.symbol) {
                fetchedLogo = nil
                guard trustedURL(logoURL) == nil else { return }
                let encoded = instrument.symbol.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? instrument.symbol
                if let result: LogoResponse = try? await store.api.request("company-logo?symbol=\(encoded)", authenticated: false),
                   !Task.isCancelled, result.symbol == instrument.symbol { fetchedLogo = result.logoURL }
            }
    }
    @ViewBuilder private var fallback: some View {
        Image(systemName: instrument.kind == "bond_etf" ? "doc.text" : instrument.kind == "stock" ? "building.2" : "square.stack.3d.up")
            .font(.system(size: large ? 28 : 20, weight: .medium))
    }

}

struct ChangeLabel: View {
    var percent: Double
    var body: some View {
        Label((percent > 0 ? "+" : "") + percent.formatted(.number.precision(.fractionLength(2))) + " %",
              systemImage: percent < 0 ? "arrow.down.right" : percent > 0 ? "arrow.up.right" : "minus")
            .font(.caption.weight(.semibold)).monospacedDigit()
            .foregroundStyle(percent < 0 ? Theme.loss : percent > 0 ? Theme.gain : Theme.muted)
    }
}

struct AssetRow: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let instrument: Instrument
    var quote: Quote?
    var units: Int? = nil
    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 12) {
                    identity
                    price.frame(maxWidth: .infinity, alignment: .trailing)
                }
            } else {
                HStack(spacing: 12) {
                    identity.frame(maxWidth: .infinity, alignment: .leading)
                    price.fixedSize(horizontal: true, vertical: false)
                }
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 15).contentShape(Rectangle())
    }
    private var identity: some View {
        HStack(spacing: 12) {
            AssetMark(instrument: instrument, logoURL: quote?.logoURL)
            VStack(alignment: .leading, spacing: 5) {
                Text(instrument.name).font(.body.weight(.semibold)).foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text(units.map { "\($0) unidades · \(instrument.symbol)" } ?? "\(instrument.symbol) · \(instrument.category)")
                    .font(.caption).foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
    private var price: some View {
        VStack(alignment: .trailing, spacing: 6) {
            Text(quote.map { store.money.text($0.priceCents * Int64(units ?? 1)) } ?? "—")
                .font(.body.weight(.semibold)).monospacedDigit().foregroundStyle(Theme.ink)
            if let quote { ChangeLabel(percent: quote.changePercent) }
            else { Text("Precio no disponible").font(.caption).foregroundStyle(Theme.muted) }
        }
    }
}

struct ReadingCard: View {
    let eyebrow, title, text: String
    var dark = false
    var concept: LearningConcept = .learning
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ConceptLabel(title: eyebrow, concept: concept).font(.caption.weight(.semibold))
            Text(title).font(.title2.weight(.semibold))
            Text(text).font(.subheadline).lineSpacing(4).foregroundStyle(Theme.muted)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(22)
            .background(dark ? Theme.pale : Theme.surface, in: RoundedRectangle(cornerRadius: 24))
            .overlay { RoundedRectangle(cornerRadius: 24).strokeBorder(Theme.line.opacity(0.7)) }
    }
}

extension View {
    func appCanvas() -> some View { modifier(AppCanvas()) }
    func flatControl(radius: CGFloat = 18) -> some View { modifier(FlatControl(radius: radius)) }
    func dataCard() -> some View {
        frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 24))
            .overlay { RoundedRectangle(cornerRadius: 24).strokeBorder(Theme.line.opacity(0.3)) }
    }
}

struct AmountField: View {
    let title: String
    @Binding var value: String
    var unit = "USD"
    var identifier: String
    @FocusState private var focused: Bool
    @ScaledMetric(relativeTo: .largeTitle) private var amountFontSize = 38.0
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.subheadline).foregroundStyle(Theme.muted)
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                TextField("0", text: $value).keyboardType(.decimalPad).textFieldStyle(.plain).focused($focused)
                    .font(.system(size: amountFontSize, weight: .semibold, design: .rounded)).monospacedDigit()
                    .minimumScaleFactor(0.6).accessibilityLabel(title).accessibilityIdentifier(identifier)
                Text(unit).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.muted)
            }
            Rectangle().fill(focused ? Theme.accent : Theme.line).frame(height: focused ? 2 : 1)
        }.padding(20).dataCard()
            .toolbar { ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Listo") { focused = false } } }
    }
}

struct ChoiceRow: View {
    let title: String
    let subtitle: String
    let icon: String
    var selected = false
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon).font(.title3).foregroundStyle(Theme.accent)
                    .frame(width: 44, height: 44).background(Theme.pale, in: Circle())
                VStack(alignment: .leading, spacing: 6) {
                    Text(title).font(.body.weight(.semibold)).foregroundStyle(Theme.ink)
                    Text(subtitle).font(.subheadline).foregroundStyle(Theme.muted).fixedSize(horizontal: false, vertical: true)
                }.frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: selected ? "checkmark.circle.fill" : "circle").font(.title2)
                    .foregroundStyle(selected ? Theme.accent : Theme.line)
            }.frame(minHeight: 62).contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityAddTraits(selected ? .isSelected : [])
    }
}
