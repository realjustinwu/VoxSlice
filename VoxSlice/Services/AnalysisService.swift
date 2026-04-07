import Foundation

// MARK: - Analysis Service

/// AI-powered meeting analysis service per D-01 through D-08.
/// Takes a TranscriptInfo, calls AI provider Chat Completions API with a single structured prompt,
/// and saves the analysis as a Markdown file with YAML frontmatter.
@Observable
@MainActor
final class AnalysisService {

    // MARK: Published State

    var analysisStep: AnalysisStep = .idle
    var progress: Double = 0.0
    var lastAnalysis: AnalysisResult?
    var lastError: AnalysisError?

    // MARK: Dependencies

    private let storageService: StorageService

    // MARK: Init

    init(storageService: StorageService) {
        self.storageService = storageService
    }

    // MARK: - Public API

    /// Analyze a transcript using the configured AI provider.
    /// Returns a structured AnalysisResult and writes a Markdown file to the analysis/ directory.
    func analyze(transcript: TranscriptInfo) async throws -> AnalysisResult {
        // Reset state
        lastError = nil
        lastAnalysis = nil
        progress = 0.0

        // Read AI provider configuration
        guard let providerRaw = UserDefaults.standard.string(forKey: AppConstants.aiProviderKey),
              let provider = AIProvider(rawValue: providerRaw) else {
            let error = AnalysisError.noAPIKey
            analysisStep = .failed(error)
            lastError = error
            postFailureNotification(error)
            throw error
        }

        // Read API key from Keychain
        guard let apiKey = KeychainService.shared.read(key: provider.keychainAccount) else {
            let error = AnalysisError.noAPIKey
            analysisStep = .failed(error)
            lastError = error
            postFailureNotification(error)
            throw error
        }

        // Read endpoint URL (custom or default)
        let endpoint = UserDefaults.standard.string(forKey: AppConstants.aiEndpointURLKey)
            ?? provider.defaultEndpoint

        // Read analysis language setting
        let savedLanguage = UserDefaults.standard.string(forKey: AppConstants.analysisLanguageKey) ?? "auto"
        let analysisLanguage: String
        if savedLanguage == "auto" {
            analysisLanguage = transcript.language
        } else {
            analysisLanguage = savedLanguage
        }

        do {
            // Step 1: Preparing (progress 0.0 -> 0.10)
            analysisStep = .preparing
            progress = 0.05

            let transcriptText = formatTranscriptText(transcript)
            let systemPrompt = buildSystemPrompt(analysisLanguage: analysisLanguage)

            progress = 0.10

            // Step 2: Sending (progress 0.10 -> 0.70)
            analysisStep = .sending
            progress = 0.20

            let responseContent = try await sendToAIProvider(
                endpoint: endpoint,
                apiKey: apiKey,
                systemPrompt: systemPrompt,
                userMessage: transcriptText
            )

            progress = 0.70

            // Step 3: Processing (progress 0.70 -> 0.90)
            analysisStep = .processing
            progress = 0.75

            let analysisData = try parseAIResponse(responseContent)

            progress = 0.85

            let result = try buildAnalysisResult(
                analysisData: analysisData,
                transcript: transcript,
                provider: providerRaw,
                language: analysisLanguage
            )

            progress = 0.90

            // Step 4: Saving (progress 0.90 -> 1.0)
            analysisStep = .saving
            progress = 0.95

            let filePath = try saveAnalysisMarkdown(result, transcript: transcript)

            let finalResult = AnalysisResult(
                id: result.id,
                transcriptId: result.transcriptId,
                summary: result.summary,
                actionItems: result.actionItems,
                decisions: result.decisions,
                topics: result.topics,
                analyzedAt: result.analyzedAt,
                provider: result.provider,
                language: result.language,
                filePath: filePath
            )

            // Completion
            analysisStep = .completed
            progress = 1.0
            lastAnalysis = finalResult

            NotificationCenter.default.post(
                name: AppConstants.analysisDidCompleteNotification,
                object: self,
                userInfo: ["analysis": finalResult]
            )

            return finalResult

        } catch let error as AnalysisError {
            analysisStep = .failed(error)
            lastError = error
            postFailureNotification(error)
            throw error
        } catch {
            let analysisError = AnalysisError.networkError
            analysisStep = .failed(analysisError)
            lastError = analysisError
            postFailureNotification(analysisError)
            throw analysisError
        }
    }

    // MARK: - Private: Format Transcript Text

