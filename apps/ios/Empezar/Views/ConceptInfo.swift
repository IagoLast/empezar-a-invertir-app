import SwiftUI

enum LearningConcept: String, Identifiable {
    case cachedPrice, dailyChange, pe, eps, virtualCash, etf, commission, safetyMargin
    case portfolioValue, investedValue, positions, allocation, activity, chart, orderType, asset, risk, learning
    case marketOrder, limitOrder
    var id: String { rawValue }
    var title: String {
        switch self {
        case .marketOrder: return "Compra a mercado"
        case .limitOrder: return "Orden de compra limitada"
        case .portfolioValue: return "Valor de mi cartera"
        case .investedValue: return "Valor en inversiones"
        case .positions: return "Tus activos"
        case .allocation: return "Distribución de la cartera"
        case .activity: return "Tus movimientos"
        case .chart: return "Histórico de precios"
        case .orderType: return "Cómo comprar"
        case .asset: return "Qué estás comprando"
        case .risk: return "Entender los riesgos"
        case .learning: return "Aprender practicando"
        case .cachedPrice: return "Cómo leer este precio"
        case .dailyChange: return "La variación diaria"
        case .pe: return "Qué significa el PER"
        case .eps: return "Beneficio por acción"
        case .virtualCash: return "Tu saldo virtual"
        case .etf: return "Qué es un ETF"
        case .safetyMargin: return "Margen de seguridad"
        case .commission: return "La comisión de una operación"
        }
    }
    var explanation: String {
        switch self {
        case .marketOrder: return "Eliges cuántas unidades comprar y revisas el importe antes de confirmar. En Empezar utilizamos la cotización válida que aparece en el resumen, con el mercado abierto. Si caduca, tendrás que actualizar el precio. No escoges un precio máximo: por eso conviene revisar el total y la comisión."
        case .limitOrder: return "Eliges el precio máximo por unidad que estás dispuesto a pagar. Si el precio disponible es superior, la orden sigue pendiente. En Empezar se guarda en este dispositivo: desde Movimientos debes pulsar «Comprobar y ejecutar». Solo se realizará la compra si el mercado está abierto, el precio cumple tu límite y tienes saldo suficiente. No reserva dinero ni se ejecuta en segundo plano."
        case .portfolioValue: return "Aquí ves el valor total de tu cartera: el saldo disponible más el valor de tus activos al último precio recibido. Si falta algún precio, no podemos calcular el total."
        case .investedValue: return "Es el valor actual de tus activos, calculado multiplicando sus unidades por el último precio disponible. No es necesariamente lo que pagaste por ellos."
        case .positions: return "Cada posición reúne las unidades que tienes de un activo. El resultado compara su valor actual con el coste de compra, incluidas las comisiones."
        case .allocation: return "Muestra qué porcentaje del valor total corresponde a cada activo y al efectivo disponible. Cambia cuando operas o cambian los precios."
        case .activity: return "Aquí aparecen las compras y ventas realizadas, con fecha, unidades, importe y comisión. Las órdenes locales pendientes se muestran por separado y aún no cambian tu saldo."
        case .chart: return "La línea une precios de cierre; cada vela muestra apertura, máximo, mínimo y cierre del intervalo. Los datos proceden del histórico del proveedor y se muestran en la moneda de cotización. No garantizan resultados futuros."
        case .orderType: return "La compra a mercado utiliza una cotización válida al confirmar. La orden limitada local guarda el precio máximo que quieres pagar. Desde Movimientos puedes comprobarla y ejecutarla si la cotización cumple el límite. Solo se guarda en este dispositivo; no se ejecuta en segundo plano ni reserva saldo."
        case .asset: return "Esta ficha explica a qué empresa o fondo corresponde el activo. Consulta su actividad y sus riesgos para entender qué puede afectar a su valor."
        case .risk: return "El valor de un activo puede bajar. Lee los riesgos específicos y considera cómo afectaría una caída a tu cartera virtual."
        case .learning: return "Relaciona esta explicación con los datos de la ficha y prueba tus ideas con dinero virtual."
        case .cachedPrice: return "Es el importe de una acción o participación en la fecha indicada. Durante la sesión puede subir o bajar; cuando el mercado cierra, puedes seguir consultando el último precio disponible. Mira siempre la fecha antes de comparar precios."
        case .dailyChange: return "Compara el último precio con el cierre de la sesión anterior. Un porcentaje positivo indica una subida; uno negativo, una bajada. No representa lo que has ganado o perdido tú: eso depende del precio al que compraste y de las comisiones."
        case .pe: return "El PER divide el precio de una acción entre el beneficio por acción de los últimos doce meses. Sirve para comparar cuánto se paga por los beneficios, pero un PER bajo no demuestra que una acción esté barata ni uno alto que esté cara. Si no hay beneficios positivos, esta comparación deja de ser útil."
        case .eps: return "El beneficio por acción, o BPA, expresa cuánto beneficio corresponde a cada acción. Aquí usamos el dato de los últimos doce meses. No es dinero que se ingrese automáticamente al accionista: la empresa puede reinvertirlo o repartir una parte como dividendo."
        case .virtualCash: return "Es el dinero ficticio disponible para practicar. Tu cuenta empieza con 10.000 US$ virtuales. Comprar un activo reduce el saldo y vender lo aumenta, descontando las comisiones simuladas. No se puede retirar ni convertir en dinero real. Las recargas opcionales sí se pagan con dinero real."
        case .etf: return "Un ETF es un fondo que cotiza en bolsa y reúne distintos activos, como acciones o bonos. Comprar una participación permite acceder a esa cartera. Diversificar no elimina el riesgo: un ETF puede perder valor y algunos concentran su inversión en un sector o país."
        case .safetyMargin: return "Es un descuento sobre el valor que has estimado, para dejar espacio a errores en tus supuestos. No garantiza evitar pérdidas: la estimación también puede estar equivocada."
        case .commission: return "Una comisión es un coste por realizar una operación. En este simulador cobramos 1 US$ ficticio por cada compra o venta. Aumenta el coste de comprar y reduce lo que recibes al vender. Los costes reales dependen del intermediario."
        }
    }
    var example: String {
        switch self {
        case .marketOrder: return "Si compras 2 unidades a 100 US$, el importe es 200 US$. Con la comisión virtual de 1 US$, se descuentan 201 US$ de tu saldo. Antes de confirmar puedes volver y cambiar las unidades."
        case .limitOrder: return "Con un límite de 95 US$, un precio de 100 US$ no permite comprar. Si al comprobar la orden el precio válido es de 94 US$, dos unidades cuestan 188 US$ más 1 US$ de comisión. Puedes cancelar la orden mientras siga pendiente."
        case .portfolioValue: return "Con 800 US$ disponibles y activos valorados en 200 US$, tu cartera vale 1.000 US$."
        case .investedValue: return "Dos acciones a 120 US$ representan 240 US$ en inversiones."
        case .positions: return "Si pagaste 201 US$ con comisión y ahora vale 220 US$, el resultado es +19 US$."
        case .allocation: return "Un activo de 250 US$ en una cartera de 1.000 US$ pesa un 25 %."
        case .activity: return "Comprar dos unidades a 100 US$ muestra 200 US$ de importe y 1 US$ de comisión."
        case .chart: return "Una vela verde termina por encima de su apertura; una roja termina por debajo. Cambia de periodo para observar cómo ha evolucionado el precio."
        case .orderType: return "Con un límite de 100 US$, la orden solo puede ejecutarse a 100 US$ o menos, más la comisión."
        case .asset: return "Una acción representa una participación en una empresa; un ETF reúne una cartera de activos."
        case .risk: return "Una caída del 10 % convierte 100 US$ invertidos en 90 US$ antes de comisiones."
        case .learning: return "Compara dos activos y explica con tus palabras qué estás comprando en cada uno."
        case .cachedPrice: return "Una acción de 100 US$ cuesta menos por unidad que otra de 200 US$, pero eso no significa que la empresa esté más barata: también importan sus beneficios y cuántas acciones tiene."
        case .dailyChange: return "Si ayer cerró a 100 US$ y ahora cuesta 103 US$, la variación es +3 %. Si tú compraste a 110 US$, todavía tendrías una pérdida."
        case .pe: return "Precio de 100 US$ ÷ BPA de 5 US$ = PER de 20 veces. Es una relación entre precio y beneficios pasados, no una promesa de rentabilidad."
        case .eps: return "Una empresa con 1.000.000 US$ de beneficio y 500.000 acciones tendría un BPA de 2 US$ en un cálculo simplificado."
        case .virtualCash: return "Con 10.000 US$ virtuales, comprar dos acciones a 100 US$ y pagar 1 US$ de comisión deja 9.799 US$ de saldo disponible."
        case .etf: return "VTI reúne acciones de muchas empresas estadounidenses. BND reúne bonos. Ambos son ETF, pero sus inversiones y riesgos son diferentes."
        case .safetyMargin: return "Si estimas un valor de 100 US$ y aplicas un margen del 20 %, el resultado del ejercicio es 80 US$. Ese descuento no convierte la inversión en segura."
        case .commission: return "Comprar a 100 US$ y vender al mismo precio cuesta 2 US$ en total: 1 al comprar y 1 al vender. El resultado sería −2 US$."
        }
    }
}

