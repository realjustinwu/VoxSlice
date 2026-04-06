import SwiftUI

struct GeneralSettingsView: View {
    @Bindable var storageService: StorageService
    @State private var outputFolderPath: String = ""

    var body: some View {
        Form {
            Section {
                HStack {
                    TextField("Output Folder", text: $outputFolderPath)
                        .textFieldStyle(.roundedBorder)
                        .disabled(true)

                    Button("Choose...") {
                        chooseOutputFolder()
                    }
                }

                Text("Transcripts, analysis, and recordings will be saved here.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Output Location")
            }
        }
        .padding(24)
        .onAppear {
            outputFolderPath = storageService.outputFolderPath
        }
    }

    private func chooseOutputFolder() {
        let panel = NSOpenPanel()
        panel.title = "Choose Output Folder"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: outputFolderPath)

        if panel.runModal() == .OK, let url = panel.url {
            outputFolderPath = url.path
            storageService.outputFolderPath = url.path
        }
    }
}
