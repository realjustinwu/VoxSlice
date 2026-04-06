---
phase: 02-audio-capture-engine
plan: 02
subsystem: audio
tags: [recording, coordinator, state-machine, notifications, combine]

# Dependency graph
requires:
  - phase: 02-audio-capture-engine/01
    provides: AudioCaptureService, RecordingInfo model, AppConstants
provides:
  - RecordingCoordinator with start/stop lifecycle API
  - Coordinator-level notification names for UI binding
  - MM:SS formatted elapsed time for display
affects: [02-03, menu-bar-ui]

# Tech tracking
tech-stack:
  added: []
  patterns: [coordinator-delegation, notification-forwarding, combine-state-sync]

key-files:
  created:
    - VoxSlice/Services/RecordingCoordinator.swift
  modified:
    - VoxSlice/Utils/Constants.swift
    - VoxSlice.xcodeproj/project.pbxproj

key-decisions:
  - "RecordingCoordinator delegates entirely to AudioCaptureService rather than reimplementing audio capture logic"
  - "Used Combine publishers to observe AudioCaptureService notifications and sync state"
  - "Coordinator syncs elapsed duration via 0.5s timer rather than reimplementing its own duration counter"
  - "Notification names defined in AppConstants for single source of truth, aliased in RecordingCoordinator for convenience"

patterns-established:
  - "Coordinator pattern: thin orchestration layer that delegates to services and forwards events"
  - "Notification forwarding: capture-service internal notifications -> coordinator public notifications"

requirements-completed: [RECD-02, RECD-04]

# Metrics
duration: 6min
completed: 2026-04-06
---

# Phase 2 Plan 02: Recording Coordinator Summary

**RecordingCoordinator orchestrates full recording lifecycle by delegating to AudioCaptureService, forwarding device change and silence events, and providing MM:SS elapsed time and public notification API for menu bar UI**

## Performance

- **Duration:** 6 min
- **Started:** 2026-04-06T15:02:06Z
- **Completed:** 2026-04-06T15:08:17Z
- **Tasks:** 1
- **Files modified:** 3

## Accomplishments
- RecordingCoordinator provides clean startRecording/stopRecording API with state machine guards
- Delegates audio capture entirely to AudioCaptureService (no duplicate audio logic)
- Forwards device change events and silence detection as coordinator-level notifications
- formattedElapsedTime returns MM:SS format for UI binding
- Notification name constants centralized in AppConstants

## Task Commits

Each task was committed atomically:

1. **Task 1: Implement RecordingCoordinator with state machine and file management** - `4aa5dbc` (feat)

## Files Created/Modified
- `VoxSlice/Services/RecordingCoordinator.swift` - Recording lifecycle coordinator delegating to AudioCaptureService
- `VoxSlice/Utils/Constants.swift` - Added notification name constants for coordinator events
- `VoxSlice.xcodeproj/project.pbxproj` - Registered RecordingCoordinator.swift in project

## Decisions Made
- **Full delegation to AudioCaptureService:** AudioCaptureService already handles file naming, metadata saving, timers, and audio capture. RecordingCoordinator wraps it with state guards, permission checks, and notification forwarding rather than reimplementing any of that logic.
- **Combine-based state sync:** Used Combine publishers with a 0.5s polling timer to sync elapsed duration from AudioCaptureService. This avoids tight coupling while keeping the coordinator's elapsed time reasonably accurate.
- **Single source of truth for notification names:** Defined in AppConstants and aliased in RecordingCoordinator static properties for convenience.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Removed deinit from @MainActor class**
- **Found during:** Task 1 (RecordingCoordinator implementation)
- **Issue:** `deinit` is nonisolated in @MainActor classes, so `cancellables.removeAll()` caused a compile error: "main actor-isolated property 'cancellables' can not be mutated from a nonisolated context"
- **Fix:** Removed the deinit entirely -- AnyCancellable objects auto-cancel when the array is deallocated, so explicit cleanup is unnecessary
- **Files modified:** VoxSlice/Services/RecordingCoordinator.swift
- **Verification:** Build succeeds without errors
- **Committed in:** 4aa5dbc (Task 1 commit)

**2. [Rule 1 - Bug] Coordinator references AppConstants for notification names instead of duplicating string literals**
- **Found during:** Task 1 (RecordingCoordinator implementation)
- **Issue:** Plan said to add notification names to Constants.swift but also define them inline in RecordingCoordinator -- this creates duplicate definitions that could drift
- **Fix:** RecordingCoordinator static properties now reference AppConstants constants for single source of truth
- **Files modified:** VoxSlice/Services/RecordingCoordinator.swift, VoxSlice/Utils/Constants.swift
- **Verification:** Build succeeds, notification names are consistent
- **Committed in:** 4aa5dbc (Task 1 commit)

---

**Total deviations:** 2 auto-fixed (1 blocking, 1 bug)
**Impact on plan:** Both auto-fixes necessary for correctness and build success. No scope creep.

## Issues Encountered
- pbxproj file uses mixed tab/space indentation which made editing with string replacement difficult; resolved by using Python for precise edits

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- RecordingCoordinator ready for menu bar UI binding in Plan 03
- UI can observe RecordingCoordinator.state, .formattedElapsedTime, .currentRecording
- UI can call startRecording()/stopRecording() directly
- Device change and failure notifications available via coordinator-level Notification.Names

---
*Phase: 02-audio-capture-engine*
*Completed: 2026-04-06*

## Self-Check: PASSED

- FOUND: VoxSlice/Services/RecordingCoordinator.swift
- FOUND: VoxSlice/Utils/Constants.swift
- FOUND: commit 4aa5dbc
