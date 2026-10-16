#if DEBUG
import SwiftUI

/// Catálogo del sistema visual (solo en compilaciones de desarrollo).
/// Se abre al lanzar la app con el argumento `-uvu-gallery` (lo usan las capturas automáticas).
struct DesignSystemGallery: View {
    private let swatches: [(String, String, Color)] = [
        ("ink", "#0A0A0A", .ink), ("carbon", "#151515", .carbon),
        ("graphite", "#2A2A2A", .graphite), ("ash", "#8C8C8C", .ash),
        ("bone", "#E9E3D6", .bone), ("signal", "#D42A20", .signal),
        ("signalDeep", "#8E1B14", .signalDeep), ("brass", "#B08D57", .brass),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.xl) {
                Text("Sistema.")
                    .posterTitle(72)
                Text("Discipline · v1")
                    .labelCaps()

                section("Paleta") {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Space.s) {
                        ForEach(swatches, id: \.0) { name, hex, color in
                            HStack(spacing: Space.s) {
                                Rectangle()
                                    .fill(color)
                                    .frame(width: 44, height: 44)
                                    .overlay { Rectangle().strokeBorder(.graphite, lineWidth: Stroke.hairline) }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(name).font(.uiBodyStrong).foregroundStyle(.bone)
                                    Text(hex).labelCaps(11, .regular)
                                }
                                Spacer(minLength: 0)
                            }
                        }
                    }
                }

                section("Tipografía") {
                    VStack(alignment: .leading, spacing: Space.m) {
                        Text("Hoy.").posterTitle(96)
                        Text("Semana 42").posterTitle(40)
                        Text("Inter Black · Botones").font(.ui(17, .black)).foregroundStyle(.bone)
                        Text("Inter SemiBold · Hábitos").font(.ui(17, .semibold)).foregroundStyle(.bone)
                        Text("Inter Regular · Cuerpo de texto para notas y descripciones largas.")
                            .font(.uiBody).foregroundStyle(.bone)
                        Text("Etiqueta con tracking amplio").labelCaps()
                        Text("Empieza donde estás.").editorialQuote()
                            .frame(maxWidth: .infinity)
                        HStack(alignment: .firstTextBaseline, spacing: Space.s) {
                            Text("04:00").font(.numeral(72)).foregroundStyle(.bone)
                            Text("21").font(.numeral(72, weight: .thin)).foregroundStyle(.bone)
                        }
                        .monospacedDigit()
                    }
                }

                section("Grano") {
                    HStack(spacing: Space.m) {
                        Rectangle().fill(.signal).frame(height: 120).grain(.poster)
                        Rectangle().fill(.ink).frame(height: 120).grain(.subtle)
                            .overlay { Rectangle().strokeBorder(.graphite, lineWidth: Stroke.hairline) }
                    }
                }

                GalleryComponents()
            }
            .padding(Space.m)
        }
        .background(Color.ink.ignoresSafeArea())
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Space.s) {
            Text(title).labelCaps(12, .black, color: .bone)
            Rectangle().fill(.graphite).frame(height: Stroke.hairline)
            content()
        }
    }
}

#Preview {
    DesignSystemGallery()
        .preferredColorScheme(.dark)
}
#endif