    /// Format transcript segments for the AI prompt per D-04 (include speaker labels and timestamps)
    private func formatTranscriptText(_ transcript: TranscriptInfo) -> String {
        let speakerMap = Dictionary(uniqueKeysWithValues: transcript.speakers.map { ($0.id, $0.label) })

        var lines: [String] = []
        for segment in transcript.segments {
            let speakerLabel = speakerMap[segment.speaker] ?? segment.speaker
            let startMM = formatTime(segment.startTime)
            let endMM = formatTime(segment.endTime)
            lines.append("[\(speakerLabel)] [\(startMM) - \(endMM)]: \(segment.text)")
        }

        return lines.joined(separator: "\n")
    }

    /// Format seconds as MM:SS
    private func formatTime(_ seconds: Double) -> String {
        let totalSeconds = Int(seconds)
        let minutes = totalSeconds / 60
        let secs = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, secs)
    }

    // MARK: - Private: Build System Prompt

    /// Build the system prompt per D-01 (single structured prompt) and D-02 (TL;DR + detailed)
    private func buildSystemPrompt(analysisLanguage: String) -> String {
        return """
        You are a meeting analysis assistant. Analyze the following meeting transcript and return a JSON object with this exact structure:
        {
          "summary": {
            "tldr": "one-line summary",
            "detailed": "detailed paragraph summary"
          },
          "action_items": [
            {"text": "action item description", "assignee": "name or null", "deadline": "deadline or null"}
          ],
          "decisions": ["decision 1", "decision 2"],
          "topics": [
            {"name": "topic name", "description": "brief description"}
          ]
        }
        Rules:
        - Summary must include both a concise TL;DR (one sentence) and a detailed paragraph
        - Action items must include assignee and deadline if mentioned in the transcript
        - Decisions should capture concrete decisions made, not discussion points
        - Topics should be the main themes discussed with brief descriptions
        - Write all output in \(analysisLanguage) language
        - Return ONLY valid JSON, no markdown formatting or explanation
        """
    }

    // MARK: - Private: Send to AI Provider

    /// POST to AI provider Chat Completions API per D-01
    private func sendToAIProvider(
        endpoint: String,
        apiKey: String,
        systemPrompt: String,
        userMessage: String
    ) async throws -> String {
        guard let url = URL(string: "\(endpoint)/chat/completions") else {
            throw AnalysisError.networkError
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 300  // 5 minutes for long transcripts (T-04-03)

        let requestBody: [String: Any] = [
            "model": "gpt-4o",
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userMessage]
            ],
            "response_format": ["type": "json_object"],
            "temperature": 0.3
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw AnalysisError.networkError
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AnalysisError.invalidResponse("Non-HTTP response from AI provider")
        }

        // Handle HTTP status codes per T-04-02
        switch httpResponse.statusCode {
        case 200...299:
            break
        case 401:
            throw AnalysisError.invalidAPIKey
        case 429, 503:
            throw AnalysisError.networkError
        case 400:
            // Check for context_length_exceeded error
            if let errorBody = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorDict = errorBody["error"] as? [String: Any],
               let errorCode = errorDict["code"] as? String,
               errorCode == "context_length_exceeded" {
                throw AnalysisError.contextTooLong
            }
            throw AnalysisError.invalidResponse("Bad request (status 400)")
        default:
            throw AnalysisError.invalidResponse("Unexpected status code: \(httpResponse.statusCode)")
        }

        // Extract response content
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw AnalysisError.invalidResponse("Could not extract content from AI response")
        }

        return content
    }

    // MARK: - Private: Parse AI Response

    /// Parse the JSON string from AI response into structured data per T-04-02
    private func parseAIResponse(_ content: String) throws -> [String: Any] {
        guard let jsonData = content.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            throw AnalysisError.invalidResponse("AI response is not valid JSON")
        }

        // Validate required fields exist (T-04-02)
        guard let summary = json["summary"] as? [String: Any],
              let _ = summary["tldr"] as? String,
              let _ = summary["detailed"] as? String else {
            throw AnalysisError.invalidResponse("Missing or invalid 'summary' field")
        }

        guard let _ = json["action_items"] as? [[String: Any]] else {
            throw AnalysisError.invalidResponse("Missing or invalid 'action_items' field")
        }

        guard let _ = json["decisions"] as? [String] else {
            throw AnalysisError.invalidResponse("Missing or invalid 'decisions' field")
        }

        guard let _ = json["topics"] as? [[String: Any]] else {
            throw AnalysisError.invalidResponse("Missing or invalid 'topics' field")
        }

        return json
    }

    // MARK: - Private: Build Analysis Result

    /// Build AnalysisResult from parsed JSON data
    private func buildAnalysisResult(
        analysisData: [String: Any],
        transcript: TranscriptInfo,
        provider: String,
        language: String
    ) throws -> AnalysisResult {
        // Parse summary
        guard let summaryDict = analysisData["summary"] as? [String: Any],
              let tldr = summaryDict["tldr"] as? String,
              let detailed = summaryDict["detailed"] as? String else {
            throw AnalysisError.invalidResponse("Invalid summary structure")
        }
        let summary = AnalysisSummary(tldr: tldr, detailed: detailed)

        // Parse action items
        let rawActionItems = analysisData["action_items"] as? [[String: Any]] ?? []
        let actionItems: [ActionItem] = rawActionItems.enumerated().compactMap { (index, item) in
            guard let text = item["text"] as? String else { return nil }
            return ActionItem(
                id: UUID(),
                index: index + 1,
                text: text,
                assignee: item["assignee"] as? String,
                deadline: item["deadline"] as? String
            )
        }

        // Parse decisions
        let decisions = (analysisData["decisions"] as? [String]) ?? []

        // Parse topics
        let rawTopics = analysisData["topics"] as? [[String: Any]] ?? []
        let topics: [Topic] = rawTopics.compactMap { item in
            guard let name = item["name"] as? String,
                  let description = item["description"] as? String else { return nil }
            return Topic(name: name, description: description)
        }

        return AnalysisResult(
            id: UUID(),
            transcriptId: transcript.id,
            summary: summary,
            actionItems: actionItems,
            decisions: decisions,
            topics: topics,
            analyzedAt: Date(),
            provider: provider,
            language: language,
            filePath: ""  // Will be updated after saving
        )
    }

    // MARK: - Private: Save Analysis Markdown

    /// Write Markdown file to analysis/ directory per D-05 through D-08
    private func saveAnalysisMarkdown(_ result: AnalysisResult, transcript: TranscriptInfo) throws -> String {
        let analysisDir = storageService.directoryURL(for: AppConstants.analysisDir)

        // Ensure analysis directory exists
        try FileManager.default.createDirectory(
            at: analysisDir,
            withIntermediateDirectories: true
        )

        // File naming: YYYY-MM-DD_HH-MM-SS_analysis.md per D-07
        let formatter = DateFormatter()
        formatter.dateFormat = AppConstants.recordingTimestampFormat
        let timestamp = formatter.string(from: transcript.transcribedAt)
        let fileName = "\(timestamp)\(AppConstants.analysisFileSuffix).\(AppConstants.analysisFileExtension)"
        let fileURL = analysisDir.appendingPathComponent(fileName)

        // Build Markdown content
        let markdown = buildMarkdownContent(result: result, transcript: transcript)

        // Write to file atomically (T-04-06: deterministic path, no user-supplied filename)
        try markdown.data(using: .utf8)?.write(to: fileURL, options: .atomic)

        return fileURL.path
    }

    // MARK: - Private: Build Markdown Content

    /// Build Markdown string with YAML frontmatter per D-05, D-06, D-08
    private func buildMarkdownContent(result: AnalysisResult, transcript: TranscriptInfo) -> String {
        // YAML frontmatter per D-06
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withColonSeparatorInTimeZone]
        let dateString = isoFormatter.string(from: transcript.transcribedAt)

        let durationString = result.formattedDuration(transcript.duration)

        let topicLines = result.topics.map { "  - \"\($0.name)\"" }.joined(separator: "\n")

        var markdown = """
        ---
        date: "\(dateString)"
        duration: "\(durationString)"
        language: "\(transcript.language)"
        topics:
        \(topicLines)
        ---

        """

        // Summary section per D-05 (section order: Summary first)
        markdown += "# Meeting Summary\n\n"
        markdown += "TL;DR: \(result.summary.tldr)\n\n"
        markdown += "\(result.summary.detailed)\n\n"

        // Action Items section per D-05 (second)
        markdown += "# Action Items\n\n"
        for item in result.actionItems {
            var actionLine = "\(item.index). \(item.text)"
            if let assignee = item.assignee {
                actionLine += " [\(assignee)]"
            }
            if let deadline = item.deadline {
                actionLine += " [\(deadline)]"
            }
            markdown += "\(actionLine)\n"
        }
        markdown += "\n"

        // Decisions section per D-05 (third)
        markdown += "# Decisions\n\n"
        for decision in result.decisions {
            markdown += "- \(decision)\n"
        }
        markdown += "\n"

        // Key Topics section per D-05 (fourth)
        markdown += "# Key Topics\n\n"
        for topic in result.topics {
            markdown += "- **\(topic.name)**: \(topic.description)\n"
        }
        markdown += "\n"

        return markdown
    }

    // MARK: - Private: Notifications

    private func postFailureNotification(_ error: AnalysisError) {
        NotificationCenter.default.post(
            name: AppConstants.analysisDidFailNotification,
            object: self,
            userInfo: ["error": error]
        )
    }
}
