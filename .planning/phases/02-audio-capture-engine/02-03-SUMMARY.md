---
phase: 02-audio-capture-engine
plan: 03
subsystem: ui
tags: [swiftui, menu-bar, observable, bindable, recording-coordinator]

# Dependency graph
requires:
  - phase: 02-audio-capture-engine
    provides: AudioCaptureService (Plan 01), RecordingCoordinator (Plan 02), RecordingInfo model
provides:
  - Menu bar UI with recording start/stop controls and elapsed time display
  - Visual recording indicator (icon changes to red circle when recording)
  - Full dependency injection chain from AppDelegate through to MenuBarView
affects: [03-transcription, 04-ai-analysis, 05-ui-polish]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "@MainActor on AppDelegate for synchronous @Observable service initialization"
    - "@Bindable pattern for passing @Observable objects into SwiftUI views"
    - "Lazy var for deferred service creation in AppDelegate"

key-files:
  created: []
  modified:
    - VoxSlice/VoxSliceApp.swift
    - VoxSlice/Views/MenuBarView.swift

key-decisions:
  - "AppDelegate marked @MainActor to allow synchronous initialization of @MainActor @Observable services (AudioCaptureService, RecordingCoordinator)"
  - "Used record.circle SF Symbol for recording state icon (red circle) vs waveform.circle for idle state per D-05"
  - "Moved StorageService from VoxSliceApp @State to AppDelegate property for centralized dependency management"

patterns-established:
  - "AppDelegate as single dependency container: all services created there, passed via @NSApplicationDelegateAdaptor"
  - "MenuBarExtra systemImage binding to RecordingCoordinator state for icon changes"

requirements-completed: [RECD-03, RECD-04]

# Metrics
duration: 3min
completed: 2026-04-06
---

# Phase 2 Plan 3: Menu Bar Recording Controls Summary

**Recording controls wired into menu bar: start/stop toggle, elapsed time display (MM:SS), and visual recording indicator (red circle icon) using RecordingCoordinator via AppDelegate dependency injection**

## Performance

- **Duration:** 3 min
- **Started:** 2026-04-06T15:12:37Z
- **Completed:** 2026-04-06T15:15:37Z
- **Tasks:** 1
- **Files modified:** 2

## Accomplishments
- Full dependency injection chain: AppDelegate creates PermissionManager, StorageService, AudioCaptureService, RecordingCoordinator
- Menu bar icon dynamically switches between waveform.circle (idle) and record.circle (recording) per D-05
- MenuBarView shows context-sensitive controls: Start Recording button when idle, elapsed time + Stop Recording button when recording per D-04/D-06
- No notification or popup when recording stops -- icon simply reverts per D-07

## Task Commits

Each task was committed atomically:

1. **Task 1: Wire RecordingCoordinator into app and update MenuBarView with recording controls** - `cdf2ea3` (feat)

## Files Created/Modified
- `VoxSlice/VoxSliceApp.swift` - AppDelegate now creates all services (AudioCaptureService, RecordingCoordinator), marked @MainActor; VoxSliceApp passes coordinator to MenuBarView
- `VoxSlice/Views/MenuBarView.swift` - Recording-aware menu with @Bindable coordinator: Start/Stop buttons, elapsed time display, red recording indicator

## Decisions Made
- AppDelegate marked @MainActor to allow synchronous lazy var initialization of @MainActor @Observable services -- Swift concurrency requires same isolation context for synchronous init calls
- Used `record.circle` SF Symbol for recording state (provides red circle visual) vs `waveform.circle` for idle state -- clear visual distinction without needing overlay approach
- Moved StorageService from `@State private var` in VoxSliceApp to AppDelegate property for centralized dependency management alongside other services

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Added @MainActor to AppDelegate for service initialization**
- **Found during:** Task 1 (build verification)
- **Issue:** AudioCaptureService and RecordingCoordinator are @MainActor-isolated classes. Their initializers cannot be called synchronously from a non-isolated context (plain AppDelegate class). Build failed with "call to main actor-isolated initializer in a synchronous nonisolated context"
- **Fix:** Added `@MainActor` annotation to AppDelegate class declaration, making it execute on the main actor and allowing synchronous service initialization
- **Files modified:** VoxSlice/VoxSliceApp.swift
- **Verification:** Build succeeded with no errors
- **Committed in:** cdf2ea3 (part of task commit)

---

**Total deviations:** 1 auto-fixed (1 blocking)
**Impact on plan:** Essential fix for Swift 6 strict concurrency. No scope creep.

## Issues Encountered
- Swift 6 concurrency enforcement required @MainActor on AppDelegate -- services are @MainActor isolated so their container must be too

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Audio capture engine fully wired to UI. Phase 2 is complete.
- Ready for Phase 3 (transcription): recordings produce M4A files + metadata JSON in the recordings directory
- Ready for global hotkey implementation (can call coordinator.startRecording()/stopRecording() from hotkey handler)

## Self-Check: PASSED

- FOUND: VoxSlice/VoxSliceApp.swift
- FOUND: VoxSlice/Views/MenuBarView.swift
- FOUND: 02-03-SUMMARY.md
- FOUND: commit cdf2ea3

---
*Phase: 02-audio-capture-engine*
*Completed: 2026-04-06*
