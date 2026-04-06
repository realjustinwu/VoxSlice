import SwiftUI

struct SettingsView: View {
    @Bindable var storageService: StorageService

    var body: some View {
        TabView {
            GeneralSettingsView(storageService: storageService)
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }
            STTProviderSettingsView(storageService: storageService)
                .tabItem {
                    Label("STT Provider", systemImage: "waveform")
                }
            AIProviderSettingsView(storageService: storageService)
                .tabItem {
                    Label("AI Provider", systemImage: "brain")
                }
        }
        .frame(width: 520, height: 420)
    }
}
