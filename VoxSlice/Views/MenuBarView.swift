import SwiftUI

struct MenuBarView: View {
    var body: some View {
        // Header
        Text("VoxSlice")
            .font(.headline)

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
    MenuBarView()
}
