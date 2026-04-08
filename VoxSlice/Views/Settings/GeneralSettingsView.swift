import SwiftUI

struct GeneralSettingsView: View {
    @Bindable var storageService: StorageService
    @Bindable var analysisService: AnalysisService
    @Bindable var globalHotkeyService: GlobalHotkeyService
    @State private var outputFolderPath: String = ""
    @State private var analysisLanguage: String = UserDefaults.standard.string(forKey: AppConstants.analysisLanguageKey) ?? "auto"
    @State private var isRecordingShortcut = false

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
                HStack {
                    Text(globalHotkeyService.shortcutDescription)
                        .font(.system(.body, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Spacer()

                    if isRecordingShortcut {
                        Button("Cancel") {
                            isRecordingShortcut = false
                        }
                        .buttonStyle(.bordered)
                    } else {
                        Button("Record Shortcut") {
                            isRecordingShortcut = true
                        }
                        .buttonStyle(.bordered)
                    }
                }

                if isRecordingShortcut {
                    Text("Press your desired key combination...")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    // Hidden text field that captures keyboard input
                    HotkeyRecorder(
                        isRecording: $isRecordingShortcut,
                        globalHotkeyService: globalHotkeyService
                    )
                    .frame(height: 0)  // Invisible, just captures keys
                }

                // Per D-08: Clear/disable hotkey
                if globalHotkeyService.isEnabled {
                    Button("Clear Shortcut") {
                        globalHotkeyService.clearShortcut()
                    }
                    .foregroundStyle(.red)
                }
            } header: {
                Text("Recording Shortcut")
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

// MARK: - Hotkey Recorder (NSViewRepresentable)

/// Per D-06: Button-triggered hotkey recorder.
/// Uses NSTextField as first responder to capture key events via NSEvent.addLocalMonitorForEvents.
/// This captures the key combination when the user presses it in the Settings window.
private struct HotkeyRecorder: NSViewRepresentable {
    @Binding var isRecording: Bool
    let globalHotkeyService: GlobalHotkeyService

    func makeNSView(context: Context) -> NSTextField {
        let textField = NSTextField()
        textField.isEditable = true
        textField.isBordered = false
        textField.drawsBackground = false
        textField.focusRingType = .none
        textField.isBezeled = false
        textField.stringValue = ""

        // Make it first responder to capture key events
        DispatchQueue.main.async {
            if let window = textField.window {
                window.makeFirstResponder(textField)
            }
        }

        // Add local monitor to capture key down events
        context.coordinator.monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            context.coordinator.handleKeyEvent(event, textField: textField)
            return nil  // Consume the event
        }

        return textField
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(isRecording: $isRecording, service: globalHotkeyService)
    }

    static func dismantleNSView(_ nsView: NSTextField, coordinator: Coordinator) {
        if let monitor = coordinator.monitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    class Coordinator: NSObject {
        var isRecording: Binding<Bool>
        let service: GlobalHotkeyService
        var monitor: Any?

        init(isRecording: Binding<Bool>, service: GlobalHotkeyService) {
            self.isRecording = isRecording
            self.service = service
        }

        func handleKeyEvent(_ event: NSEvent, textField: NSTextField) {
            // Ignore lone modifier key presses (Cmd, Shift, Opt, Ctrl)
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if flags.isEmpty || flags == .command || flags == .shift
                || flags == .option || flags == .control {
                return
            }

            // Must have at least one modifier
            guard flags.contains(.command) || flags.contains(.option)
                || flags.contains(.control) else {
                return
            }

            // Update the hotkey binding
            let modifierRaw = flags.rawValue
            let keyCode = event.keyCode

            // Run on MainActor since GlobalHotkeyService is @MainActor
            Task { @MainActor in
                service.updateShortcut(modifiers: modifierRaw, keyCode: keyCode)
                isRecording.wrappedValue = false
            }

            // Remove monitor
            if let monitor = monitor {
                NSEvent.removeMonitor(monitor)
                self.monitor = nil
            }

            // Resign first responder
            textField.window?.makeFirstResponder(nil)
        }
    }
}
