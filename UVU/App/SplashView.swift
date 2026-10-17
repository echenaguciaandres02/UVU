import AVFoundation
import SwiftUI

/// Presentación al abrir la app: el video del toro (`Resources/Splash/splash_toro.mp4`, 7 s, sin
/// sonido) a pantalla completa. Al terminar, o al tocar la pantalla, se desvanece y aparece Hoy.
/// Solo sale al abrir la app desde cero, no al volver a ella desde segundo plano.
struct SplashView: View {
    var onFinish: () -> Void

    @State private var player: AVPlayer?
    @State private var finished = false

    var body: some View {
        ZStack {
            // Mismo negro que la pantalla de arranque de iOS, para que no haya un destello.
            Color.ink.ignoresSafeArea()
            if let player {
                VideoLayerView(player: player)
                    .ignoresSafeArea()
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { finish() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Presentación de UVU")
        .accessibilityHint("Toca para saltar")
        .accessibilityAddTraits(.isButton)
        .onAppear(perform: start)
        .onReceive(NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime)) { note in
            guard let item = note.object as? AVPlayerItem, item === player?.currentItem else { return }
            finish()
        }
    }

    private func start() {
        guard player == nil else { return }
        guard let url = Bundle.main.url(forResource: "splash_toro", withExtension: "mp4") else {
            finish()
            return
        }
        // Sin sonido y en modo "ambiente": no corta la música que estés escuchando.
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        let player = AVPlayer(url: url)
        player.isMuted = true
        player.preventsDisplaySleepDuringVideoPlayback = false
        self.player = player
        player.play()
    }

    private func finish() {
        guard !finished else { return }
        finished = true
        player?.pause()
        onFinish()
    }

    /// ¿Debe salir la presentación? No en las pruebas automáticas ni en las capturas.
    static var isEnabled: Bool {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-uvu-splash") { return true }
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil { return false }
        return !arguments.contains { $0.hasPrefix("-uvu-") }
    }
}

/// Capa de video que llena la pantalla (recorta los bordes si la proporción no coincide).
private struct VideoLayerView: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> PlayerView {
        let view = PlayerView()
        view.playerLayer.player = player
        view.playerLayer.videoGravity = .resizeAspectFill
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ uiView: PlayerView, context: Context) {
        uiView.playerLayer.player = player
    }

    final class PlayerView: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    }
}
