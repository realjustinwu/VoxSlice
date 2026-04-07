import SwiftUI

struct MenuBarView: View {
    @Bindable var coordinator: RecordingCoordinator

    /// Whether transcription is currently in progress
    private var isTranscribing: Bool {
        let step = coordinator.transcriptionService.transcriptionStep
        return step != .idle && step != .completed && !(step == .failed(coordinator.transcriptionService.lastError ?? .noRecording))
    }

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
            .disabled(isTranscribing)
        }

        // Transcription state display per UI-SPEC
        transcriptionStatusSection

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

    // MARK: - Transcription Status Section

    @ViewBuilder
    private var transcriptionStatusSection: some View {
        let step = coordinator.transcriptionService.transcriptionStep

        switch step {
        case .idle:
            EmptyView()

        case .preparing, .sending, .chunkProgress, .processingSpeakers, .saving:
            HStack {
                Image(systemName: "doc.text.below.ecg")
                Text("Transcribing...")
            }

            ProgressView(value: coordinator.transcriptionService.progress)
                .progressViewStyle(.linear)

            Text(stepDescription(for: step))
                .font(.caption)
                .foregroundStyle(.secondary)

        case .completed:
            if let transcript = coordinator.transcriptionService.lastTranscript {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Transcription complete")
                }
                Text("\(transcript.speakers.count) speakers detected \u{00B7} \(transcript.language)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

        case .failed:
            HStack {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
                Text("Transcription failed")
            }

            Text(errorDescription(for: coordinator.transcriptionService.lastError))
                .font(.caption)
                .foregroundStyle(.red)

            Button("Retry Transcription") {
                Task {
                    if let recording = coordinator.currentRecording {
                        try? await coordinator.transcriptionService.transcribe(recording: recording)
                    }
                }
            }
        }
    }

    // MARK: - Helper Methods

    private func stepDescription(for step: TranscriptionStep) -> String {
        switch step {
        case .preparing: return "Preparing audio..."
        case .sending: return "Sending to whisperX..."
        case .chunkProgress(let current, let total): return "Transcribing chunk \(current) of \(total)..."
        case .processingSpeakers: return "Processing speakers..."
        case .saving: return "Saving transcript..."
        default: return ""
        }
    }

    private func errorDescription(for error: TranscriptionError?) -> String {
        guard let error = error else { return "Unknown error" }
        switch error {
        case .serviceUnavailable: return "Could not connect to whisperX service"
        case .invalidResponse: return "whisperX returned an error. Check service logs."
        case .timeout: return "Transcription timed out. The recording may be too long."
        default: return error.localizedDescription
        }
    }
}

#Preview {
    MenuBarView(coordinator: RecordingCoordinator(
        audioCaptureService: AudioCaptureService(
            storageService: StorageService(),
            permissionManager: PermissionManager()
        ),
        storageService: StorageService(),
        permissionManager: PermissionManager(),
        transcriptionService: TranscriptionService(storageService: StorageService()),
        analysisService: AnalysisService(storageService: StorageService())
    ))
}
