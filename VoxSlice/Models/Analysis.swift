import Foundation

// MARK: - Analysis Error

/// Errors specific to AI analysis, per UI-SPEC copywriting contract
enum AnalysisError: Error, LocalizedError, Equatable {
    case noAPIKey           // "AI provider API key not configured. Set it in Settings."
    case invalidAPIKey      // "AI provider rejected the API key. Check Settings."
    case networkError       // "Could not connect to AI provider. Check your internet connection."
    case timeout            // "Analysis timed out. The transcript may be too long."
    case invalidResponse(String)  // "AI provider returned an unexpected response."
    case contextTooLong     // "Transcript exceeds AI context limit. Try a shorter recording."

    var errorDescription: String? {
        switch self {
        case .noAPIKey:
            return "AI provider API key not configured. Set it in Settings."
        case .invalidAPIKey:
            return "AI provider rejected the API key. Check Settings."
        case .networkError:
            return "Could not connect to AI provider. Check your internet connection."
        case .timeout:
            return "Analysis timed out. The transcript may be too long."
        case .invalidResponse(let message):
            return "AI provider returned an unexpected response. \(message)"
        case .contextTooLong:
            return "Transcript exceeds AI context limit. Try a shorter recording."
        }
    }

    static func == (lhs: AnalysisError, rhs: AnalysisError) -> Bool {
        switch (lhs, rhs) {
        case (.noAPIKey, .noAPIKey),
             (.invalidAPIKey, .invalidAPIKey),
             (.networkError, .networkError),
             (.timeout, .timeout),
             (.contextTooLong, .contextTooLong):
            return true
        case (.invalidResponse(let l), .invalidResponse(let r)):
            return l == r
        default:
            return false
        }
    }
}

// MARK: - Analysis Step

/// Progress step during analysis, per UI-SPEC state machine
enum AnalysisStep: Equatable {
    case idle
    case preparing          // 0.0 - 0.10 "Preparing transcript..."
    case sending            // 0.10 - 0.70 "Sending to AI provider..."
    case processing         // 0.70 - 0.90 "Processing response..."
    case saving             // 0.90 - 1.0  "Saving analysis..."
    case completed
    case failed(AnalysisError)
}

// MARK: - Analysis Summary

/// Meeting summary with TL;DR and detailed paragraph per D-02
struct AnalysisSummary: Codable, Equatable {
    let tldr: String       // One-line TL;DR summary (per D-02)
    let detailed: String   // Detailed paragraph summary (per D-02)
}

// MARK: - Action Item

/// An action item extracted from the meeting transcript per ANLY-03
struct ActionItem: Codable, Identifiable, Equatable {
    let id: UUID
    let index: Int
    let text: String
    let assignee: String?  // If mentioned in transcript
    let deadline: String?  // If mentioned in transcript
}

// MARK: - Topic

/// A key topic discussed during the meeting per ANLY-05
struct Topic: Codable, Equatable {
    let name: String
    let description: String
}

// MARK: - Analysis Result

/// Structured AI analysis result per UI-SPEC data model contract
struct AnalysisResult: Codable, Identifiable {
    let id: UUID
    let transcriptId: UUID
    let summary: AnalysisSummary
    let actionItems: [ActionItem]
    let decisions: [String]
    let topics: [Topic]
    let analyzedAt: Date
    let provider: String       // "openai", "deepseek", "zhipuai"
    let language: String       // Output language code
    let filePath: String       // Path to saved Markdown file

    /// Duration formatted as "Xm Ys" for YAML frontmatter
    func formattedDuration(_ seconds: Double) -> String {
        let totalSeconds = Int(seconds)
        let minutes = totalSeconds / 60
        let secs = totalSeconds % 60
        if minutes > 0 {
            return "\(minutes)m \(secs)s"
        }
        return "\(secs)s"
    }
}
