import UIKit

/// Ajustes globales de UIKit que SwiftUI no expone: tipografía de las barras de navegación
/// y colores de la barra de pestañas. Las barras conservan el material nativo de iOS (Liquid Glass);
/// solo cambian fuentes y colores.
enum Appearance {
    static func configure() {
        let bone = UIColor(named: "bone") ?? .white
        let ash = UIColor(named: "ash") ?? .gray

        let largeTitle = UIFont(name: FontName.display, size: 44) ?? .systemFont(ofSize: 34, weight: .black)
        let inlineTitle = UIFont(name: FontName.interBlack, size: 15) ?? .systemFont(ofSize: 15, weight: .black)

        let navigationBar = UINavigationBar.appearance()
        navigationBar.largeTitleTextAttributes = [
            .font: UIFontMetrics(forTextStyle: .largeTitle).scaledFont(for: largeTitle),
            .foregroundColor: bone,
            .kern: -0.5,
        ]
        navigationBar.titleTextAttributes = [
            .font: UIFontMetrics(forTextStyle: .headline).scaledFont(for: inlineTitle),
            .foregroundColor: bone,
            .kern: 1.5,
        ]

        UITabBar.appearance().unselectedItemTintColor = ash
    }
}
