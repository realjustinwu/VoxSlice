import Foundation

/// Service that loads and manages recording history from disk.
/// Scans recordings/, transcripts/, and analysis/ directories to build
/// a unified list of RecordingHistoryItem with computed processing status.
@Observable
@MainActor
final class RecordingHistoryService {

    // MARK: - Properties

    /// All recordings sorted newest first by recording.startTime
    var recordings: [RecordingHistoryItem] = []

    /// Whether a load operation is in progress
    var isLoading: Bool = false

    /// Search text for filtering recordings
    var searchText: String = ""

    /// Live status overrides for current session (recordingId -> status)
    private var liveStatuses: [UUID: ProcessingStatus] = [:]

    /// Filtered recordings based on searchText.
    /// If searchText is empty, returns all recordings.
    /// Otherwise filters where any of these match case-insensitively:
    /// displayTitle, transcript segment text, analysis summary (tldr + detailed),
    /// action item text, decision text, topic name.
    var filteredRecordings: [RecordingHistoryItem] {
        guard !searchText.isEmpty else { return recordings }
        let query = searchText.lowercased()
        return recordings.filter { item in
            // Match display title
            if item.displayTitle.lowercased().contains(query) { return true }

            // Match transcript segment text
            if let transcript = item.transcript {
                for segment in transcript.segments {
                    if segment.text.lowercased().contains(query) { return true }
                }
            }

            // Match analysis content
            if let analysis = item.analysis {
                if analysis.summary.tldr.lowercased().contains(query) { return true }
                if analysis.summary.detailed.lowercased().contains(query) { return true }
                for actionItem in analysis.actionItems {
                    if actionItem.text.lowercased().contains(query) { return true }
                }
                for decision in analysis.decisions {
                    if decision.lowercased().contains(query) { return true }
                }
                for topic in analysis.topics {
                    if topic.name.lowercased().contains(query) { return true }
                }
            }

            return false
        }
    }

    // MARK: - Dependencies

    private let storageService: StorageService
    private let fileManager = FileManager.default

    // MARK: - Init

    init(storageService: StorageService) {
        self.storageService = storageService
    }

    // MARK: - Public Methods

    /// Scans the recordings/ directory and builds the full recording history list.
    /// Handles missing/corrupted files gracefully by skipping them.
    func loadRecordings() {
        isLoading = true

        let recordingsDir = storageService.directoryURL(for: AppConstants.recordingsDir)
        let transcriptsDir = storageService.directoryURL(for: AppConstants.transcriptsDir)
        let analysisDir = storageService.directoryURL(for: AppConstants.analysisDir)

        var loadedRecordings: [RecordingHistoryItem] = []

        // Scan recordings/ directory for metadata JSON files
        let metadataFiles: [URL]
        do {
            // Use contentsOfDirectory which only lists immediate children (T-05-02)
            metadataFiles = try fileManager.contentsOfDirectory(
                at: recordingsDir,
                includingPropertiesForKeys: nil
            ).filter { $0.pathExtension == AppConstants.metadataFileExtension }
        } catch {
            // Recordings directory doesn't exist or isn't readable
            self.recordings = []
            self.isLoading = false
            return
        }

        for metadataURL in metadataFiles {
            // Decode RecordingInfo from metadata JSON (T-05-01: use try? for safety)
            guard let data = try? Data(contentsOf: metadataURL),
                  let recording = try? JSONDecoder().decode(RecordingInfo.self, from: data) else {
                // Skip corrupted/unreadable files gracefully per T-05-01
                continue
            }

            // Extract timestamp prefix from metadata filename.
            // Pattern: YYYY-MM-DD_HH-MM-SS_metadata.json -> YYYY-MM-DD_HH-MM-SS
            let baseName = metadataURL.deletingPathExtension().lastPathComponent
                .replacingOccurrences(of: "_metadata", with: "")

            // Look for matching transcript
            let transcript: TranscriptInfo? = loadTranscript(
                prefix: baseName,
                transcriptsDir: transcriptsDir
            )

            // Look for matching analysis (check for both .md file and companion .json)
            let analysis: AnalysisResult? = loadAnalysis(
                prefix: baseName,
                analysisDir: analysisDir
            )

            // Compute processing status
            let status = computeStatus(
                recordingId: recording.id,
                transcript: transcript,
                analysis: analysis
            )

            // Compute display title and summary
            let displayTitle = computeDisplayTitle(recording: recording, analysis: analysis)
            let displaySummary = analysis?.summary.tldr

            let item = RecordingHistoryItem(
                id: recording.id,
                recording: recording,
                transcript: transcript,
                analysis: analysis,
                status: status,
                displayTitle: displayTitle,
                displaySummary: displaySummary
            )
            loadedRecordings.append(item)
        }

        // Sort by recording startTime descending (newest first per D-05)
        loadedRecordings.sort { $0.recording.startTime > $1.recording.startTime }

        self.recordings = loadedRecordings
        self.isLoading = false
    }

    /// Reload the recording history from disk.
    func refreshRecordings() {
        loadRecordings()
    }

