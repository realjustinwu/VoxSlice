import SwiftUI

/// Scrollable detail view for a selected recording per D-08 and UI-SPEC.
/// Displays audio player, transcript segments, and analysis sections in a stacked layout.
/// Wires player to transcript sync: click segment to seek, highlight current segment during playback.
struct DetailView: View {
    let item: RecordingHistoryItem
    let coordinator: RecordingCoordinator
    @Environment(AppDelegate.self) var appDelegate
    @State private var playerViewModel = AudioPlayerViewModel()

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // 1. Audio player (replaces the placeholder from Plan 02)
                    AudioPlayerView(viewModel: playerViewModel)

                    // 2. Transcript section (wired to player for sync)
                    transcriptSection

                    // 3. Analysis sections
                    analysisSections
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 24)
            }
            .onChange(of: playerViewModel.currentSegmentId) { _, newSegmentId in
                // Auto-scroll to highlighted segment per D-15
                if let segmentId = newSegmentId {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        proxy.scrollTo(segmentId, anchor: .center)
                    }
                }
            }
        }
        .onAppear {
            playerViewModel.loadAudio(for: item, historyService: appDelegate.recordingHistoryService)
        }
        .onDisappear {
            playerViewModel.cleanup()
        }
        .onChange(of: item.id) { _, _ in
            // Reload player when selection changes
            playerViewModel.cleanup()
            playerViewModel.loadAudio(for: item, historyService: appDelegate.recordingHistoryService)
        }
    }

    // MARK: - Transcript Section

    @ViewBuilder
    private var transcriptSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Transcript")
                .font(.title3)

            if let transcript = item.transcript {
                // Build speaker map for label resolution
                let speakerMap = Dictionary(uniqueKeysWithValues: transcript.speakers.map { ($0.id, $0.label) })

                ForEach(transcript.segments) { segment in
                    TranscriptSegmentView(
                        segment: segment,
                        speakerLabel: speakerMap[segment.speaker] ?? segment.speaker,
                        isHighlighted: playerViewModel.currentSegmentId == segment.id,
                        onTap: {
                            playerViewModel.seekToSegment(segment)
                        }
                    )
                    .id(segment.id)
                }
            } else {
                switch item.status {
                case .transcribing:
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Transcribing...")
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)

                case .failed:
                    MissingDataView(
                        title: "Transcript not available",
                        message: "The transcript for this recording could not be found.",
                        buttonTitle: "Retry Transcription",
                        onRetry: {
                            Task {
                                try? await coordinator.transcriptionService.transcribe(recording: item.recording)
                                appDelegate.recordingHistoryService.refreshRecordings()
                            }
                        }
                    )

                case .new, .transcribed, .analyzing, .completed:
                    MissingDataView(
                        title: "Transcript not available",
                        message: "This recording has not been transcribed yet.",
                        buttonTitle: "Transcribe",
                        onRetry: {
                            Task {
                                try? await coordinator.transcriptionService.transcribe(recording: item.recording)
                                appDelegate.recordingHistoryService.refreshRecordings()
                            }
                        }
                    )
                }
            }
        }
    }

    // MARK: - Analysis Sections

    @ViewBuilder
    private var analysisSections: some View {
        if let analysis = item.analysis {
            // Summary section per D-10
            AnalysisSectionView(
                title: "Summary",
                copyText: "\(analysis.summary.tldr)\n\n\(analysis.summary.detailed)"
            ) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(analysis.summary.tldr)
                        .font(.body)
                    Text(analysis.summary.detailed)
                        .font(.body)
                }
            }

            // Action Items section per D-10
            AnalysisSectionView(
                title: "Action Items",
                copyText: analysis.actionItems.map { item in
                    var line = "\(item.index). \(item.text)"
                    if let assignee = item.assignee { line += " [\(assignee)]" }
                    if let deadline = item.deadline { line += " [\(deadline)]" }
                    return line
                }.joined(separator: "\n")
            ) {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(analysis.actionItems) { actionItem in
                        HStack(spacing: 4) {
                            Text("\(actionItem.index). \(actionItem.text)")
                                .font(.body)
                            if let assignee = actionItem.assignee {
                                Text("[\(assignee)]")
                                    .font(.body)
                                    .foregroundStyle(.secondary)
                            }
                            if let deadline = actionItem.deadline {
                                Text("[\(deadline)]")
                                    .font(.body)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            // Decisions section per D-10
            AnalysisSectionView(
                title: "Decisions",
                copyText: analysis.decisions.map { "- \($0)" }.joined(separator: "\n")
            ) {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(analysis.decisions, id: \.self) { decision in
                        Text("- \(decision)")
                            .font(.body)
                    }
                }
            }

            // Key Topics section per D-10
            AnalysisSectionView(
                title: "Key Topics",
                copyText: analysis.topics.map { "- **\($0.name)**: \($0.description)" }.joined(separator: "\n")
            ) {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(analysis.topics, id: \.name) { topic in
                        HStack(spacing: 4) {
                            Text(topic.name)
                                .font(.body)
                                .fontWeight(.semibold)
                            Text(": \(topic.description)")
                                .font(.body)
                        }
                    }
                }
            }
        } else {
            // No analysis available
            switch item.status {
            case .analyzing:
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Analyzing...")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 16)

            case .failed:
                MissingDataView(
                    title: "Analysis not available",
                    message: "Analysis has not been generated for this recording.",
                    buttonTitle: "Retry Analysis",
                    onRetry: {
                        guard let transcript = item.transcript else { return }
                        Task {
                            try? await coordinator.analysisService.analyze(transcript: transcript)
                            appDelegate.recordingHistoryService.refreshRecordings()
                        }
                    }
                )

            case .new, .transcribed, .transcribing:
                if item.transcript != nil {
                    MissingDataView(
                        title: "Analysis not available",
                        message: "Analysis has not been generated for this recording.",
                        buttonTitle: "Analyze",
                        onRetry: {
                            guard let transcript = item.transcript else { return }
                            Task {
                                try? await coordinator.analysisService.analyze(transcript: transcript)
                                appDelegate.recordingHistoryService.refreshRecordings()
                            }
                        }
                    )
                } else {
                    MissingDataView(
                        title: "Analysis not available",
                        message: "Transcription required before analysis can be performed.",
                        buttonTitle: "Analyze",
                        onRetry: {
                            // Cannot analyze without transcript
                        }
                    )
                    .opacity(0.5)
                }

            case .completed:
                // Completed status but no analysis data -- should not happen normally
                EmptyView()
            }
        }
    }
}
