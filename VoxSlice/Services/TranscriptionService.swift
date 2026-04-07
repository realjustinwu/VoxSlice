import Foundation
import AVFoundation

// MARK: - Transcription Error

/// Errors specific to transcription
enum TranscriptionError: Error, LocalizedError, Equatable {
    case serviceUnavailable(String)
    case invalidResponse(String)
    case timeout
    case mergeFailed(String)
    case chunkFailed(String)
    case noRecording

    var errorDescription: String? {
        switch self {
        case .serviceUnavailable(let message):
            return message
        case .invalidResponse(let message):
            return "Invalid response from transcription service: \(message)"
        case .timeout:
            return "Transcription timed out. The recording may be too long or the service is overloaded."
        case .mergeFailed(let reason):
            return "Failed to merge audio streams: \(reason)"
        case .chunkFailed(let reason):
            return "Failed to split audio for transcription: \(reason)"
        case .noRecording:
            return "No recording available to transcribe."
        }
    }

    static func == (lhs: TranscriptionError, rhs: TranscriptionError) -> Bool {
        switch (lhs, rhs) {
        case (.timeout, .timeout), (.noRecording, .noRecording):
            return true
        case (.serviceUnavailable(let l), .serviceUnavailable(let r)),
             (.invalidResponse(let l), .invalidResponse(let r)),
             (.mergeFailed(let l), .mergeFailed(let r)),
             (.chunkFailed(let l), .chunkFailed(let r)):
            return l == r
        default:
            return false
        }
    }
}

// MARK: - Transcription Step

/// Progress step during transcription, per UI-SPEC progress states
enum TranscriptionStep: Equatable {
    case idle
    case preparing          // "Preparing audio..." -- merging streams
    case sending            // "Sending to whisperX..."
    case chunkProgress(current: Int, total: Int)  // "Transcribing chunk N of M..."
    case processingSpeakers // "Processing speakers..."
    case saving             // "Saving transcript..."
    case completed
    case failed(TranscriptionError)
}

// MARK: - Transcription Service

@Observable
@MainActor
final class TranscriptionService {

    // MARK: Published State

    var transcriptionStep: TranscriptionStep = .idle
    var progress: Double = 0.0  // 0.0 to 1.0
    var lastTranscript: TranscriptInfo?
    var lastError: TranscriptionError?

    // MARK: Dependencies

    private let storageService: StorageService

    // MARK: WhisperX Configuration

    /// whisperX service URL from UserDefaults
    var whisperXURL: String {
        get {
            UserDefaults.standard.string(forKey: AppConstants.whisperXURLKey)
                ?? AppConstants.whisperXDefaultURL
        }
        set {
            UserDefaults.standard.set(newValue, forKey: AppConstants.whisperXURLKey)
        }
    }

    // MARK: Init

    init(storageService: StorageService) {
        self.storageService = storageService
    }

    // MARK: - Health Check

