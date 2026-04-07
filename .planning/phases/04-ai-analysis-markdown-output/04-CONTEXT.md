# Phase 4: AI Analysis + Markdown Output - Context

**Gathered:** 2026-04-07
**Status:** Ready for planning

<domain>
## Phase Boundary

Structured AI analysis of meeting transcripts (summary, action items, decisions, key topics) and export as shareable Markdown files with YAML frontmatter. Builds an AnalysisService that takes TranscriptInfo output from Phase 3, sends it to the user's configured AI provider (OpenAI/Deepseek/ZhipuAI), and saves structured Markdown to the analysis/ directory. Does NOT include dashboard UI, audio playback, or global hotkeys — those are separate phases.

</domain>

<decisions>
## Implementation Decisions

### Analysis Structure & Prompt Design
- **D-01:** Single structured prompt — one API call returns ALL analysis sections (summary, action items, decisions, topics) as structured JSON. Simpler, faster, fewer tokens than multiple calls.
- **D-02:** Meeting summary includes both a one-line TL;DR and a detailed paragraph — covers quick scanning and deep reading.
- **D-03:** Analysis output language is user-configurable in Settings — user picks their preferred language, not auto-detected from transcript. Adds a language setting to existing Settings infrastructure.
- **D-04:** AI prompt includes the full transcript text with speaker labels and timestamps so the AI has complete context for analysis.

### Markdown Output Format
- **D-05:** Section order in Markdown: Summary → Action Items → Decisions → Key Topics. Big picture first, details after.
- **D-06:** Minimal YAML frontmatter: date, duration (formatted string), language (detected from transcript), topics (list of strings). No extra metadata.
- **D-07:** File naming: `YYYY-MM-DD_HH-MM-SS_analysis.md` — consistent with recording and transcript naming convention. Stored in `analysis/` directory.
- **D-08:** Markdown formatting: clear headers per section, bullet lists for action items, numbered lists where appropriate. Professional meeting-notes style.

### Analysis Trigger & UX Flow
- **D-09:** Analysis triggers automatically after transcription completes — same auto-chain pattern as recording → transcription. RecordingCoordinator chains: recording stop → transcribe → analyze.
- **D-10:** Menu bar icon changes to analysis state (e.g., sparkles icon) during analysis, dropdown shows "Analyzing..." progress — consistent with existing transcription status pattern.
- **D-11:** On analysis failure (API error, invalid key, network): menu bar dropdown shows error with a "Retry" button — same pattern as transcription retry (Phase 3 D-13).

### In-App Interaction with Results
- **D-12:** Analysis sections shown in menu bar dropdown (scrollable view) — quick access without opening a new window. Limited to showing most recent analysis.
- **D-13:** Per-section copy buttons in the dropdown — user can copy individual sections (summary, action items, etc.) to clipboard. Fulfills OUTP-03.

### Claude's Discretion
- Exact JSON schema for AI response parsing
- AI prompt wording and system message design
- Markdown formatting details (bold, headers, spacing)
- Retry strategy for analysis failures
- How to handle very long transcripts that exceed AI context window
- Error message wording
- Analysis state data model and state machine

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Prior Phase Context
- `.planning/phases/01-app-shell-permissions-settings/01-CONTEXT.md` — AI provider config (D-05~D-08), Keychain storage (D-11), Settings UI patterns (D-21~D-25), directory structure (D-09/D-10)
- `.planning/phases/02-audio-capture-engine/02-CONTEXT.md` — Recording metadata model, file naming convention
- `.planning/phases/03-transcription-pipeline/03-CONTEXT.md` — Transcript JSON format (D-07/D-08), auto-transcribe flow (D-10), menu bar state pattern

### Project Context
- `.planning/PROJECT.md` — Vision, constraints (macOS only, multilingual, BYOK model)
- `.planning/REQUIREMENTS.md` — ANLY-01~ANLY-05, OUTP-01~OUTP-03 are Phase 4 requirements
- `.planning/ROADMAP.md` — Phase 4 goal, success criteria, depends on Phase 3

### Codebase Integration Points
- `VoxSlice/Models/Provider.swift` — AIProvider enum (openAI, deepseek, zhipuAI) with OpenAI-compatible API endpoints
- `VoxSlice/Models/Transcript.swift` — TranscriptInfo model (input for analysis), Segment and Speaker structs
- `VoxSlice/Models/RecordingInfo.swift` — Recording metadata (duration, timestamps)
- `VoxSlice/Services/StorageService.swift` — `analysis/` directory, output folder config
- `VoxSlice/Services/RecordingCoordinator.swift` — Lifecycle chain (recording → transcription → analysis trigger point)
- `VoxSlice/Services/TranscriptionService.swift` — Pattern reference for AnalysisService structure
- `VoxSlice/Utils/Constants.swift` — AppConstants (analysis dir, notification names, file naming)
- `VoxSlice/Views/MenuBarView.swift` — Menu bar UI for showing analysis state and results
- `VoxSlice/Views/Settings/SettingsView.swift` — Settings tab pattern for adding analysis language config

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **AIProvider enum**: Already defined with openAI, deepseek, zhipuAI — each has displayName, defaultEndpoint, keychainAccount. All use OpenAI-compatible Chat Completions API.
- **TranscriptInfo model**: Structured transcript output with segments (speaker + timestamps + text), speakers list, language, duration — this is the analysis input.
- **StorageService**: `analysis/` directory already created via `createDirectoryStructure()`. `directoryURL(for:)` method for getting paths.
- **RecordingCoordinator**: Full lifecycle management. `startTranscription()` method is the pattern for `startAnalysis()`. Already posts `transcriptionDidComplete` notification — analysis hooks in here.
- **TranscriptionService**: Pattern reference for building AnalysisService — same @Observable class pattern, same error handling, same notification-based communication.
- **KeychainService**: Already stores AI provider API keys — analysis service reads keys from here.
- **ProviderValidationService**: Pattern for validating AI provider connectivity.

### Established Patterns
- `@Observable` class for services (not Combine/ObservableObject)
- Services in `VoxSlice/Services/` directory
- Models in `VoxSlice/Models/` directory
- AppConstants for all constants (notification names, file extensions, directory names)
- Combine publishers + NotificationCenter for cross-service communication
- Settings uses TabView with separate tabs per feature area
- Menu bar icon switches between states (idle, recording, transcribing)

### Integration Points
- RecordingCoordinator.startTranscription() → after transcription completes, post notification → trigger analysis
- TranscriptionService.transcriptionDidCompleteNotification → hook for starting analysis
- MenuBarView → needs new state for "analyzing" and display of analysis results
- SettingsView → needs new tab or section for analysis language preference
- StorageService.analysisDir → analysis Markdown file output location
- AIProvider + KeychainService → reading AI API key and endpoint for analysis API calls

</code_context>

<specifics>
## Specific Ideas

- Analysis language is a user choice, not auto-detected — user may prefer reading analysis in English even for Chinese meetings, or vice versa
- TL;DR + detailed summary format gives both quick-scan and deep-read options in one output
- Single prompt with structured JSON output is efficient — one API call gets all sections, then app formats into Markdown
- Menu bar is the primary interaction surface for Phase 4 (no dashboard until Phase 5)

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 04-ai-analysis-markdown-output*
*Context gathered: 2026-04-07*
