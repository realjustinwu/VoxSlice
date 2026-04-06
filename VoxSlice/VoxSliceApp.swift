import SwiftUI

@main
struct VoxSliceApp: App {
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
