import SwiftUI

struct MenuBarView: View {
    @Bindable var coordinator: RecordingCoordinator

    /// Whether transcription is currently in progress
    private var isTranscribing: Bool {
        let step = coordinator.transcriptionService.transcriptionStep
        return step != .idle && step != .completed && !(step == .failed(coordinator.transcriptionService.lastError ?? .noRecording))
    }

    /// Whether analysis is currently in progress
    private var isAnalyzing: Bool {
        let step = coordinator.analysisService.analysisStep
        return step != .idle && step != .completed && !(step == .failed(coordinator.analysisService.lastError ?? .noAPIKey))
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
            .disabled(isTranscribing || isAnalyzing)
        }

        // Transcription state display per UI-SPEC
        transcriptionStatusSection

        // Analysis state display per UI-SPEC
        analysisStatusSection

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

    // MARK: - Analysis Status Section

    @ViewBuilder
    private var analysisStatusSection: some View {
        let step = coordinator.analysisService.analysisStep

        switch step {
        case .idle:
            EmptyView()

        case .preparing, .sending, .processing, .saving:
            Divider()

            HStack {
                Image(systemName: "sparkles")
                Text("Analyzing...")
            }

            ProgressView(value: coordinator.analysisService.progress)
                .progressViewStyle(.linear)

            Text(analysisStepDescription(for: step))
                .font(.caption)
                .foregroundStyle(.secondary)

        case .completed:
            if let analysis = coordinator.analysisService.lastAnalysis {
                Divider()

                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Analysis complete")
                }

                Text(analysisSummaryLine(analysis))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Divider()

                // Scrollable analysis results per D-12
                analysisResultsSection(analysis)
            }

        case .failed:
            Divider()

            HStack {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
                Text("Analysis failed")
            }

            Text(analysisErrorDescription(for: coordinator.analysisService.lastError))
                .font(.caption)
                .foregroundStyle(.red)

            Button("Retry Analysis") {
                Task {
                    if let transcript = coordinator.transcriptionService.lastTranscript {
                        try? await coordinator.analysisService.analyze(transcript: transcript)
                    }
                }
            }
        }
    }

    // MARK: - Analysis Results Section

    @ViewBuilder
    private func analysisResultsSection(_ analysis: AnalysisResult) -> some View {
        // Summary section
        VStack(alignment: .leading, spacing: 4) {
            Text("Summary")
                .font(.headline)

            HStack(alignment: .top) {
                VStack(alignment: .leading) {
                    Text(analysis.summary.tldr)
                        .font(.body)
                        .lineLimit(1)
                    Text(analysis.summary.detailed)
                        .font(.body)
                        .lineLimit(3)
                }

                Spacer()

                CopyButton(text: "\(analysis.summary.tldr)\n\n\(analysis.summary.detailed)")
            }
        }

        Divider()

        // Action Items section
        VStack(alignment: .leading, spacing: 4) {
            Text("Action Items")
                .font(.headline)

            HStack(alignment: .top) {
                VStack(alignment: .leading) {
                    ForEach(analysis.actionItems.prefix(3)) { item in
                        Text("\(item.index). \(item.text)")
                            .font(.body)
                            .lineLimit(1)
                    }
                    if analysis.actionItems.count > 3 {
                        Text("+\(analysis.actionItems.count - 3) more")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                CopyButton(text: analysis.actionItems.map { "\($0.index). \($0.text)\($0.assignee != nil ? " [\($0.assignee!)]" : "")\($0.deadline != nil ? " [\($0.deadline!)]" : "")" }.joined(separator: "\n"))
            }
        }

        Divider()

        // Decisions section
        VStack(alignment: .leading, spacing: 4) {
            Text("Decisions")
                .font(.headline)

            HStack(alignment: .top) {
                VStack(alignment: .leading) {
                    ForEach(Array(analysis.decisions.prefix(3).enumerated()), id: \.offset) { _, decision in
                        Text("- \(decision)")
                            .font(.body)
                            .lineLimit(1)
                    }
                }

                Spacer()

                CopyButton(text: analysis.decisions.map { "- \($0)" }.joined(separator: "\n"))
            }
        }

        Divider()

        // Key Topics section
        VStack(alignment: .leading, spacing: 4) {
            Text("Key Topics")
                .font(.headline)

            HStack(alignment: .top) {
                Text(analysis.topics.map { $0.name }.joined(separator: " \u{00B7} "))
                    .font(.body)
                    .lineLimit(2)

                Spacer()

                CopyButton(text: analysis.topics.map { "- **\($0.name)**: \($0.description)" }.joined(separator: "\n"))
            }
        }
    }

    // CopyButton now in Views/Shared/CopyButton.swift

    // MARK: - Analysis Helper Methods

    private func analysisStepDescription(for step: AnalysisStep) -> String {
        switch step {
        case .preparing: return "Preparing transcript..."
        case .sending: return "Sending to AI provider..."
        case .processing: return "Processing response..."
        case .saving: return "Saving analysis..."
        default: return ""
        }
    }

    private func analysisSummaryLine(_ analysis: AnalysisResult) -> String {
        "Summary \u{00B7} \(analysis.actionItems.count) action items \u{00B7} \(analysis.decisions.count) decisions"
    }

    private func analysisErrorDescription(for error: AnalysisError?) -> String {
        guard let error = error else { return "Unknown error" }
        return error.localizedDescription
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