    /// Update the live processing status for a recording during the current session.
    /// Used to reflect in-progress transcription/analysis state.
    func updateLiveStatus(
        recordingId: UUID,
        isTranscribing: Bool,
        isAnalyzing: Bool,
        isFailed: Bool
    ) {
        if isFailed {
            liveStatuses[recordingId] = .failed
        } else if isTranscribing {
            liveStatuses[recordingId] = .transcribing
        } else if isAnalyzing {
            liveStatuses[recordingId] = .analyzing
        } else {
            liveStatuses.removeValue(forKey: recordingId)
        }

        // Update the matching recording in-place
        if let index = recordings.firstIndex(where: { $0.id == recordingId }) {
            let item = recordings[index]
            let newStatus = computeStatus(
                recordingId: recordingId,
                transcript: item.transcript,
                analysis: item.analysis
            )
            recordings[index] = RecordingHistoryItem(
                id: item.id,
                recording: item.recording,
                transcript: item.transcript,
                analysis: item.analysis,
                status: newStatus,
                displayTitle: item.displayTitle,
                displaySummary: item.displaySummary
            )
        }
    }

    /// Returns the merged audio file URL for playback.
    /// Looks for {timestamp}_merged.m4a in recordings/ directory.
    /// Returns nil if file does not exist.
    func recordingURL(for item: RecordingHistoryItem) -> URL? {
        let recordingsDir = storageService.directoryURL(for: AppConstants.recordingsDir)

        // Extract timestamp prefix from the mic file path
        let micURL = URL(fileURLWithPath: item.recording.micFilePath)
        let baseName = micURL.deletingPathExtension().lastPathComponent
            .replacingOccurrences(of: "_mic", with: "")

        let mergedURL = recordingsDir
            .appendingPathComponent(baseName)
            .appendingPathExtension(AppConstants.audioFileExtension)

        // The merged file uses the _merged suffix
        // Construct: {baseName}_merged.m4a
        let mergedFileName = "\(baseName)\(AppConstants.mergedFileSuffix).\(AppConstants.audioFileExtension)"
        let mergedFileURL = recordingsDir.appendingPathComponent(mergedFileName)

        guard fileManager.fileExists(atPath: mergedFileURL.path) else {
            return nil
        }
        return mergedFileURL
    }

    // MARK: - Private Methods

    /// Load transcript JSON for a recording by timestamp prefix.
    private func loadTranscript(prefix: String, transcriptsDir: URL) -> TranscriptInfo? {
        let transcriptFileName = "\(prefix)\(AppConstants.transcriptFileSuffix).\(AppConstants.transcriptFileExtension)"
        let transcriptURL = transcriptsDir.appendingPathComponent(transcriptFileName)

        guard fileManager.fileExists(atPath: transcriptURL.path),
              let data = try? Data(contentsOf: transcriptURL),
              let transcript = try? JSONDecoder().decode(TranscriptInfo.self, from: data) else {
            return nil
        }
        return transcript
    }

    /// Load analysis result for a recording by timestamp prefix.
    /// Analysis is stored as Markdown, so we check for file existence only
    /// and parse the companion JSON data if available from the AnalysisService.
    /// For the dashboard, we need the structured data, so we look for
    /// an _analysis.json companion alongside the .md file.
    private func loadAnalysis(prefix: String, analysisDir: URL) -> AnalysisResult? {
        // Try to load JSON companion first (structured data)
        let jsonFileName = "\(prefix)\(AppConstants.analysisFileSuffix).json"
        let jsonURL = analysisDir.appendingPathComponent(jsonFileName)

        if fileManager.fileExists(atPath: jsonURL.path),
           let data = try? Data(contentsOf: jsonURL),
           let analysis = try? JSONDecoder().decode(AnalysisResult.self, from: data) {
            return analysis
        }

        // If no JSON companion, check if .md exists (indicates analysis was done
        // but we don't have structured data to load — return nil for now).
        // This case will be handled when we update AnalysisService to save
        // JSON companions alongside Markdown files (Plan 02 integration).
        return nil
    }

    /// Compute processing status based on live state and file existence.
    private func computeStatus(
        recordingId: UUID,
        transcript: TranscriptInfo?,
        analysis: AnalysisResult?
    ) -> ProcessingStatus {
        // Check live status overrides first (current session state)
        if let liveStatus = liveStatuses[recordingId] {
            return liveStatus
        }

        // Compute from file existence
        let hasTranscript = transcript != nil
        let hasAnalysis = analysis != nil

        if hasTranscript && hasAnalysis {
            return .completed
        } else if hasTranscript {
            return .transcribed
        } else {
            return .new
        }
    }

    /// Compute display title: first analysis topic name, or formatted date fallback.
    private func computeDisplayTitle(recording: RecordingInfo, analysis: AnalysisResult?) -> String {
        if let topic = analysis?.topics.first {
            return topic.name
        }

        // Fall back to formatted date string
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy 'at' h:mm a"
        return formatter.string(from: recording.startTime)
    }
}
