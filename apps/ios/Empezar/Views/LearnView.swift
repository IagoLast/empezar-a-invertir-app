import SwiftUI

struct LearnView: View {
    @EnvironmentObject var store: AppStore
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 27) {
                Text("Un poco más claro.\nCada día.").font(.system(.largeTitle, design: .rounded)).padding(.top, 12)
                Text("Ideas pequeñas para tomar decisiones más conscientes.").font(.subheadline).foregroundStyle(Theme.muted).lineSpacing(4)
                HStack { Text("LOS FUNDAMENTOS").font(.caption).tracking(1.4); Spacer(); Text("\(store.portfolio.completedLessons.count) de 4").font(.caption) }
                ProgressView(value: Double(store.portfolio.completedLessons.count), total: 4).tint(Theme.accent).accessibilityLabel("Lecciones completadas")
                ForEach(Content.lessons) { lesson in
                    NavigationLink { LessonView(lesson: lesson) } label: {
                        VStack(alignment: .leading, spacing: 18) {
                            HStack { Text(lesson.number).font(.system(.title, design: .rounded)); Spacer(); Image(systemName: store.portfolio.completedLessons.contains(lesson.id) ? "checkmark.circle.fill" : lesson.icon).font(.title2) }
                            Text(lesson.title).font(.system(.title2, design: .rounded))
                            HStack { Text("\(lesson.minutes) min · \(lesson.subtitle)").font(.caption); Spacer(); Image(systemName: "arrow.right") }
                        }.padding(23).foregroundStyle(Theme.ink).background(Theme.surface, in: RoundedRectangle(cornerRadius: 25))
                    }.buttonStyle(.plain)
                }
                NavigationLink { ValuationView() } label: { ReadingCard(eyebrow: "Laboratorio", title: "¿Y cuánto vale?", text: "Cambia los supuestos. Observa cuánto cambia una valoración.", dark: true) }.buttonStyle(.plain)
            }.padding(24)
        }.appCanvas().navigationTitle("Aprender").navigationBarTitleDisplayMode(.inline)
    }
}
struct LessonView: View {
    let lesson: Lesson
    @EnvironmentObject var store: AppStore
    @State private var saving = false
    var completed: Bool { store.portfolio.completedLessons.contains(lesson.id) }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 27) {
                HStack { Pill(text: "Lección \(lesson.number)", icon: lesson.icon); Spacer(); Text("\(lesson.minutes) min").font(.caption).foregroundStyle(Theme.muted) }
                Text(lesson.title).font(.system(.largeTitle, design: .rounded))
                Text(lesson.subtitle).font(.title3).foregroundStyle(Theme.muted)
                ForEach(Array(lesson.paragraphs.enumerated()), id: \.offset) { _, paragraph in Text(paragraph).font(.body).lineSpacing(7).fixedSize(horizontal: false, vertical: true) }
                ReadingCard(eyebrow: "Quédate con esto", title: lesson.takeaway, text: lesson.exercise, dark: true)
                PrimaryButton(title: completed ? "Lección completada" : "Lo he entendido", icon: "checkmark", disabled: completed, loading: saving) {
                    Task { saving = true; await store.complete(lesson); saving = false }
                }
                if !store.signedIn { Text("Inicia sesión para guardar tu progreso entre dispositivos.").font(.caption).foregroundStyle(Theme.muted) }
            }.padding(25)
        }.appCanvas().navigationTitle("Los fundamentos").navigationBarTitleDisplayMode(.inline)
    }
}
struct ValuationView: View {
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
                Text("Un ejercicio de beneficio × múltiplo. No es una valoración completa ni una recomendación de compra.").font(.subheadline).foregroundStyle(Theme.muted).lineSpacing(4)
                VStack(alignment: .leading, spacing: 12) {
                    Text("Beneficio anual por acción estimado ($)").font(.subheadline)
                    TextField("Ejemplo: 5", text: $epsText).keyboardType(.decimalPad).textFieldStyle(.roundedBorder)
                    Text(initialEPS == nil ? "5 $ es un supuesto de ejemplo; no es un dato de una empresa." : "Partimos del BPA reportado. Cámbialo para explorar otros supuestos.").font(.caption).foregroundStyle(Theme.muted)
                }
                VStack(spacing: 12) { HStack { Text("Múltiplo PER asumido"); Spacer(); Text("\(Int(multiple))×").monospacedDigit() }; Slider(value: $multiple, in: 5...40, step: 1).accessibilityLabel("Múltiplo PER asumido") }
                VStack(spacing: 12) { HStack { Text("Margen de seguridad"); Spacer(); Text("\(Int(margin)) %").monospacedDigit() }; Slider(value: $margin, in: 0...50, step: 5).accessibilityLabel("Margen de seguridad") }
                ReadingCard(eyebrow: "Precio bajo estos supuestos", title: value.map { Money.text(Int64(($0 * 100).rounded())) } ?? "Revisa el beneficio", text: "Por acción, después del margen. Cambiar el crecimiento esperado, la deuda o la calidad del negocio puede cambiar mucho el resultado.", dark: true)
                Text("Para beneficios nulos o negativos este cálculo no es útil. No compara automáticamente el resultado con el precio de mercado.").font(.caption).foregroundStyle(Theme.muted)
            }.padding(24)
        }.appCanvas().navigationTitle("Laboratorio de valoración").navigationBarTitleDisplayMode(.inline)
            .onAppear { if let initialEPS, initialEPS > 0 { epsText = String(format: "%.2f", initialEPS) } }
    }
}
