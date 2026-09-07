import SwiftUI

struct OnboardingView: View {
    var complete: (Bool) -> Void
    @State private var page = 0

    private let pages = [
        OnboardingPage(
            icon: "chart.line.uptrend.xyaxis",
            eyebrow: "APRENDE SIN ARRIESGAR",
            title: "Aprende a invertir con dinero ficticio.",
            text: "Empieza con 10.000 US$ virtuales y practica las decisiones que tomarías en el mercado real.",
            points: ["Practica sin comprar activos reales", "Compra acciones y ETF", "Avanza a tu propio ritmo"]
        ),
        OnboardingPage(
            icon: "building.columns",
            eyebrow: "MERCADO REAL",
            title: "Entiende qué estás comprando.",
            text: "Explora empresas y fondos conocidos. Consulta precios de mercado reales antes de cada operación simulada.",
            points: ["Aprende a interpretar los precios", "Riesgo y contexto de cada activo", "Explicaciones junto a cada concepto"]
        ),
        OnboardingPage(
            icon: "book.closed",
            eyebrow: "APRENDER HACIENDO",
            title: "Construye criterio, no solo una cartera.",
            text: "Sigue el resultado de tus decisiones y completa lecciones breves sobre acciones, ETF, bonos y valoración.",
            points: ["Cartera y movimientos claros", "Lecciones cortas y prácticas", "Laboratorio de valoración"]
        )
    ]

    var body: some View {
        VStack(spacing: 0) {
            header
            TabView(selection: $page) {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, item in
                    OnboardingPageView(page: item).tag(index)
                }
                paywall.tag(pages.count)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            footer
        }
        .appCanvas()
    }

    private var header: some View {
        HStack {
            HStack(spacing: 9) {
                Image(systemName: "chart.line.uptrend.xyaxis").foregroundStyle(Theme.accent)
                Text("empezar").font(.headline.weight(.bold))
            }
            Spacer()
            Button("Saltar") { complete(false) }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.muted)
                .frame(minWidth: 60, minHeight: 44)
                .accessibilityIdentifier("skip-onboarding")
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
    }

    private var footer: some View {
        VStack(spacing: 16) {
            HStack(spacing: 7) {
                ForEach(0...pages.count, id: \.self) { index in
                    Capsule().fill(index == page ? Theme.accent : Theme.line)
                        .frame(width: index == page ? 24 : 7, height: 7)
                }
            }
            if page < pages.count {
                PrimaryButton(title: "Siguiente") {
                    withAnimation(.easeInOut(duration: 0.22)) { page += 1 }
                }
            } else {
                PrimaryButton(title: "Crear mi cuenta", icon: "person.crop.circle.badge.plus") { complete(true) }
                Button("Explorar la app") { complete(false) }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.muted)
                    .frame(minHeight: 44)
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
    }

    private var paywall: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Image(systemName: "sparkles")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 62, height: 62)
                    .background(Theme.pale, in: RoundedRectangle(cornerRadius: 18))
                VStack(alignment: .leading, spacing: 12) {
                    Text("EMPIEZA A PRACTICAR").font(.caption.weight(.bold)).foregroundStyle(Theme.accent).tracking(1.2)
                    Text("10.000 US$ virtuales para empezar.")
                        .font(.system(.largeTitle, design: .rounded).weight(.bold))
                    Text(Configuration.freePreviewEnabled ? "Crea tu cuenta para guardar tu cartera y tu progreso. Ahora puedes acceder gratis a las lecciones y al simulador." : "Empezar Plus incluye las lecciones y el simulador con un plan mensual. Las recargas de saldo virtual se compran por separado.")
                        .foregroundStyle(Theme.muted).lineSpacing(4)
                }
                VStack(spacing: 0) {
                    offerRow(icon: "gift", title: "Incluido", detail: "10.000 US$ virtuales de bienvenida")
                    Divider().overlay(Theme.line)
                    offerRow(icon: "building.2", title: "Explora", detail: "Conoce una empresa y sus riesgos")
                    Divider().overlay(Theme.line)
                    offerRow(icon: "book.closed", title: "Aprende", detail: "Empieza por la primera lección")
                }
                .padding(.horizontal, 20)
                .dataCard()
                Text("Puedes explorar los activos y leer las lecciones antes de crear tu cuenta. El saldo de práctica es ficticio y no se puede retirar.")
                    .font(.caption).foregroundStyle(Theme.muted).lineSpacing(3)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 22)
        }
    }

    private func offerRow(icon: String, title: String, detail: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon).foregroundStyle(Theme.accent).frame(width: 24)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(detail).font(.caption).foregroundStyle(Theme.muted)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 17)
    }
}

private struct OnboardingPage {
    let icon, eyebrow, title, text: String
    let points: [String]
}

private struct OnboardingPageView: View {
    let page: OnboardingPage
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                Spacer(minLength: 10)
                Image(systemName: page.icon)
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 72, height: 72)
                    .background(Theme.pale, in: RoundedRectangle(cornerRadius: 20))
                VStack(alignment: .leading, spacing: 14) {
                    Text(page.eyebrow).font(.caption.weight(.bold)).foregroundStyle(Theme.accent).tracking(1.2)
                    Text(page.title).font(.system(.largeTitle, design: .rounded).weight(.bold))
                    Text(page.text).foregroundStyle(Theme.muted).lineSpacing(4)
                }
                VStack(alignment: .leading, spacing: 18) {
                    ForEach(page.points, id: \.self) { point in
                        Label(point, systemImage: "checkmark.circle.fill")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Theme.ink)
                    }
                }
                .padding(22)
                .frame(maxWidth: .infinity, alignment: .leading)
                .dataCard()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 22)
        }
    }
}
