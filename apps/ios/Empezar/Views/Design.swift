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
    static let paper = adaptive(0xF6F9FF, 0x0B1120)
    static let surface = adaptive(0xFFFFFF, 0x151E30)
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
        content.background {
            ZStack(alignment: .topTrailing) {
                Theme.paper
                RadialGradient(colors: [Theme.accent.opacity(0.09), .clear], center: .topTrailing, startRadius: 10, endRadius: 450)
            }.ignoresSafeArea()
        }.foregroundStyle(Theme.ink)
    }
}

// Keep glass in the control layer; data surfaces stay legible.
private struct GlassControl: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    var radius: CGFloat
    @ViewBuilder func body(content: _ViewModifier_Content<Self>) -> some View {
        if reduceTransparency {
            content.background(Theme.surface, in: RoundedRectangle(cornerRadius: radius))
                .overlay { RoundedRectangle(cornerRadius: radius).strokeBorder(Theme.line, lineWidth: 1) }
        } else { platformGlass(content) }
    }
    @ViewBuilder private func platformGlass(_ content: _ViewModifier_Content<Self>) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            content.glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: radius))
        } else { legacyGlass(content) }
        #else
        legacyGlass(content)
        #endif
    }
    private func legacyGlass(_ content: _ViewModifier_Content<Self>) -> some View {
        content.background(.regularMaterial, in: RoundedRectangle(cornerRadius: radius))
            .overlay {
                RoundedRectangle(cornerRadius: radius).strokeBorder(
                    LinearGradient(colors: [Theme.surface.opacity(0.9), Theme.line.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
            }.shadow(color: Theme.accent.opacity(0.06), radius: 12, y: 5)
    }
}

private struct PressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: ButtonStyleConfiguration) -> some View {
        configuration.label.opacity(configuration.isPressed ? 0.8 : 1)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct PrimaryButton: View {
    let title: String
    var icon = "arrow.right"
    var disabled = false
    var loading = false
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
                .foregroundStyle(.white).background(Theme.button.gradient, in: RoundedRectangle(cornerRadius: 20))
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
    let instrument: Instrument
    var large = false
    var body: some View {
        Group {
            if instrument.symbol == "AAPL" {
                Image(systemName: "apple.logo").font(.system(size: large ? 34 : 23, weight: .medium))
            } else {
                Text(instrument.monogram).font(.system(size: large ? 28 : 20, weight: .bold, design: .rounded))
            }
        }.foregroundStyle(Theme.accent).frame(width: large ? 72 : 46, height: large ? 72 : 46)
            .background(Theme.pale.gradient, in: RoundedRectangle(cornerRadius: large ? 24 : 15))
            .overlay { RoundedRectangle(cornerRadius: large ? 24 : 15).strokeBorder(Theme.accent.opacity(0.08)) }
            .accessibilityHidden(true)
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
    let instrument: Instrument
    var quote: Quote?
    var units: Int? = nil
    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) { identity; Spacer(minLength: 10); price }
            VStack(alignment: .leading, spacing: 12) { identity; price }
        }.padding(.vertical, 15).contentShape(Rectangle())
    }
    private var identity: some View {
        HStack(spacing: 12) {
            AssetMark(instrument: instrument)
            VStack(alignment: .leading, spacing: 5) {
                Text(instrument.name).font(.body.weight(.semibold)).foregroundStyle(Theme.ink)
                Text(units.map { "\($0) unidades · \(instrument.symbol)" } ?? "\(instrument.symbol) · \(instrument.category)")
                    .font(.caption).foregroundStyle(Theme.muted)
            }
        }
    }
    private var price: some View {
        VStack(alignment: .trailing, spacing: 6) {
            Text(quote.map { Money.text($0.priceCents * Int64(units ?? 1)) } ?? "—")
                .font(.body.weight(.semibold)).monospacedDigit().foregroundStyle(Theme.ink)
            if let quote { ChangeLabel(percent: quote.changePercent) }
            else { Text("Sin cotización").font(.caption).foregroundStyle(Theme.muted) }
        }
    }
}

struct ReadingCard: View {
    let eyebrow, title, text: String
    var dark = false
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(eyebrow).font(.caption.weight(.semibold)).foregroundStyle(Theme.accent)
            Text(title).font(.title2.weight(.semibold))
            Text(text).font(.subheadline).lineSpacing(4).foregroundStyle(Theme.muted)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(22)
            .background(dark ? Theme.pale : Theme.surface, in: RoundedRectangle(cornerRadius: 24))
            .overlay { RoundedRectangle(cornerRadius: 24).strokeBorder(Theme.line.opacity(0.7)) }
    }
}

extension View {
    func appCanvas() -> some View { modifier(AppCanvas()) }
    func glassControl(radius: CGFloat = 22) -> some View { modifier(GlassControl(radius: radius)) }
    func dataCard() -> some View {
        background(Theme.surface, in: RoundedRectangle(cornerRadius: 26))
            .overlay { RoundedRectangle(cornerRadius: 26).strokeBorder(Theme.line.opacity(0.65)) }
            .shadow(color: Theme.accent.opacity(0.035), radius: 18, y: 8)
    }
}
