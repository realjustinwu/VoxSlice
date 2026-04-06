# Phase 2: Audio Capture Engine - Context

**Gathered:** 2026-04-06
**Status:** Ready for planning

<domain>
## Phase Boundary

Dual-stream audio recording engine: simultaneously capture microphone and system audio to separate compressed files, with menu bar recording controls, visual status indicators, and robust device change handling. Does NOT include transcription, AI analysis, or global hotkey — those are separate phases.

</domain>

<decisions>
## Implementation Decisions

### Audio Format & Quality
- **D-01:** Audio files saved as M4A (AAC) format — good compression, STT API compatible, Apple native
- **D-02:** Microphone and system audio saved as SEPARATE files with synchronized timestamps — enables natural speaker separation (mic = local, system = remote) for Phase 3 transcription and diarization
- **D-03:** Audio quality: 44.1kHz sample rate, 128kbps AAC bitrate — covers full human voice range, manageable file size (~60MB/hour), all STT APIs support it

### Recording Controls
- **D-04:** Single-click toggle on menu bar icon to start/stop recording — simple and intuitive
- **D-05:** Recording indicator: red dot overlay on menu bar icon — clear visual distinction, similar to macOS screen recording indicator
- **D-06:** Dropdown menu during recording shows: elapsed time (MM:SS) and a Stop button
- **D-07:** No notification or popup when recording stops — icon simply reverts to normal state

### Device Change Handling
- **D-08:** On audio device disconnect/reconnect: automatically switch to new default audio device without interrupting recording
- **D-09:** Silent switch + system notification (e.g., "Switched to MacBook Microphone") — user informed without workflow interruption

### Recording File Management
- **D-10:** Files named by timestamp: `YYYY-MM-DD_HH-MM-SS_mic.m4a` and `YYYY-MM-DD_HH-MM-SS_system.m4a` — sortable, unambiguous, no user input needed
- **D-11:** Metadata saved as a companion JSON file (`YYYY-MM-DD_HH-MM-SS.json`) containing: duration, sample rate, channel count, start/end time, device info
- **D-12:** Health monitoring: detect prolonged silence (30 seconds with no audio data) and automatically stop recording with a notification — prevents empty/invalid recordings

### Claude's Discretion
- Exact ScreenCaptureKit stream configuration and audio format conversion
- AVAudioEngine tap installation and buffer management
- Audio device change detection implementation (AVAudioApplication notifications or NotificationCenter)
- Silence detection algorithm and threshold
- File write error handling and recovery
- Memory management for long recordings

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase 1 Context
- `.planning/phases/01-app-shell-permissions-settings/01-CONTEXT.md` — Established patterns: services layer, menu bar setup, permission handling, output directory structure
- `.planning/phases/01-app-shell-permissions-settings/01-UI-SPEC.md` — UI design patterns, SF Symbol usage, component conventions

### Project Context
- `.planning/PROJECT.md` — Vision, constraints (macOS only, dual-stream capture, local storage)
- `.planning/REQUIREMENTS.md` — RECD-02 (dual-stream), RECD-03 (visual indicator), RECD-04 (background recording) are Phase 2 requirements
- `.planning/ROADMAP.md` — Phase 2 goal, success criteria, dependency on Phase 1

### Research
- `.planning/research/STACK.md` — ScreenCaptureKit, AVAudioEngine, AVFoundation technology recommendations
- `.planning/research/ARCHITECTURE.md` — Component boundaries and data flow for audio capture
- `.planning/research/PITFALLS.md` — Permission pitfalls and audio API limits

### Codebase Integration Points
- `VoxSlice/Services/PermissionManager.swift` — Microphone permission already handled; extend for system audio capture
- `VoxSlice/Services/StorageService.swift` — `recordings/` directory already created; file management utilities available
- `VoxSlice/Views/MenuBarView.swift` — Menu bar UI ready for recording controls and status display
- `VoxSlice/VoxSliceApp.swift` — App entry point with AppDelegate pattern

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **PermissionManager**: Microphone permission checking/requesting already implemented; screen recording permission handled — Phase 2 extends to verify both before starting capture
- **StorageService**: Creates `recordings/`, `transcripts/`, `analysis/`, `config/` directories; file path management ready
- **MenuBarView**: SwiftUI menu bar UI with `waveform.circle` icon; ready for recording state management

### Established Patterns
- `@Observable` classes for services (not Combine/ObservableObject)
- Security framework for Keychain, UserDefaults for preferences
- Services in `VoxSlice/Services/` directory
- Models in `VoxSlice/Models/` directory
- SF Symbols for icons, template mode for menu bar

### Integration Points
- Menu bar icon state → needs recording indicator overlay
- MenuBarView dropdown → needs recording controls (timer, stop button)
- PermissionManager → Phase 2 must check both mic + screen recording permissions before starting capture
- StorageService → recordings directory for file output
- AppDelegate → background audio session lifecycle management

</code_context>

<specifics>
## Specific Ideas

- Dual-stream separation (mic vs system) is the key advantage for speaker diarization — mic = local speaker, system = remote participants
- No third-party dependencies — use ScreenCaptureKit (system audio) and AVAudioEngine (microphone) natively
- Recording must survive app window hide, minimize, and background — menu bar app pattern already supports this

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 02-audio-capture-engine*
*Context gathered: 2026-04-06*