    /// Check if whisperX service is reachable (GET /health)
    /// Returns (success: Bool, errorMessage: String?)
    func healthCheck() async -> (Bool, String?) {
        let urlString = "\(whisperXURL)\(AppConstants.whisperXHealthEndpoint)"

        guard let url = URL(string: urlString) else {
            return (false, "Invalid whisperX URL: \(whisperXURL)")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 10

        do {
            let (_, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                return (true, nil)
            } else {
                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
                return (false, "whisperX returned an unexpected response (status \(statusCode)).")
            }
        } catch {
            return (false, "Could not connect to whisperX at \(whisperXURL). Make sure the service is running.")
        }
    }

    // MARK: - Transcribe

    /// Main entry point: transcribe a recording per D-10.
    /// Merges dual-stream audio, chunks if needed, sends to whisperX, saves transcript.
    func transcribe(recording: RecordingInfo) async throws -> TranscriptInfo {
        // Reset state
        lastError = nil
        lastTranscript = nil
        progress = 0.0

        // Step 1: Prepare (merge dual-stream audio)
        transcriptionStep = .preparing
        progress = 0.05

        let mergedAudioURL = try await mergeAudioFiles(
            micPath: recording.micFilePath,
            systemPath: recording.systemFilePath
        )
        progress = 0.10

        // Persist merged audio file for playback (was previously temp + deleted)
        let persistedMergedURL = persistMergedAudio(mergedAudioURL, recording: recording)

        let fileSize = fileSize(of: persistedMergedURL)

        // Step 2: Check if chunking is needed
        if AudioChunker.shouldChunk(fileURL: persistedMergedURL) {
            return try await transcribeWithChunks(
                mergedAudioURL: persistedMergedURL,
                recording: recording,
                fileSize: fileSize
            )
        } else {
            return try await transcribeSingle(
                mergedAudioURL: persistedMergedURL,
                recording: recording
            )
        }
    }

    // MARK: - Retry

    /// Retry the last failed transcription
    func retryLastTranscription() async throws -> TranscriptInfo {
        guard lastError != nil else {
            throw TranscriptionError.noRecording
        }
        // Reset error state but don't have recording info here
        // Caller should use transcribe(recording:) with the original recording
        throw TranscriptionError.noRecording
    }

    // MARK: - Private: Single File Transcription

    /// Transcribe a single (non-chunked) audio file
    private func transcribeSingle(
        mergedAudioURL: URL,
        recording: RecordingInfo
    ) async throws -> TranscriptInfo {
        // Sending: 20% - 80%
        transcriptionStep = .sending
        progress = 0.20

        let rawResponse = try await sendToWhisperX(audioURL: mergedAudioURL)

        // Processing speakers: 80% - 95%
        transcriptionStep = .processingSpeakers
        progress = 0.80

        let transcript = parseWhisperXResponse(
            rawResponse,
            recordingId: recording.id,
            audioPath: mergedAudioURL.path,
            duration: recording.duration
        )

        // Saving: 95% - 100%
        transcriptionStep = .saving
        progress = 0.95

        let savedURL = try saveTranscript(transcript)

        transcriptionStep = .completed
        progress = 1.0
        lastTranscript = transcript

        return transcript
    }

    // MARK: - Private: Chunked Transcription

    /// Transcribe a large audio file by splitting into chunks
    private func transcribeWithChunks(
        mergedAudioURL: URL,
        recording: RecordingInfo,
        fileSize: UInt64
    ) async throws -> TranscriptInfo {
        let chunkCount = AudioChunker.calculateChunkCount(fileURL: mergedAudioURL)

        // Split audio
        let chunkURLs: [URL]
        do {
            chunkURLs = try await AudioChunker.splitAudioFile(mergedAudioURL)
        } catch {
            throw TranscriptionError.chunkFailed(error.localizedDescription)
        }

        defer {
            AudioChunker.cleanupChunks(chunkURLs)
        }

        // Transcribe each chunk
        var chunkResults: [TranscriptInfo] = []
        for (index, chunkURL) in chunkURLs.enumerated() {
            transcriptionStep = .chunkProgress(current: index + 1, total: chunkCount)
            progress = 0.10 + (0.80 * Double(index) / Double(chunkCount))

            let rawResponse = try await sendToWhisperX(audioURL: chunkURL)
            let chunkTranscript = parseWhisperXResponse(
                rawResponse,
                recordingId: recording.id,
                audioPath: chunkURL.path,
                duration: 0 // individual chunk duration
            )
            chunkResults.append(chunkTranscript)
        }

        // Processing speakers: 90% - 95%
        transcriptionStep = .processingSpeakers
        progress = 0.90

        let mergedTranscript = AudioChunker.mergeChunkResults(
            chunks: chunkResults,
            recordingId: recording.id,
            totalDuration: recording.duration,
            language: chunkResults.first?.language ?? "unknown",
            audioFilePath: mergedAudioURL.path
        )

        // Saving: 95% - 100%
        transcriptionStep = .saving
        progress = 0.95

        let savedURL = try saveTranscript(mergedTranscript)

        transcriptionStep = .completed
        progress = 1.0
        lastTranscript = mergedTranscript

        return mergedTranscript
    }

    // MARK: - Private: Merge Audio Files

    /// Merge mic and system audio files per D-13.
    /// Mixes both audio sources at equal volume into a single M4A file.
    private func mergeAudioFiles(micPath: String, systemPath: String) async throws -> URL {
        let fileManager = FileManager.default

        // If mic file doesn't exist, use system audio directly
        guard fileManager.fileExists(atPath: micPath) else {
            // Fall back to system audio only
            if fileManager.fileExists(atPath: systemPath) {
                return URL(fileURLWithPath: systemPath)
            }
            throw TranscriptionError.mergeFailed("No audio files found")
        }

        // If system file doesn't exist, use mic audio directly
        guard fileManager.fileExists(atPath: systemPath) else {
            return URL(fileURLWithPath: micPath)
        }

        // Merge both audio files using AVAsset / AVAssetExportSession
        let micURL = URL(fileURLWithPath: micPath)
        let systemURL = URL(fileURLWithPath: systemPath)

        let micAsset = AVAsset(url: micURL)
        let systemAsset = AVAsset(url: systemURL)

        // Load durations to verify assets are valid
        let micDuration: Double
        let systemDuration: Double
        do {
            micDuration = try await micAsset.load(.duration).seconds
            systemDuration = try await systemAsset.load(.duration).seconds
        } catch {
            // Fall back to system audio only if merge fails
            return systemURL
        }

        guard micDuration > 0, systemDuration > 0 else {
            // Fall back to system audio only
            return systemURL
        }

        // Use AVMutableComposition to merge both tracks
        let composition = AVMutableComposition()

        // Add mic audio track
        let micTracks = try await micAsset.load(.tracks)
        guard let micAudioTrack = micTracks.first(where: { $0.mediaType == .audio }) else {
            return systemURL
        }

        let compositionMicTrack = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        )
        try compositionMicTrack?.insertTimeRange(
            CMTimeRange(start: .zero, duration: try await micAsset.load(.duration)),
            of: micAudioTrack,
            at: .zero
        )

        // Add system audio track
        let systemTracks = try await systemAsset.load(.tracks)
        guard let systemAudioTrack = systemTracks.first(where: { $0.mediaType == .audio }) else {
            // Return mic track only
            // Export just the mic composition
            return try await exportMergedComposition(composition, micPath: micPath)
        }

        let compositionSystemTrack = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        )
        try compositionSystemTrack?.insertTimeRange(
            CMTimeRange(start: .zero, duration: try await systemAsset.load(.duration)),
            of: systemAudioTrack,
            at: .zero
        )

