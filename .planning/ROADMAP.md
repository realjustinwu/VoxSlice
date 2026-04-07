# Roadmap: VoxSlice

## Overview

VoxSlice goes from an empty Xcode project to a distributable Mac app that records meetings, transcribes them, and produces structured AI analysis as Markdown. The journey starts with the app shell and permission handling (the foundation everything depends on), then builds the audio capture engine (highest technical risk), followed by the transcription and analysis pipeline (core value delivery), then the dashboard and playback UI (daily usability), and finally the global hotkey and distribution packaging (completing the product).

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [x] **Phase 1: App Shell + Permissions + Settings** - Menu bar app lifecycle, macOS permission handling, and settings with secure API key storage (completed 2026-04-06)
- [ ] **Phase 2: Audio Capture Engine** - Dual-stream system audio + microphone recording with health monitoring
- [ ] **Phase 3: Transcription Pipeline** - Multi-provider STT with chunking, timestamps, and speaker diarization
- [ ] **Phase 4: AI Analysis + Markdown Output** - Structured meeting analysis and configurable Markdown export
- [ ] **Phase 5: Dashboard + Playback** - Recording history dashboard with synced audio playback
- [ ] **Phase 6: Global Hotkey + Distribution** - Global keyboard shortcut and installable DMG packaging

## Phase Details

### Phase 1: App Shell + Permissions + Settings
**Goal**: Users can launch the app, grant required permissions with clear guidance, and configure API keys securely
**Depends on**: Nothing (first phase)
**Requirements**: RECD-05, UIUX-02, UIUX-03
**Success Criteria** (what must be TRUE):
  1. User launches app and sees a menu bar icon with controls for recording
  2. User is prompted for Screen Recording and Microphone permissions with clear explanations, and the app handles the restart requirement for Screen Recording permission correctly
  3. User can open Settings and enter API keys for STT provider and AI provider, with keys stored securely in macOS Keychain (not UserDefaults)
  4. User can select and validate their STT provider choice in settings
**Plans:** 3/3 plans complete

Plans:
- [x] 01-01-PLAN.md — Xcode project scaffolding + menu bar app shell
- [x] 01-02-PLAN.md — Permission handling with card-based UI and restart flow
- [x] 01-03-PLAN.md — Settings window with Keychain, multi-provider config, and API key validation

### Phase 2: Audio Capture Engine
**Goal**: Users can record both microphone and system audio simultaneously with visual feedback that recording is active
**Depends on**: Phase 1
**Requirements**: RECD-02, RECD-03, RECD-04
**Success Criteria** (what must be TRUE):
  1. User can start recording and both microphone audio and system audio are captured simultaneously to separate compressed files
  2. Menu bar icon changes state to clearly indicate recording is active (visual recording indicator)
  3. Recording continues uninterrupted when the app window is hidden, minimized, or the app is in the background
  4. Recording survives audio device changes (e.g., headphone disconnect/reconnect) without crashing or silently stopping
**Plans:** 3 plans

Plans:
- [x] 02-01-PLAN.md — Dual-stream audio capture engine (ScreenCaptureKit + AVAudioEngine)
- [x] 02-02-PLAN.md — Recording coordinator with state machine, file management, and metadata
- [x] 02-03-PLAN.md — Menu bar recording UI and app integration wiring

### Phase 3: Transcription Pipeline
**Goal**: Users get accurate transcriptions with timestamps and speaker identification for recorded meetings via a user-managed whisperX HTTP service
**Depends on**: Phase 2
**Requirements**: TRSC-01, TRSC-02, TRSC-03, TRSC-04, TRSC-05
**Success Criteria** (what must be TRUE):
  1. User can transcribe a recording using their configured STT provider (whisperX local HTTP service as primary, cloud providers as backup)
  2. Transcription auto-detects and correctly handles Chinese, English, and mixed-language audio
  3. Transcript output includes timestamps for navigation through the recording
  4. Long recordings (60+ minutes) are automatically chunked and transcribed without hitting API upload limits
  5. Transcript identifies speakers (Speaker 1, Speaker 2, etc.) via speaker diarization
**Plans:** 2 plans

Plans:
- [x] 03-01-PLAN.md — Transcript data model, TranscriptionService with whisperX HTTP client, and AudioChunker
- [x] 03-02-PLAN.md — Wire transcription into RecordingCoordinator, MenuBarView, and Settings UI

### Phase 4: AI Analysis + Markdown Output
**Goal**: Users receive structured AI analysis of their meetings exported as shareable Markdown files
**Depends on**: Phase 3
**Requirements**: ANLY-01, ANLY-02, ANLY-03, ANLY-04, ANLY-05, OUTP-01, OUTP-02, OUTP-03
**Success Criteria** (what must be TRUE):
  1. User receives a concise meeting summary generated by AI after transcription completes
  2. AI extracts action items, key decisions, and main discussion topics from the transcript
  3. Analysis results are clearly structured and formatted (not raw AI output)
  4. All results are saved as a Markdown file with YAML frontmatter (date, duration, topics) to the user's configured output folder
  5. User can copy individual analysis sections to clipboard from within the app
**Plans:** 2 plans

Plans:
- [x] 04-01-PLAN.md — Analysis data models, AnalysisService with AI provider API call, and Markdown file writer
- [x] 04-02-PLAN.md — Wire analysis into lifecycle (auto-analysis), menu bar UI (6-state icon, progress, results, copy, retry), and settings language picker

### Phase 5: Dashboard + Playback
**Goal**: Users can browse their recording history and review meetings with synced audio playback
**Depends on**: Phase 4
**Requirements**: UIUX-01, UIUX-04
**Success Criteria** (what must be TRUE):
  1. User sees a full window dashboard with a list of all past recordings showing date, duration, and processing status
  2. User can click on any recording to view its transcript and analysis results
  3. User can play back audio and click on transcript text to jump to that moment in the recording
**Plans:** 3 plans

Plans:
- [x] 05-01-PLAN.md — Data layer: RecordingHistoryService, RecordingHistoryItem model, persist merged audio, shared CopyButton
- [x] 05-02-PLAN.md — Dashboard UI: NavigationSplitView window, sidebar with search, detail view with transcript + analysis sections
- [x] 05-03-PLAN.md — Audio playback: AVPlayer controls, transcript sync (click-to-seek, highlight, auto-scroll)

### Phase 6: Global Hotkey + Distribution
**Goal**: Users can start and stop recording from anywhere on Mac with a keyboard shortcut, and the app is distributable as a standard Mac application
**Depends on**: Phase 5
**Requirements**: RECD-01, DIST-01
**Success Criteria** (what must be TRUE):
  1. User can press a global keyboard shortcut from any application context to start or stop recording
  2. User can configure the global hotkey binding in settings
  3. User can install the app from a DMG file on a Mac
**Plans**: TBD

## Progress

**Execution Order:**
Phases execute in numeric order: 1 -> 2 -> 3 -> 4 -> 5 -> 6

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. App Shell + Permissions + Settings | 3/3 | Complete   | 2026-04-06 |
| 2. Audio Capture Engine | 3/3 | Complete   | 2026-04-06 |
| 3. Transcription Pipeline | 0/2 | Not started | - |
| 4. AI Analysis + Markdown Output | 0/2 | Not started | - |
| 5. Dashboard + Playback | 0/3 | Not started | - |
| 6. Global Hotkey + Distribution | 0/? | Not started | - |
