# Phase 5: Dashboard + Playback - Context

**Gathered:** 2026-04-07
**Status:** Ready for planning

<domain>
## Phase Boundary

Full window dashboard showing recording history with status, detail view for transcript + analysis, and synced audio playback. Users browse past recordings, view their transcripts and analysis, and play back audio with transcript sync (click transcript segment to jump to that moment). Builds on RecordingInfo (Phase 2), TranscriptInfo (Phase 3), and AnalysisResult (Phase 4) data models. Does NOT include global hotkeys, DMG distribution, or new recording/transcription/analysis capabilities.

</domain>

<decisions>
## Implementation Decisions

### Dashboard Window
- **D-01:** Menu bar item only — keep LSUIElement=true (no dock icon), add "Open Dashboard" menu item in the menu bar dropdown
- **D-02:** Sidebar + detail split view — left sidebar with recording list, right panel shows selected recording's detail (transcript, analysis, playback)
- **D-03:** Resizable window with minimum size (e.g., 800x500pt), remembers last position and size via UserDefaults. Close button hides window (app stays running in menu bar, reopen via menu bar)

### Recording List & Status
- **D-04:** Rich rows with preview — each sidebar row shows: date/time, duration, title (first topic or auto-generated), processing status color dot, 2-line summary preview, speaker count
- **D-05:** Newest first sort order by default
- **D-06:** Color dot for processing status — green = fully processed (transcribed + analyzed), yellow = in progress, red = failed, gray = new/not processed
- **D-07:** Search bar at top of sidebar — filters recordings by title, transcript text, and analysis content

### Detail View Layout
- **D-08:** Stacked layout — audio player controls at top, transcript in middle, analysis sections at bottom, all in a single scrollable view
- **D-09:** Transcript displayed as segment blocks — each segment shows speaker label (bold), timestamp bracket [MM:SS - MM:SS], and text below. Segments are clickable for audio jump.
- **D-10:** All analysis sections inline (Summary → Action Items → Decisions → Key Topics) with per-section copy buttons, reusing Phase 4 CopyButton pattern
- **D-11:** Placeholder message when no recording selected — centered app icon + "Select a recording to view details"
- **D-12:** Missing transcript or analysis sections show "not available" message with a retry button per section

### Audio Playback & Sync
- **D-13:** Play merged audio file only (mic + system combined). Note: current TranscriptionService creates a temporary merged file that is deleted after transcription — the planner must decide how to handle this (persist merged file, re-merge on demand, or play original system audio as fallback).
- **D-14:** Player controls: play/pause button, seekable timeline slider, current time / total time display, speed control (0.5x, 1.0x, 1.5x, 2.0x), skip forward/back ±15s buttons. No volume slider (use system volume).
- **D-15:** Click transcript segment → audio jumps to that segment's startTime. During playback, current segment is highlighted with subtle background color. Auto-scroll follows the highlighted segment.

### Claude's Discretion
- Dashboard window management (NSWindow lifecycle, SwiftUI WindowGroup vs NSWindow)
- Sidebar width and resize behavior
- How to load recording history from disk (scanning recordings/, transcripts/, analysis/ directories)
- How to determine recording processing status from existing data files
- AVPlayer vs AVAudioPlayer for playback implementation
- Highlight style for current transcript segment
- Search implementation (debounce, ranking, scope)
- How to handle the merged audio file availability for playback (persist, re-merge, or fallback)
- Exact player UI component design and layout
- Error handling for missing or corrupted audio/transcript/analysis files
- Empty recording list state

</decisions>

<specifics>
## Specific Ideas

- The merged audio file is currently temporary (created during transcription, deleted after). Playback needs a permanent merged file or a strategy to re-create it on demand. The simplest fix is to persist the merged file in recordings/ alongside the original mic and system files.
- Processing status must be inferred from file existence (recording metadata JSON exists → recorded; transcript JSON exists → transcribed; analysis MD exists → analyzed) since there is no database tracking status.
- Sidebar rows need a "title" but RecordingInfo has no title field. Use the first analysis topic name if available, otherwise fall back to date/time string as the display title.
- CopyButton from Phase 4 (private struct in MenuBarView) should be extracted to a shared component for reuse in the dashboard detail view.

