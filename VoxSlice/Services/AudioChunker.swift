import Foundation
import AVFoundation

/// A stateless utility that handles audio file splitting for long recordings per D-11.
struct AudioChunker {

    // MARK: - Chunking Decision

    /// Check if a file needs to be chunked based on size per D-11.
    /// Returns true if file exceeds AppConstants.maxUploadFileSize (24MB).
    static func shouldChunk(fileURL: URL) -> Bool {
        let size = fileSize(of: fileURL)
        return size > AppConstants.maxUploadFileSize
    }

    /// Calculate how many chunks are needed based on file size.
    /// Each chunk targets AppConstants.maxUploadFileSize bytes.
    static func calculateChunkCount(fileURL: URL) -> Int {
        let size = fileSize(of: fileURL)
        guard size > 0 else { return 1 }

        let chunkSize = AppConstants.maxUploadFileSize
        let count = Int((UInt64(size) + chunkSize - 1) / chunkSize) // ceiling division
        return max(1, count)
    }

    // MARK: - Split Audio File

    /// Split an audio file into chunks of AppConstants.defaultChunkDuration (10 minutes) each.
    /// Returns array of temporary file URLs for each chunk.
    /// Uses AVAsset export with time ranges.
    static func splitAudioFile(
        _ fileURL: URL,
        chunkDuration: TimeInterval = AppConstants.defaultChunkDuration
    ) async throws -> [URL] {
        let asset = AVAsset(url: fileURL)
        let totalDuration = try await asset.load(.duration)

        guard totalDuration.seconds > 0 else {
            throw TranscriptionError.chunkFailed("Audio file has zero duration")
        }

        let totalSeconds = totalDuration.seconds
        let chunkCount = Int(ceil(totalSeconds / chunkDuration))
        var chunkURLs: [URL] = []

        // Create a temporary directory for chunks in the same directory as the source file
        let sourceDirectory = fileURL.deletingLastPathComponent()
        let chunksDirectoryName = "chunks_\(UUID().uuidString)"
        let chunksDirectory = sourceDirectory.appendingPathComponent(chunksDirectoryName)

        try FileManager.default.createDirectory(
            at: chunksDirectory,
            withIntermediateDirectories: true
        )

        for i in 0..<chunkCount {
            let startOffset = Double(i) * chunkDuration
            let remainingDuration = totalSeconds - startOffset
            let currentChunkDuration = min(chunkDuration, remainingDuration)

            guard currentChunkDuration > 0 else { break }

            let startTime = CMTime(seconds: startOffset, preferredTimescale: 600)
            let duration = CMTime(seconds: currentChunkDuration, preferredTimescale: 600)
            let timeRange = CMTimeRange(start: startTime, duration: duration)

            let chunkFileName = "chunk_\(String(format: "%03d", i)).\(AppConstants.audioFileExtension)"
            let chunkURL = chunksDirectory.appendingPathComponent(chunkFileName)

            guard let exportSession = AVAssetExportSession(
                asset: asset,
                presetName: AVAssetExportPresetAppleM4A
            ) else {
                // Clean up any already-created chunks on failure
                cleanupChunks(chunkURLs)
                throw TranscriptionError.chunkFailed("Could not create export session for chunk \(i + 1)")
            }

            exportSession.outputURL = chunkURL
            exportSession.outputFileType = .m4a
            exportSession.timeRange = timeRange

            await exportSession.export()

            guard exportSession.status == .completed else {
                cleanupChunks(chunkURLs)
                let errorMessage = exportSession.error?.localizedDescription ?? "unknown error"
                throw TranscriptionError.chunkFailed("Export of chunk \(i + 1) failed: \(errorMessage)")
            }

            chunkURLs.append(chunkURL)
        }

        guard !chunkURLs.isEmpty else {
            throw TranscriptionError.chunkFailed("No chunks were created")
        }

        return chunkURLs
    }

    // MARK: - Merge Chunk Results

    /// Merge transcript segments from multiple chunks into a single TranscriptInfo.
    /// Adjusts timestamps: chunk N segments have (N * chunkDuration) added to start/end.
    /// Speaker IDs are kept as-is since whisperX processes each chunk independently.
    static func mergeChunkResults(
        chunks: [TranscriptInfo],
        recordingId: UUID,
        totalDuration: Double,
        language: String,
        audioFilePath: String
    ) -> TranscriptInfo {
        guard !chunks.isEmpty else {
            return TranscriptInfo(
                id: UUID(),
                recordingId: recordingId,
                language: language,
                duration: totalDuration,
                speakers: [],
                segments: [],
                transcribedAt: Date(),
                provider: "whisperX",
                audioFilePath: audioFilePath
            )
        }

        var allSegments: [Segment] = []
        var allSpeakers: [String: Speaker] = [:]
        let chunkDuration = AppConstants.defaultChunkDuration

        for (chunkIndex, chunk) in chunks.enumerated() {
            let timeOffset = Double(chunkIndex) * chunkDuration

            for segment in chunk.segments {
                // Offset timestamps by chunk position
                let adjustedSegment = Segment(
                    id: UUID(),
                    speaker: segment.speaker,
                    startTime: segment.startTime + timeOffset,
                    endTime: segment.endTime + timeOffset,
                    text: segment.text
                )
                allSegments.append(adjustedSegment)

                // Collect unique speakers (deduplicate by ID)
                if allSpeakers[segment.speaker] == nil {
                    let speakerNumber = allSpeakers.count + 1
                    allSpeakers[segment.speaker] = Speaker(
                        id: segment.speaker,
                        label: "Speaker \(speakerNumber)"
                    )
                }
            }
        }

        // Sort segments chronologically after merging
        allSegments.sort { $0.startTime < $1.startTime }

        // Use the language from the first chunk (or majority could be computed later)
        let mergedLanguage = language.isEmpty ? (chunks.first?.language ?? "unknown") : language

        return TranscriptInfo(
            id: UUID(),
            recordingId: recordingId,
            language: mergedLanguage,
            duration: totalDuration,
            speakers: Array(allSpeakers.values),
            segments: allSegments,
            transcribedAt: Date(),
            provider: "whisperX",
            audioFilePath: audioFilePath
        )
    }

    // MARK: - Cleanup

    /// Clean up temporary chunk files and their parent directory
    static func cleanupChunks(_ chunkURLs: [URL]) {
        guard !chunkURLs.isEmpty else { return }

        // Remove the parent chunks directory (contains all chunk files)
        let parentDirectory = chunkURLs.first?.deletingLastPathComponent()
        if let directory = parentDirectory {
            try? FileManager.default.removeItem(at: directory)
        }

        // Also try removing individual files as a fallback
        for url in chunkURLs {
            try? FileManager.default.removeItem(at: url)
        }
    }

    // MARK: - Private Utilities

    /// Get file size in bytes
    private static func fileSize(of url: URL) -> UInt64 {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            return attributes[.size] as? UInt64 ?? 0
        } catch {
            return 0
        }
    }
}
