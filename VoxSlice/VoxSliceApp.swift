import SwiftUI

// AppDelegate manages the permissions window lifecycle
class AppDelegate: NSObject, NSApplicationDelegate {
    let permissionManager = PermissionManager()
    var permissionsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Per D-16: Show permissions window on first launch if any permission missing
        if permissionManager.hasMissingPermissions {
            showPermissionsWindow()
        }
    }

    func showPermissionsWindow() {
        // Per D-16: Show permissions window if permissions are missing
        let contentView = PermissionsView(permissionManager: permissionManager)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 320),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "VoxSlice Permissions"
        window.contentView = NSHostingView(rootView: contentView)
        window.center()
        window.makeKeyAndOrderFront(nil)
        permissionsWindow = window
    }
}

@main
struct VoxSliceApp: App {
    // Per D-16: Register AppDelegate to manage permissions window
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra("VoxSlice", systemImage: "waveform.circle") {
            MenuBarView()
        }
        .menuBarExtraStyle(.menu)

        Settings {
            Text("Settings placeholder")
                .frame(width: 520, height: 420)
        }
    }
}
