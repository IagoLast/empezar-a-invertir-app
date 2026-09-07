import SwiftUI

enum PurchaseOrderType: String, CaseIterable, Identifiable {
    case market, limit
    var id: String { rawValue }
    var title: String { self == .market ? "Compra a mercado" : "Orden de compra limitada" }
    var subtitle: String {
        self == .market ? "Compra al precio disponible después de revisar y confirmar." : "Tú eliges el precio máximo. La compra puede quedarse pendiente."
    }
    var icon: String { self == .market ? "bolt.fill" : "slider.horizontal.3" }
    var concept: LearningConcept { self == .market ? .marketOrder : .limitOrder }
}

struct OrderTypeSheet: View {
    let selected: PurchaseOrderType
    let select: (PurchaseOrderType) -> Void
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("¿Cómo quieres comprar?").font(.title.weight(.bold))
                    Text("Elige qué quieres controlar: comprar al precio disponible o fijar un precio máximo.")
                        .font(.subheadline).foregroundStyle(Theme.muted).lineSpacing(4)
                    ForEach(PurchaseOrderType.allCases) { type in
                        VStack(alignment: .leading, spacing: 8) {
                            ChoiceRow(title: type.title, subtitle: type.subtitle, icon: type.icon, selected: selected == type) {
                                select(type); dismiss()
                            }.accessibilityIdentifier("order-option-\(type.rawValue)")
                            NavigationLink {
                                OrderTypeExplanation(type: type) { select(type); dismiss() }
                            } label: {
                                Label("Saber más", systemImage: "arrow.up.right").font(.subheadline.weight(.semibold)).foregroundStyle(Theme.accent).frame(minHeight: 44)
                            }.accessibilityLabel("Saber más sobre \(type.title)").accessibilityIdentifier("order-learn-\(type.rawValue)")
                        }.padding(20).dataCard()
                    }
                    Text("Ambas opciones utilizan dinero virtual y tienen una comisión simulada de 1 US$ al ejecutarse.")
                        .font(.caption).foregroundStyle(Theme.muted).lineSpacing(3)
                }.padding(20)
            }.appCanvas().navigationTitle("Tipo de compra").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Cerrar") { dismiss() } } }
        }.presentationDetents([.fraction(0.82), .large]).presentationDragIndicator(.visible).presentationCornerRadius(30)
    }
}

private struct OrderTypeExplanation: View {
    let type: PurchaseOrderType
    let select: () -> Void
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Image(systemName: type.icon).font(.largeTitle).foregroundStyle(Theme.accent)
                    .frame(width: 72, height: 72).background(Theme.pale, in: Circle())
                Text(type.title).font(.largeTitle.weight(.bold))
                Text(type.concept.explanation).lineSpacing(6)
                VStack(alignment: .leading, spacing: 12) {
                    Text("Un ejemplo con números").font(.headline)
                    Text(type.concept.example).lineSpacing(5)
                }.padding(20).dataCard()
                VStack(alignment: .leading, spacing: 12) {
                    Text(type == .market ? "Antes de confirmar" : "Mientras está pendiente").font(.headline)
                    Text(type == .market ? "Revisa las unidades, la fecha del precio y el total con comisión. Deslizar para actualizar solo consulta un precio nuevo; no realiza ninguna compra." : "Encontrarás la orden en Movimientos. Se reserva saldo o unidades y se ejecuta automáticamente en el servidor. Puedes editarla o cancelarla mientras esté pendiente; actualizar solo consulta su estado.")
                        .foregroundStyle(Theme.muted).lineSpacing(5)
                }
            }.padding(20)
        }.appCanvas().navigationTitle("Saber más").navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                PrimaryButton(title: "Elegir esta opción", icon: "checkmark", action: select)
                    .padding(20).background(.bar)
            }
    }
}
