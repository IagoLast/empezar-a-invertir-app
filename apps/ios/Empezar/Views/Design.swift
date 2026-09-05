import SwiftUI

enum Theme {
    static func adaptive(_ light: UInt32, _ dark: UInt32) -> Color {
        Color(UIColor { trait in
            let value = trait.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: CGFloat((value >> 16) & 255)/255, green: CGFloat((value >> 8) & 255)/255, blue: CGFloat(value & 255)/255, alpha: 1)
        })
    }
    static let paper = adaptive(0xF7F7F0, 0x131B17)
    static let surface = adaptive(0xFFFFFF, 0x1D2821)
    static let ink = adaptive(0x203C30, 0xEDF2E8)
    static let muted = adaptive(0x637065, 0xAFB9AD)
    static let line = adaptive(0xE2E6DB, 0x34443A)
    static let pale = adaptive(0xEBEFE5, 0x2A382E)
    static let forest = Color(red: 0.12, green: 0.25, blue: 0.19)
    static let lime = Color(red: 0.83, green: 0.92, blue: 0.58)
    static let loss = adaptive(0xA44834, 0xF5AD95)
}
struct PrimaryButton: View {
    let title: String
    var icon = "arrow.right"
    var disabled = false
    var loading = false
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack {
                Text(title).font(.body.weight(.semibold))
                Spacer(minLength: 10)
                if loading { ProgressView().tint(Theme.lime) } else { Image(systemName: icon) }
            }.padding(20).foregroundStyle(Theme.lime).background(Theme.forest, in: RoundedRectangle(cornerRadius: 20))
        }.buttonStyle(.plain).disabled(disabled || loading).opacity(disabled ? 0.45 : 1)
    }
}
struct Pill: View {
    let text: String
    var icon = "circle.fill"
    var body: some View {
        Label(text, systemImage: icon).font(.caption.weight(.medium)).padding(.horizontal, 11).padding(.vertical, 7)
            .foregroundStyle(Theme.ink).background(Theme.pale, in: Capsule())
    }
}
struct SectionHeading: View {
    let title: String
    var detail: String? = nil
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.title3.weight(.semibold)); Spacer()
            if let detail { Text(detail).font(.caption).foregroundStyle(Theme.muted) }
        }.foregroundStyle(Theme.ink)
    }
}
struct AssetMark: View {
    let instrument: Instrument
    var large = false
    var body: some View {
        Text(instrument.monogram).font(.system(size: large ? 38 : 25, weight: .medium, design: .serif))
            .foregroundStyle(Theme.ink).frame(width: large ? 76 : 48, height: large ? 76 : 48)
            .background(Theme.pale, in: RoundedRectangle(cornerRadius: large ? 25 : 16))
            .accessibilityHidden(true)
    }
}
struct AssetRow: View {
    let instrument: Instrument
    var quote: Quote?
    var units: Int? = nil
    var body: some View {
        HStack(spacing: 13) {
            AssetMark(instrument: instrument)
            VStack(alignment: .leading, spacing: 5) {
                Text(instrument.name).font(.body.weight(.medium)).foregroundStyle(Theme.ink)
                Text(units.map { "\($0) unidades · \(instrument.symbol)" } ?? "\(instrument.symbol) · \(instrument.category)").font(.caption).foregroundStyle(Theme.muted)
            }
            Spacer(minLength: 6)
            VStack(alignment: .trailing, spacing: 5) {
                Text(quote.map { Money.text($0.priceCents * Int64(units ?? 1)) } ?? "—").font(.body.weight(.medium)).monospacedDigit().foregroundStyle(Theme.ink)
                if let quote {
                    Text(quote.changePercent.formatted(.number.precision(.fractionLength(2))) + " %").font(.caption).monospacedDigit().foregroundStyle(quote.changePercent < 0 ? Theme.loss : Theme.ink)
                } else { Text("Sin cotización").font(.caption).foregroundStyle(Theme.muted) }
            }
        }.padding(.vertical, 12).contentShape(Rectangle())
    }
}
struct ReadingCard: View {
    let eyebrow, title, text: String
    var dark = false
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(eyebrow.uppercased()).font(.caption.weight(.medium)).tracking(1.3)
            Text(title).font(.system(.title2, design: .serif))
            Text(text).font(.subheadline).lineSpacing(4).opacity(0.85)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(23)
            .foregroundStyle(dark ? Theme.lime : Theme.ink)
            .background(dark ? Theme.forest : Theme.surface, in: RoundedRectangle(cornerRadius: 26))
    }
}
struct OrbitMark: View {
    var body: some View {
        ZStack {
            ForEach(0..<3) { i in
                Ellipse().stroke(Theme.lime.opacity(0.7), lineWidth: 1.3)
                    .frame(width: 130, height: 190).rotationEffect(.degrees(Double(i) * 60))
            }
            Circle().fill(Theme.lime).frame(width: 20, height: 20)
        }.frame(width: 210, height: 210).accessibilityHidden(true)
    }
}
extension View {
    func appCanvas() -> some View { self.background(Theme.paper).foregroundStyle(Theme.ink) }
}
