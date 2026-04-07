import SwiftUI

struct SettingsView: View {
    @Bindable var storageService: StorageService
    @Bindable var transcriptionService: TranscriptionService

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
            TranscriptionSettingsView(transcriptionService: transcriptionService)
                .tabItem {
                    Label("Transcription", systemImage: "doc.text.below.ecg")
                }
        }
        .frame(width: 520, height: 420)
    }
}
