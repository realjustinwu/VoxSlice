# Phase 6: Global Hotkey + Distribution - Context

**Gathered:** 2026-04-08
**Status:** Ready for planning

<domain>
## Phase Boundary

Global keyboard shortcut to start/stop recording from any application context, plus DMG packaging for distributable Mac app installation. Builds on RecordingCoordinator (Phase 2) for recording lifecycle and Settings window (Phase 1) for hotkey configuration. Does NOT include new recording/transcription/analysis capabilities, cloud sync, or auto-update mechanism.

</domain>

<decisions>
## Implementation Decisions

### Hotkey Implementation
- **D-01:** Use NSEvent.addGlobalMonitorForEvents(matching: .keyDown) — no Accessibility permission needed, simpler API than CGEventTap, sufficient for key combo detection
- **D-02:** Default shortcut: Cmd+Shift+R — common pattern for media/recording apps, easy to remember, unlikely to conflict with system shortcuts
- **D-03:** Toggle behavior — same shortcut starts and stops recording, matching the menu bar single-click toggle pattern from Phase 2 (D-04)
- **D-04:** GlobalHotkeyService as a new @Observable service in VoxSlice/Services/ — registers/unregisters NSEvent monitor, stores shortcut configuration in UserDefaults, calls RecordingCoordinator.toggleRecording()

### Hotkey Configuration
- **D-05:** Hotkey configuration in existing Settings General tab — add a "Recording Shortcut" section below the output folder picker, no new tab needed
- **D-06:** Button-triggered hotkey recorder — user clicks "Record Shortcut" button, presses key combo, displays captured combination. Standard macOS pattern (like System Settings > Keyboard > Keyboard Shortcuts)
- **D-07:** Store hotkey as modifier flags + keyCode in UserDefaults (key: "globalHotkey") with sensible default (Cmd+Shift+R)
- **D-08:** Allow user to clear/disable the global hotkey (optional feature)

### Hotkey Feedback
- **D-09:** Menu bar icon change only — waveform.circle → record.circle (already implemented in Phase 2 D-05). No extra system notification or sound. Clean, minimal, matches existing behavior

### DMG Distribution
- **D-10:** Use create-dmg community tool for DMG creation — professional DMG with background image, Applications folder shortcut, and window positioning
- **D-11:** Unsigned DMG for v1 — no code signing or notarization. Users may see Gatekeeper warnings (bypass via right-click > Open). Code signing can be added later with Apple Developer certificate
- **D-12:** Create a build script (scripts/build-dmg.sh) that: archives the app via xcodebuild, creates DMG via create-dmg, outputs to build/ directory

### Claude's Discretion
- Exact NSEvent monitor implementation details (handler logic, modifier flag matching)
- Hotkey recorder SwiftUI component (capture key events, display formatting)
- DMG window size, background image design, and icon positioning
- Build script structure and error handling
- Handling hotkey conflicts with system shortcuts
- Edge cases: hotkey during permissions flow, hotkey when recording is transcribing/analyzing

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Prior Phase Context
- `.planning/phases/01-app-shell-permissions-settings/01-CONTEXT.md` — Settings window pattern (D-21~D-25), LSUIElement=true (D-13), menu bar icon (D-14), UserDefaults keys pattern
- `.planning/phases/02-audio-capture-engine/02-CONTEXT.md` — Recording toggle behavior (D-04), recording indicator (D-05), RecordingCoordinator integration

### Project Context
- `.planning/PROJECT.md` — Vision, constraints (macOS only, native Mac app, zero dependencies)
- `.planning/REQUIREMENTS.md` — RECD-01 (global shortcut), DIST-01 (DMG distribution) are Phase 6 requirements
- `.planning/ROADMAP.md` — Phase 6 goal, success criteria, depends on Phase 5

### Research
- `.planning/research/STACK.md` — CGEvent/NSEvent for global hotkeys (MEDIUM confidence), create-dmg for distribution (MEDIUM confidence), KeyboardShortcuts library as fallback

### Codebase Integration Points
- `VoxSlice/VoxSliceApp.swift` — AppDelegate with all services, needs GlobalHotkeyService registration
- `VoxSlice/Views/MenuBarView.swift` — Menu bar dropdown with Cmd+R/Cmd+S keyboard shortcuts (in-menu only)
- `VoxSlice/Services/RecordingCoordinator.swift` — Recording lifecycle, toggleRecording() or startRecording()/stopRecording()
- `VoxSlice/Utils/Constants.swift` — AppConstants for UserDefaults keys, notification names
- `VoxSlice/Info.plist` — LSUIElement=true, bundle identifier com.voxslice.app

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **RecordingCoordinator**: Manages recording state machine. Phase 2 D-04 established single-click toggle — GlobalHotkeyService calls the same toggle
- **MenuBarView**: Already has Cmd+R/Cmd+S `.keyboardShortcut` modifiers (only work when menu is open). Icon state already switches between waveform.circle and record.circle
- **AppDelegate**: Central service container pattern — GlobalHotkeyService will be added here alongside other services
- **SettingsView**: TabView with General | STT Provider | AI Provider — hotkey config goes in General tab
- **AppConstants**: Centralized constants pattern — add hotkey-related UserDefaults keys and defaults here

### Established Patterns
- `@Observable` classes for services (not Combine/ObservableObject)
- Services in `VoxSlice/Services/`, Models in `VoxSlice/Models/`, Views in `VoxSlice/Views/`
- AppConstants for all constants (UserDefaults keys, notification names)
- AppDelegate as central service container with lazy initialization
- NSWindow for window management (permissions, dashboard, settings)
- Zero third-party dependencies so far (create-dmg is a build-time tool, not a runtime dependency)

### Integration Points
- AppDelegate → create and hold GlobalHotkeyService instance
- GlobalHotkeyService → call RecordingCoordinator.startRecording()/stopRecording() or toggleRecording()
- Settings General tab → add hotkey recorder UI section
- VoxSliceApp body → may need to reference GlobalHotkeyService for lifecycle
- AppConstants → add hotkey UserDefaults key

</code_context>

<specifics>
## Specific Ideas

- NSEvent global monitor does NOT require Accessibility permission (unlike CGEventTap) — simpler user experience
- Toggle behavior mirrors the menu bar single-click from Phase 2, keeping consistent interaction model
- create-dmg is a build-time tool installed via brew, not a runtime dependency — maintains zero-dependency approach
- The hotkey should be disabled/blocked during transcription and analysis states (matching the menu bar Start Recording disabled state from Phase 4)

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 06-global-hotkey-distribution*
*Context gathered: 2026-04-08*
