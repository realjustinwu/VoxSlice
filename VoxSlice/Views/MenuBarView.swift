import SwiftUI

struct MenuBarView: View {
    @Bindable var coordinator: RecordingCoordinator

    var body: some View {
        // Header
        Text("VoxSlice")
            .font(.headline)

        Divider()

        if coordinator.state == .recording {
            // Per D-06: Show elapsed time in MM:SS format and Stop button during recording
            HStack {
                Image(systemName: "record.circle")
                    .foregroundStyle(.red)
                Text(coordinator.formattedElapsedTime)
                    .font(.system(.body, design: .monospaced))
            }

            Button("Stop Recording") {
                coordinator.stopRecording()
            }
            .keyboardShortcut("s", modifiers: .command)
        } else {
            // Per D-04: Start recording with single click
            Button("Start Recording") {
                coordinator.startRecording()
            }
            .keyboardShortcut("r", modifiers: .command)
        }

        Divider()

        // Settings — uses SettingsLink which responds to cmd+,
        SettingsLink {
            Text("Settings...")
        }
        .keyboardShortcut(",", modifiers: .command)

        // About
        Button("About VoxSlice") {
            NSApplication.shared.orderFrontStandardAboutPanel(
                options: [
                    .applicationName: "VoxSlice",
                    .applicationVersion: "1.0"
                ]
            )
        }

        Divider()

        // Quit
        Button("Quit VoxSlice") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q", modifiers: .command)
    }
}

#Preview {
    MenuBarView(coordinator: RecordingCoordinator(
        audioCaptureService: AudioCaptureService(
            storageService: StorageService(),
            permissionManager: PermissionManager()
        ),
        storageService: StorageService(),
        permissionManager: PermissionManager()
    ))
}
