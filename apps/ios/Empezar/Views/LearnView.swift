import SwiftUI

struct ValuationView: View {
    @EnvironmentObject private var store: AppStore
    var initialEPS: Double? = nil
    @State private var epsText = "5"
    @State private var multiple = 20.0
    @State private var margin = 20.0
    var eps: Double? { Double(epsText.replacingOccurrences(of: ",", with: ".")) }
    var value: Double? { guard let eps, eps.isFinite, eps > 0, eps <= 10000 else { return nil }; return eps * multiple * (1 - margin / 100) }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 27) {
                Pill(text: "Tus supuestos", icon: "slider.horizontal.3")
                Text("El valor depende\nde lo que asumes.").font(.system(.largeTitle, design: .rounded))
                Text("Prueba cómo cambian las estimaciones al cambiar los beneficios y el PER. El resultado es un ejercicio, no un precio recomendado de compra.").font(.subheadline).foregroundStyle(Theme.muted).lineSpacing(4)
                VStack(alignment: .leading, spacing: 12) {
                    ConceptLabel(title: "Beneficio anual por acción (\(store.displayCurrency))", concept: .eps).font(.subheadline)
                    AmountField(title: "Beneficio por acción", value: $epsText, unit: store.displayCurrency, identifier: "valuation-eps")
                    Text(initialEPS == nil ? "5 \(store.displayCurrency) es un supuesto de ejemplo; no es un dato de una empresa." : "Partimos del BPA reportado. Cámbialo para explorar otros supuestos.").font(.caption).foregroundStyle(Theme.muted)
                }
                VStack(spacing: 12) { HStack { ConceptLabel(title: "PER estimado", concept: .pe); Spacer(); Text("\(Int(multiple))×").monospacedDigit() }; Slider(value: $multiple, in: 5...40, step: 1).tint(Theme.accent).accessibilityLabel("Múltiplo PER asumido") }.padding(20).dataCard()
                VStack(spacing: 12) { HStack { ConceptLabel(title: "Margen de seguridad", concept: .safetyMargin); Spacer(); Text("\(Int(margin)) %").monospacedDigit() }; Slider(value: $margin, in: 0...50, step: 5).tint(Theme.accent).accessibilityLabel("Margen de seguridad") }.padding(20).dataCard()
                ReadingCard(eyebrow: "Precio bajo estos supuestos", title: value.map { $0.formatted(.currency(code: store.displayCurrency).locale(Locale(identifier: "es_ES"))) } ?? "Revisa el beneficio", text: "Por acción, después del margen. Cambiar el crecimiento esperado, la deuda o la calidad del negocio puede cambiar mucho el resultado.", dark: true, concept: .safetyMargin)
                Text("Para beneficios nulos o negativos este cálculo no es útil. No compara automáticamente el resultado con el precio de mercado.").font(.caption).foregroundStyle(Theme.muted)
            }.frame(maxWidth: .infinity, alignment: .leading).padding(20)
        }.scrollDismissesKeyboard(.interactively).appCanvas().navigationTitle("Laboratorio de valoración").navigationBarTitleDisplayMode(.inline)
            .onAppear { if let initialEPS, initialEPS > 0 { epsText = store.money.inputText(Int64((initialEPS * 100).rounded())) } }
    }
}
