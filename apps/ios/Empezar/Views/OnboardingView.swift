import SwiftUI

struct OnboardingView: View {
    var complete: () -> Void
    @State private var page = 0
    @Environment(\.colorScheme) private var colorScheme

    private let pages = [
        IntroductionPage(title: "Aprende a invertir", text: "Entiende tu dinero y gana confianza para tomar tus propias decisiones. Todo empieza por aprender.", symbol: "sparkles", imageName: "IntroductionLearning"),
        IntroductionPage(title: "La bolsa no es complicada", text: "Acciones, riesgo, volatilidad… Descubre los conceptos básicos con explicaciones sencillas y ejemplos que puedes poner en práctica.", symbol: "lightbulb", imageName: "IntroductionBasics"),
        IntroductionPage(title: "Este es tu primer paso", text: "Aprende a tu ritmo y prueba lo que descubres con dinero ficticio. No necesitas saber de bolsa para empezar.", symbol: "figure.walk", imageName: "IntroductionSteps")
    ]

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $page) {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, item in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 28) {
                            if let imageName = item.imageName {
                                Group {
                                    if colorScheme == .dark {
                                        Image(imageName).resizable().scaledToFit()
                                            .colorInvert().blendMode(.screen)
                                    } else {
                                        Image(imageName).resizable().scaledToFit()
                                            .blendMode(.multiply)
                                    }
                                }.frame(maxWidth: .infinity).frame(height: 280).accessibilityHidden(true)
                            } else {
                                IntroductionArtworkPlaceholder(symbol: item.symbol)
                            }
                            Text(item.title)
                                .font(.system(.largeTitle, design: .rounded).weight(.bold))
                                .accessibilityIdentifier("introduction-title-\(index)")
                            Text(item.text).font(.body).foregroundStyle(Theme.muted).lineSpacing(5)
                        }.padding(.horizontal, 28).padding(.top, 28).padding(.bottom, 20)
                    }.tag(index)
                }
            }.tabViewStyle(.page(indexDisplayMode: .never))
            VStack(spacing: 24) {
                HStack(spacing: 8) {
                    ForEach(pages.indices, id: \.self) { index in
                        Capsule().fill(index == page ? Theme.accent : Theme.line)
                            .frame(width: index == page ? 28 : 8, height: 6)
                    }
                }.accessibilityLabel("Paso \(page + 1) de 3")
                PrimaryButton(title: "Siguiente") {
                    if page == pages.count - 1 { complete() }
                    else { withAnimation(.easeInOut(duration: 0.25)) { page += 1 } }
                }.accessibilityIdentifier("introduction-next")
            }.padding(.horizontal, 28).padding(.bottom, 20).padding(.top, 16)
        }.appCanvas()
    }
}

private struct IntroductionPage {
    let title, text, symbol: String
    var imageName: String? = nil
}

// Replace this view with the final illustrations without changing the page layout.
struct IntroductionArtworkPlaceholder: View {
    let symbol: String
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 36).fill(Theme.pale)
            Circle().fill(Theme.surface.opacity(0.65)).frame(width: 160, height: 160)
            Image(systemName: symbol).font(.system(size: 56, weight: .light)).foregroundStyle(Theme.accent.opacity(0.65))
            RoundedRectangle(cornerRadius: 36).strokeBorder(Theme.accent.opacity(0.15), style: StrokeStyle(lineWidth: 1, dash: [6, 6]))
        }.frame(height: 280).accessibilityHidden(true)
    }
}