        return try await exportMergedComposition(composition, micPath: micPath)
    }

    /// Export the merged composition to the permanent recordings/ location
    /// using the timestamp prefix pattern: {base}_merged.m4a
    private func exportMergedComposition(_ composition: AVMutableComposition, micPath: String) async throws -> URL {
        let micURL = URL(fileURLWithPath: micPath)
        let directory = micURL.deletingLastPathComponent()
        let baseName = micURL.deletingPathExtension().lastPathComponent
            .replacingOccurrences(of: "_mic", with: "")
        let mergedFileName = "\(baseName)\(AppConstants.mergedFileSuffix).\(AppConstants.audioFileExtension)"
        let mergedURL = directory.appendingPathComponent(mergedFileName)

        guard let exportSession = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPresetAppleM4A
        ) else {
            throw TranscriptionError.mergeFailed("Could not create export session")
        }

        exportSession.outputURL = mergedURL
        exportSession.outputFileType = .m4a

        await exportSession.export()

        guard exportSession.status == .completed else {
            throw TranscriptionError.mergeFailed(
                exportSession.error?.localizedDescription ?? "Export failed"
            )
        }

        return mergedURL
    }

    /// Persist the merged audio file for playback instead of deleting it.
    /// If the URL is already a permanent file (e.g., fell back to system/mic directly),
    /// returns it as-is. Otherwise, the export already wrote to the permanent path.
    /// This method ensures the file exists at the expected _merged.m4a location.
    private func persistMergedAudio(_ mergedAudioURL: URL, recording: RecordingInfo) -> URL {
        let fileManager = FileManager.default
        let recordingsDir = URL(fileURLWithPath: recording.micFilePath).deletingLastPathComponent()

        // Extract the expected permanent path
        let micURL = URL(fileURLWithPath: recording.micFilePath)
        let baseName = micURL.deletingPathExtension().lastPathComponent
            .replacingOccurrences(of: "_mic", with: "")
        let permanentFileName = "\(baseName)\(AppConstants.mergedFileSuffix).\(AppConstants.audioFileExtension)"
        let permanentURL = recordingsDir.appendingPathComponent(permanentFileName)

        // If already at the permanent location, return as-is
        if mergedAudioURL.path == permanentURL.path {
            return permanentURL
        }

        // If the merged file is already in recordings/ but with a different name,
        // rename it to the permanent pattern. If the source is the mic or system
        // file directly (no merge happened), leave it and return the merged URL.
        if mergedAudioURL.path == recording.micFilePath || mergedAudioURL.path == recording.systemFilePath {
            // No merged file was created; source was used directly
            return mergedAudioURL
        }

        // Move the temp merged file to the permanent location
        do {
            // Remove existing file at permanent location if any
            if fileManager.fileExists(atPath: permanentURL.path) {
                try fileManager.removeItem(at: permanentURL)
            }
            try fileManager.moveItem(at: mergedAudioURL, to: permanentURL)
            return permanentURL
        } catch {
            // Move failed — return original URL so playback can still attempt it
            return mergedAudioURL
        }
    }

    // MARK: - Private: Send to whisperX

    /// Send audio file to whisperX /transcribe endpoint per D-05.
    /// Returns raw whisperX response dictionary.
    private func sendToWhisperX(audioURL: URL) async throws -> [String: Any] {
        let urlString = "\(whisperXURL)\(AppConstants.whisperXTranscribeEndpoint)"

        guard let url = URL(string: urlString) else {
            throw TranscriptionError.serviceUnavailable("Invalid whisperX URL: \(whisperXURL)")
        }

        // Build multipart form data
        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 600  // 10 minutes for long recordings (T-03-02)

        var body = Data()

        // Add audio file
        let fileName = audioURL.lastPathComponent
        let fileData = try Data(contentsOf: audioURL)
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"audio_file\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/m4a\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n".data(using: .utf8)!)

        // Add parameters: enable diarization for speaker labeling per D-04
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"diarize\"\r\n\r\n".data(using: .utf8)!)
        body.append("true\r\n".data(using: .utf8)!)

        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"language\"\r\n\r\n".data(using: .utf8)!)
        body.append("auto\r\n".data(using: .utf8)!)

        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TranscriptionError.invalidResponse("Non-HTTP response from whisperX")
        }

        guard httpResponse.statusCode == 200 else {
            let responseBody = String(data: data, encoding: .utf8) ?? "unknown error"
            throw TranscriptionError.serviceUnavailable(
                "whisperX returned status \(httpResponse.statusCode): \(responseBody)"
            )
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw TranscriptionError.invalidResponse("Response is not a valid JSON object")
        }

        return json
    }

    // MARK: - Private: Parse whisperX Response

    /// Parse whisperX response into standardized TranscriptInfo per D-07/D-08.
    /// Validates all JSON fields before creating TranscriptInfo (T-03-05).
    private func parseWhisperXResponse(
        _ response: [String: Any],
        recordingId: UUID,
        audioPath: String,
        duration: Double
    ) -> TranscriptInfo {
        // Extract language with safe default
        let language = response["language"] as? String ?? "unknown"

        // Extract segments array with safe parsing (T-03-05)
        let rawSegments = response["segments"] as? [[String: Any]] ?? []
        var segments: [Segment] = []
        var speakerSet: [String: Speaker] = [:]

        for rawSegment in rawSegments {
            // Guard all required fields per T-03-05
            let speaker = rawSegment["speaker"] as? String ?? "SPEAKER_00"
            let startTime = rawSegment["start"] as? Double ?? 0.0
            let endTime = rawSegment["end"] as? Double ?? 0.0
            let text = rawSegment["text"] as? String ?? ""

            let segment = Segment(
                id: UUID(),
                speaker: speaker,
                startTime: startTime,
                endTime: endTime,
                text: text
            )
            segments.append(segment)

            // Track unique speakers
            if speakerSet[speaker] == nil {
                let speakerNumber = speakerSet.count + 1
                speakerSet[speaker] = Speaker(
                    id: speaker,
                    label: "Speaker \(speakerNumber)"
                )
            }
        }

        // Calculate total duration from segments if not provided
        let totalDuration: Double
        if duration > 0 {
            totalDuration = duration
        } else if let lastSegment = segments.last {
            totalDuration = lastSegment.endTime
        } else {
            totalDuration = 0
        }

        return TranscriptInfo(
            id: UUID(),
            recordingId: recordingId,
            language: language,
            duration: totalDuration,
            speakers: Array(speakerSet.values),
            segments: segments,
            transcribedAt: Date(),
            provider: "whisperX",
            audioFilePath: audioPath
        )
    }

    // MARK: - Private: Save Transcript

    /// Save TranscriptInfo as JSON to transcripts/ directory per D-09
    private func saveTranscript(_ transcript: TranscriptInfo) throws -> URL {
        let transcriptsDir = storageService.directoryURL(for: AppConstants.transcriptsDir)

        // Ensure transcripts directory exists
        try FileManager.default.createDirectory(
            at: transcriptsDir,
            withIntermediateDirectories: true
        )

        let fileURL = transcriptsDir.appendingPathComponent(transcript.fileName)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let data = try encoder.encode(transcript)
        try data.write(to: fileURL, options: .atomic)

        return fileURL
    }

    // MARK: - Private: File Utilities

    /// Get file size in bytes
    private func fileSize(of url: URL) -> UInt64 {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            return attributes[.size] as? UInt64 ?? 0
        } catch {
            return 0
        }
    }
}
