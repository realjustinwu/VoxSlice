import Foundation

// MARK: - Speaker

/// A speaker identified during transcription per D-08
struct Speaker: Codable, Identifiable, Equatable {
    let id: String       // e.g., "SPEAKER_00"
    let label: String    // e.g., "Speaker 1"

    var name: String { label }
}

// MARK: - Segment

/// A single transcript segment with timing and speaker per D-08
struct Segment: Codable, Identifiable, Equatable {
    let id: UUID
    let speaker: String       // Speaker ID, e.g., "SPEAKER_00"
    let startTime: Double     // seconds from start
    let endTime: Double       // seconds from start
    let text: String
}

// MARK: - Transcript Info

/// Standardized transcript output per D-07/D-08
struct TranscriptInfo: Codable, Identifiable {
    let id: UUID
    let recordingId: UUID
    let language: String              // detected language code, e.g., "zh", "en"
    let duration: Double              // total duration in seconds
    let speakers: [Speaker]
    let segments: [Segment]
    let transcribedAt: Date
    let provider: String              // "whisperX", "openai", etc.
    let audioFilePath: String         // path of the audio file that was transcribed

    /// File name for this transcript, matching the recording timestamp per D-09
    /// Format: YYYY-MM-DD_HH-MM-SS_transcript.json
    var fileName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = AppConstants.recordingTimestampFormat
        let timestamp = formatter.string(from: transcribedAt)
        return "\(timestamp)\(AppConstants.transcriptFileSuffix).\(AppConstants.transcriptFileExtension)"
    }
}
