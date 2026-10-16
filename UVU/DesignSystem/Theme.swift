import SwiftUI

// MARK: - Paleta "DISCIPLINE"
//
// Los valores viven en el Asset Catalog (Assets.xcassets/Colors). Aquí solo se exponen.
// Reglas:
// - El rojo (`signal`) es el único color con volumen: máximo un elemento rojo dominante por pantalla.
// - Completado = rojo lleno; pendiente = contorno `graphite`. No se usa verde para "éxito".
// - Texto pequeño nunca en rojo sobre negro (contraste 3,9:1): el rojo va en rellenos, íconos y titulares grandes.
// - `brass` solo para hitos (récord de racha, meta cumplida). Muy escaso.

extension ShapeStyle where Self == Color {
    /// #0A0A0A · fondo principal.
    static var ink: Color { Color("ink") }
    /// #151515 · tarjetas y superficies.
    static var carbon: Color { Color("carbon") }
    /// #2A2A2A · bordes de 1 pt y separadores.
    static var graphite: Color { Color("graphite") }
    /// #8C8C8C · texto secundario y estados inactivos.
    static var ash: Color { Color("ash") }
    /// #E9E3D6 · texto principal (blanco hueso, nunca blanco puro).
    static var bone: Color { Color("bone") }
    /// #D42A20 · acento único: completado, acción principal, racha activa.
    static var signal: Color { Color("signal") }
    /// #8E1B14 · estado presionado, parcial, fondos de pósters.
    static var signalDeep: Color { Color("signalDeep") }
    /// #B08D57 · solo hitos y récords.
    static var brass: Color { Color("brass") }
}

// MARK: - Tokens de forma y espacio

/// Espaciados (múltiplos de 4).
enum Space {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let s: CGFloat = 12
    static let m: CGFloat = 16
    static let l: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
}

/// Esquinas casi rectas.
enum Radius {
    /// Checkboxes, celdas del calendario, etiquetas.
    static let sharp: CGFloat = 2
    /// Tarjetas, botones, campos.
    static let card: CGFloat = 4
}

enum Stroke {
    static let hairline: CGFloat = 1
}

/// Animaciones secas y rápidas, sin rebotes exagerados.
enum Motion {
    static let quick = Animation.snappy(duration: 0.2)
    static let stamp = Animation.snappy(duration: 0.18, extraBounce: 0)
}

// MARK: - Superficies

extension View {
    /// Tarjeta plana: fondo `carbon`, borde `graphite` de 1 pt, esquinas de 4 pt.
    func cardSurface(padding: CGFloat = Space.m) -> some View {
        self
            .padding(padding)
            .background(.carbon, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                    .strokeBorder(.graphite, lineWidth: Stroke.hairline)
            }
    }

    /// Fondo de pantalla `ink` para listas y formularios (quita el gris agrupado del sistema).
    /// Estilo agrupado de borde a borde: filas rectas, sin las tarjetas muy redondeadas de iOS.
    func screenBackground() -> some View {
        self
            .listStyle(.grouped)
            .scrollContentBackground(.hidden)
            .background(Color.ink.ignoresSafeArea())
    }

    /// Formulario DISCIPLINE: fondo `ink`, filas `carbon`, texto Inter en `bone`.
    func uvuForm() -> some View {
        self
            .font(.uiBody)
            .foregroundStyle(.bone)
            .listRowBackground(Color.carbon)
            .listRowSeparatorTint(.graphite)
            .screenBackground()
    }

    /// Texto al pie de una sección de formulario.
    func formFooter() -> some View {
        self
            .font(.uiFootnote)
            .foregroundStyle(.ash)
    }

    /// Fila de lista: fondo `carbon` y separadores `graphite`.
    func rowSurface() -> some View {
        self
            .listRowBackground(Color.carbon)
            .listRowSeparatorTint(.graphite)
    }
}
