import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @AppStorage("weightUnit") private var weightUnit: WeightUnit = .kg

    @State private var exportFile: ShareableFile?
    @State private var showImporter = false
    @State private var pendingImport: BackupFile?
    @State private var message: SettingsMessage?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Unidad principal de peso", selection: $weightUnit) {
                        ForEach(WeightUnit.allCases) { unit in
                            Text(unit.title).tag(unit)
                        }
                    }
                } header: {
                    Text("Gym")
                } footer: {
                    Text("Puedes registrar cada serie en kg o lb. Las gráficas y récords se muestran en esta unidad.")
                }

                Section {
                    Button {
                        export()
                    } label: {
                        Label("Exportar datos (JSON)", systemImage: "square.and.arrow.up")
                    }
                    Button {
                        showImporter = true
                    } label: {
                        Label("Importar respaldo", systemImage: "square.and.arrow.down")
                    }
                } header: {
                    Text("Respaldo")
                } footer: {
                    Text("Guarda el archivo en Archivos, iCloud Drive o envíatelo. Importar reemplaza todos los datos actuales.")
                }

                Section {
                    LabeledContent("Sincronización con iCloud", value: "Desactivada")
                } footer: {
                    Text("Requiere una cuenta de Apple Developer. La app ya está preparada para activarla más adelante.")
                }

                Section("Acerca de") {
                    LabeledContent("Versión", value: appVersion)
                }
            }
            .navigationTitle("Ajustes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") { dismiss() }
                }
            }
            .sheet(item: $exportFile) { file in
                ActivityView(items: [file.url])
                    .presentationDetents([.medium, .large])
            }
            .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json]) { result in
                readBackup(result)
            }
            .alert(
                "¿Reemplazar todos los datos?",
                isPresented: Binding(get: { pendingImport != nil }, set: { if !$0 { pendingImport = nil } }),
                presenting: pendingImport
            ) { backup in
                Button("Reemplazar", role: .destructive) { restore(backup) }
                Button("Cancelar", role: .cancel) {}
            } message: { backup in
                Text("Se borrarán tus datos actuales y se cargarán los del respaldo:\n\n\(backup.summary)")
            }
            .alert(
                message?.title ?? "",
                isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } }),
                presenting: message
            ) { _ in
                Button("OK", role: .cancel) {}
            } message: { message in
                Text(message.body)
            }
        }
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }

    private func export() {
        do {
            try context.save()
            exportFile = ShareableFile(url: try BackupService.exportFile(context: context))
        } catch {
            message = SettingsMessage(title: "No se pudo exportar", body: error.localizedDescription)
        }
    }

    private func readBackup(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            let hasAccess = url.startAccessingSecurityScopedResource()
            defer {
                if hasAccess { url.stopAccessingSecurityScopedResource() }
            }
            do {
                pendingImport = try BackupService.decode(Data(contentsOf: url))
            } catch let error as BackupError {
                message = SettingsMessage(title: "No se pudo importar", body: error.localizedDescription)
            } catch {
                message = SettingsMessage(title: "No se pudo importar", body: "El archivo no es un respaldo válido de UVU.")
            }
        case .failure(let error):
            message = SettingsMessage(title: "No se pudo abrir el archivo", body: error.localizedDescription)
        }
    }

    private func restore(_ backup: BackupFile) {
        do {
            try BackupService.restore(backup, into: context)
            Task { await NotificationService.rescheduleAll(context: context) }
            message = SettingsMessage(title: "Respaldo importado", body: backup.summary)
        } catch {
            message = SettingsMessage(title: "No se pudo importar", body: error.localizedDescription)
        }
    }
}

struct SettingsMessage: Identifiable {
    let id = UUID()
    let title: String
    let body: String
}

#Preview {
    SettingsView()
        .modelContainer(PreviewData.container)
}