</specifics>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Prior Phase Context
- `.planning/phases/01-app-shell-permissions-settings/01-CONTEXT.md` — Menu bar app shell (D-13), LSUIElement=true, Settings window pattern (D-21~D-25), directory structure (D-09/D-10)
- `.planning/phases/02-audio-capture-engine/02-CONTEXT.md` — Recording file naming (D-10), metadata JSON (D-11), dual-stream audio format (D-01/D-02)
- `.planning/phases/03-transcription-pipeline/03-CONTEXT.md` — Transcript JSON format (D-07/D-08), merged audio (D-13), auto-transcribe flow (D-10)
- `.planning/phases/04-ai-analysis-markdown-output/04-CONTEXT.md` — Analysis sections order (D-05), Markdown format (D-06~D-08), auto-analysis flow (D-09), CopyButton pattern (D-13)

### Project Context
- `.planning/PROJECT.md` — Vision, constraints (macOS only, multilingual, local storage)
- `.planning/REQUIREMENTS.md` — UIUX-01 (dashboard), UIUX-04 (playback sync) are Phase 5 requirements
- `.planning/ROADMAP.md` — Phase 5 goal, success criteria, depends on Phase 4

### Codebase Integration Points
- `VoxSlice/VoxSliceApp.swift` — AppDelegate with all services, MenuBarExtra entry point, needs "Open Dashboard" menu item
- `VoxSlice/Views/MenuBarView.swift` — Menu bar dropdown, needs "Open Dashboard" button; contains CopyButton private struct
- `VoxSlice/Services/StorageService.swift` — directoryURL(for:) for recordings/, transcripts/, analysis/ paths
- `VoxSlice/Services/RecordingCoordinator.swift` — Recording lifecycle, currentRecording, state management
- `VoxSlice/Services/TranscriptionService.swift` — Transcription state, lastTranscript, merged audio file creation (temp + cleanup)
- `VoxSlice/Services/AnalysisService.swift` — Analysis state, lastAnalysis
- `VoxSlice/Models/RecordingInfo.swift` — Recording metadata model (id, startTime, duration, micFilePath, systemFilePath, state)
- `VoxSlice/Models/Transcript.swift` — TranscriptInfo with segments (speaker + startTime + endTime + text), speakers list
- `VoxSlice/Models/Analysis.swift` — AnalysisResult with summary, actionItems, decisions, topics, filePath
- `VoxSlice/Utils/Constants.swift` — AppConstants (directory names, file extensions, notification names)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **StorageService**: directoryURL(for:) method returns URL for recordings/, transcripts/, analysis/ — dashboard can scan these to build recording history
- **RecordingInfo (Codable)**: Metadata JSON files in recordings/ can be decoded to get recording list. Contains startTime, duration, micFilePath, systemFilePath, state.
- **TranscriptInfo (Codable)**: Transcript JSON files in transcripts/ contain segments with startTime/endTime/speaker/text — directly usable for synced playback display
- **AnalysisResult (Codable)**: Analysis files in analysis/ — but stored as Markdown, not JSON. AnalysisResult is Codable so it could be re-parsed or stored as JSON companion
- **MenuBarView.CopyButton**: Private struct that copies text to clipboard with feedback — should extract for reuse in dashboard
- **AppDelegate**: Central service container — dashboard views can access all services through it

### Established Patterns
- `@Observable` class for services (not Combine/ObservableObject)
- Services in `VoxSlice/Services/`, Models in `VoxSlice/Models/`, Views in `VoxSlice/Views/`
- AppConstants for all constants (notification names, file extensions, directory names)
- Combine publishers + NotificationCenter for cross-service communication
- Settings uses NSWindow with NSHostingView for window management
- File naming: `YYYY-MM-DD_HH-MM-SS` prefix pattern across all file types

### Integration Points
- VoxSliceApp body → needs new WindowGroup or NSWindow for dashboard
- MenuBarView → needs "Open Dashboard" menu item
- StorageService → scan recordings/, transcripts/, analysis/ to build history
- RecordingCoordinator → recording state for current session
- TranscriptionService → merged audio file path (currently temp, needs strategy for playback)
- AnalysisService → analysis results for display

### Data Loading Strategy
Recordings are stored as individual files on disk. The dashboard needs to:
1. Scan recordings/ directory for `*.json` metadata files → decode as RecordingInfo
2. For each recording, check if matching transcript exists in transcripts/ (by timestamp prefix)
3. For each recording, check if matching analysis exists in analysis/ (by timestamp prefix)
4. Build an in-memory list of RecordingItem (RecordingInfo + optional TranscriptInfo + optional AnalysisResult)
5. This data loading service should be a new `RecordingHistoryService` or similar @Observable class

</code_context>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 05-dashboard-playback*
*Context gathered: 2026-04-07*