/// The whole label provides a comfortable touch target for contextual help.
struct ConceptLabel: View {
    let title: String
    let concept: LearningConcept
    @State private var presented = false
    var body: some View {
        Button { presented = true } label: {
            HStack(spacing: 5) {
                Text(title).fixedSize(horizontal: false, vertical: true)
                Image(systemName: "info.circle").font(.system(size: 13, weight: .medium))
            }.foregroundStyle(Theme.muted).frame(minHeight: 44, alignment: .leading).contentShape(Rectangle())
        }.buttonStyle(.plain)
            .accessibilityLabel("\(title). Información: \(concept.title)")
            .accessibilityIdentifier("info-\(concept.rawValue)")
            .sheet(isPresented: $presented) { ConceptInfoSheet(concept: concept) }
    }
}

struct ConceptInfoSheet: View {
    let concept: LearningConcept
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text(concept.title).font(.title2.weight(.bold))
                    Text(concept.explanation).lineSpacing(4)
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Un ejemplo").font(.headline).foregroundStyle(Theme.accent)
                        Text(concept.example).lineSpacing(4)
                    }.padding(20).frame(maxWidth: .infinity, alignment: .leading).dataCard()
                }.padding(24)
            }.appCanvas().navigationTitle("Aprender").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Entendido") { dismiss() } } }
        }.presentationDetents([.medium, .large]).presentationDragIndicator(.visible)
    }
}
