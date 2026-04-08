import SwiftUI

struct GeneralSettingsView: View {
    @Bindable var storageService: StorageService
    @Bindable var analysisService: AnalysisService
    @Bindable var globalHotkeyService: GlobalHotkeyService
    @State private var outputFolderPath: String = ""
    @State private var analysisLanguage: String = UserDefaults.standard.string(forKey: AppConstants.analysisLanguageKey) ?? "auto"

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

            Section {
                Picker("Analysis Language", selection: $analysisLanguage) {
                    Text("Same as transcript language").tag("auto")
                    Text("English").tag("en")
                    Text("Chinese (Simplified)").tag("zh")
                    Text("Chinese (Traditional)").tag("zh-TW")
                    Text("Japanese").tag("ja")
                    Text("Korean").tag("ko")
                }
                .pickerStyle(.menu)

                Text("Language for AI-generated analysis output.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Analysis")
            }
        }
        .padding(24)
        .onAppear {
            outputFolderPath = storageService.outputFolderPath
        }
        .onChange(of: analysisLanguage) { _, newValue in
            UserDefaults.standard.set(newValue, forKey: AppConstants.analysisLanguageKey)
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
