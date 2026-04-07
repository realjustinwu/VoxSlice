import Foundation

// MARK: - Processing Status

/// Processing status computed from file existence on disk per D-06
enum ProcessingStatus: Equatable {
    case new           // Recording metadata exists, no transcript
    case transcribing  // Currently being transcribed
    case transcribed   // Transcript exists, no analysis
    case analyzing     // Currently being analyzed
    case completed     // Transcript + analysis both exist
    case failed        // Transcription or analysis failed
}

// MARK: - Recording History Item

/// Aggregated view model for a single recording in the dashboard.
/// Combines RecordingInfo with optional TranscriptInfo and AnalysisResult,
/// plus computed display properties and processing status.
struct RecordingHistoryItem: Identifiable {
    let id: UUID
    let recording: RecordingInfo
    let transcript: TranscriptInfo?
    let analysis: AnalysisResult?
    let status: ProcessingStatus
    var displayTitle: String
    var displaySummary: String?
}
