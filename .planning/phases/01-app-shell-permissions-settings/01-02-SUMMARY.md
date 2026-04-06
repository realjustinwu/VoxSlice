---
phase: 01-app-shell-permissions-settings
plan: 02
subsystem: ui
tags: [swift, swiftui, macos, permissions, appkit, coregraphics, avfoundation]

# Dependency graph
requires:
  - phase: 01-app-shell-permissions-settings
    plan: 01
    provides: "App entry point (VoxSliceApp.swift) and Xcode project structure"
provides:
  - "PermissionManager service with Screen Recording and Microphone permission checking"
  - "PermissionsView with card-based UI, status badges, and System Settings deep-links"
  - "AppDelegate managing permissions window lifecycle on first launch"
  - "Screen Recording restart alert with Restart/Later buttons"
  - "Auto-dismiss of permissions window when all permissions granted"
affects: [01-03-settings, audio-capture, transcription]

# Tech tracking
tech-stack:
  added: [coregraphics, avfoundation]
  patterns: [app-delegate-window-management, observable-permission-service, deep-link-settings]

key-files:
  created:
    - VoxSlice/Services/PermissionManager.swift
    - VoxSlice/Views/PermissionsView.swift
  modified:
    - VoxSlice/VoxSliceApp.swift
    - VoxSlice.xcodeproj/project.pbxproj

key-decisions:
  - "Used AppDelegate with NSApplicationDelegateAdaptor to manage permissions window, since SwiftUI App protocol does not provide direct access to openWindow"
  - "Used CGPreflightScreenCaptureAccess() for Screen Recording check (does not trigger system prompt) instead of CGRequestScreenCaptureAccess()"
  - "Used AVAudioApplication.shared.recordPermission for Microphone check and AVAudioApplication.requestRecordPermission() for requesting"

patterns-established:
  - "AppDelegate pattern: NSApplicationDelegateAdaptor for managing NSWindow lifecycle outside SwiftUI scenes"
  - "Permission polling: Re-check permissions on didBecomeActiveNotification when user returns from System Settings"

requirements-completed: [RECD-05]

# Metrics
duration: 8min
completed: 2026-04-06
---

# Phase 01 Plan 02: Permission Handling Summary

**Permission checking service and card-based UI guiding users through Screen Recording and Microphone permissions with restart flow**

## Performance

- **Duration:** 8 min
- **Started:** 2026-04-06T10:10:00Z
- **Completed:** 2026-04-06T10:18:00Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments
- PermissionManager service with CGPreflightScreenCaptureAccess for Screen Recording and AVAudioApplication for Microphone
- Card-based PermissionsView with status badges (Granted/Not Granted), deep-links to System Settings privacy panes
- AppDelegate managing permissions window that opens automatically on first launch when permissions missing
- Restart alert for Screen Recording with Restart/Later buttons, auto-dismiss when all permissions granted

## Task Commits

Each task was committed atomically:

1. **Task 1: Create PermissionManager service** - `e7362ea` (feat)
2. **Task 2: Create PermissionsView and wire into app lifecycle** - `a4d9a5f` (feat)

## Files Created/Modified
- `VoxSlice/Services/PermissionManager.swift` - Observable permission service with checking, monitoring, deep-links, and restart capability
- `VoxSlice/Views/PermissionsView.swift` - Card-based permission UI with PermissionCard component for Screen Recording and Microphone
- `VoxSlice/VoxSliceApp.swift` - Added AppDelegate with NSApplicationDelegateAdaptor for permissions window lifecycle
- `VoxSlice.xcodeproj/project.pbxproj` - Added new source files to build

## Decisions Made
- Used AppDelegate via NSApplicationDelegateAdaptor to manage the permissions NSWindow, since SwiftUI's App protocol does not provide a convenient way to programmatically open windows on launch. This is a standard pattern for SwiftUI Mac apps that need imperative window management.
- Used CGPreflightScreenCaptureAccess() (read-only check) rather than CGRequestScreenCaptureAccess() (triggers system prompt) to avoid surprising users with a system dialog before they understand why the permission is needed.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- PermissionManager and PermissionsView are ready for Phase 2 (Audio Capture) which depends on both Screen Recording and Microphone permissions
- The restart flow ensures that after Screen Recording is granted, the app correctly restarts so ScreenCaptureKit can function
- Plan 03 (Settings) can now proceed independently since it only depends on Plan 01 (completed)

---
*Phase: 01-app-shell-permissions-settings*
*Completed: 2026-04-06*
