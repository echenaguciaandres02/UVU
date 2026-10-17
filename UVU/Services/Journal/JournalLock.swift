import Foundation
import LocalAuthentication
import Observation

/// Bloqueo del journal con Face ID (o el código del iPhone si Face ID falla).
/// Se vuelve a bloquear cuando la app pasa a segundo plano.
@MainActor
@Observable
final class JournalLock {
    static let shared = JournalLock()
    static let enabledKey = "journal.faceIDEnabled"

    private(set) var isUnlocked = false
    private(set) var lastError: String?
    private(set) var isAuthenticating = false

    var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: Self.enabledKey)
    }

    /// El contenido se puede mostrar.
    var allowsAccess: Bool {
        !isEnabled || isUnlocked
    }

    func lock() {
        isUnlocked = false
    }

    /// Pide Face ID. Si el iPhone no tiene Face ID ni código configurado, no hay con qué proteger:
    /// se deja pasar y se avisa.
    func unlock() async {
        guard isEnabled, !isUnlocked, !isAuthenticating else { return }
        isAuthenticating = true
        defer { isAuthenticating = false }

        let context = LAContext()
        context.localizedCancelTitle = "Cancelar"
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            lastError = "Este iPhone no tiene Face ID ni código configurado."
            isUnlocked = true
            return
        }
        do {
            let success = try await context.evaluatePolicy(.deviceOwnerAuthentication,
                                                           localizedReason: "Desbloquear tu journal")
            isUnlocked = success
            lastError = success ? nil : "No se pudo verificar."
        } catch {
            isUnlocked = false
            lastError = "No se pudo verificar. Toca Desbloquear para intentar de nuevo."
        }
    }

    /// Para activar la protección, primero se confirma con Face ID.
    func confirmIdentity() async -> Bool {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else { return false }
        let success = (try? await context.evaluatePolicy(.deviceOwnerAuthentication,
                                                         localizedReason: "Activar la protección del journal")) ?? false
        if success { isUnlocked = true }
        return success
    }
}
