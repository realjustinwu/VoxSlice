---
phase: 01-app-shell-permissions-settings
verified: 2026-04-06T19:30:00Z
status: human_needed
score: 18/18 must-haves verified
human_verification:
  - test: "Launch the app and verify it appears ONLY as a menu bar icon (waveform.circle), with NO dock icon"
    expected: "Menu bar shows waveform.circle icon. App does NOT appear in the Dock."
    why_human: "Requires running the app and observing macOS Dock and menu bar behavior"
  - test: "On first launch (with no Screen Recording or Microphone permission), verify the Permissions window opens automatically"
    expected: "A centered window titled 'VoxSlice Permissions' appears with two permission cards (Screen Recording and Microphone)"
    why_human: "Requires running the app on a machine without granted permissions"
  - test: "Click 'Open System Settings' on the Screen Recording card and verify it deep-links to the correct Privacy pane"
    expected: "macOS System Settings opens to the Screen Recording privacy section"
    why_human: "Requires running the app and interacting with macOS System Settings"
  - test: "After granting Screen Recording permission and returning to the app, verify the restart alert appears"
    expected: "Alert with 'VoxSlice needs to restart' message and Restart/Later buttons"
    why_human: "Requires running the app and granting a system permission"
  - test: "Click Restart and verify the app relaunches"
    expected: "App terminates and a new instance launches"
    why_human: "Requires running the app and triggering the restart flow"
  - test: "Open Settings via Cmd+, or menu bar, verify 3-tab layout at 520x420pt"
    expected: "Settings window with General, STT Provider, AI Provider tabs opens"
    why_human: "Requires running the app and observing window layout"
  - test: "In General tab, click Choose... and select a folder via NSOpenPanel"
    expected: "Output folder path updates to the selected directory"
    why_human: "Requires running the app and interacting with NSOpenPanel"
  - test: "In STT Provider tab, select a provider, enter a real API key, click Validate Key"
    expected: "Spinner shows during validation, then green checkmark 'Key verified' on success or red error on failure"
    why_human: "Requires running the app with a real API key and observing async validation UI states"
  - test: "Verify API key is stored in macOS Keychain (not UserDefaults plist)"
    expected: "Key can be read via Keychain Access utility. Not present in ~/Library/Preferences/com.voxslice.app.plist"
    why_human: "Requires checking macOS Keychain and filesystem after app interaction"
---

# Phase 1: App Shell + Permissions + Settings Verification Report

**Phase Goal:** Users can launch the app, grant required permissions with clear guidance, and configure API keys securely
**Verified:** 2026-04-06T19:30:00Z
**Status:** human_needed
**Re-verification:** No -- initial verification

## Goal Achievement

### Observable Truths

The 18 truths below combine the ROADMAP Success Criteria (SC1-SC4) with the PLAN frontmatter must-haves across all 3 plans. ROADMAP SCs are non-negotiable; PLAN truths add plan-specific detail.

**ROADMAP Success Criteria:**

| # | Truth (Roadmap SC) | Status | Evidence |
|---|---------------------|--------|----------|
| 1 | User launches app and sees a menu bar icon with controls for recording | VERIFIED | VoxSliceApp.swift L39: `MenuBarExtra("VoxSlice", systemImage: "waveform.circle")`; MenuBarView.swift L6-34: Settings, About, Quit items |
| 2 | User is prompted for Screen Recording and Microphone permissions with clear explanations, and the app handles the restart requirement for Screen Recording correctly | VERIFIED | PermissionManager.swift L39: `CGPreflightScreenCaptureAccess()`, L49: `AVAudioApplication.shared.recordPermission`, L42-44: restart alert trigger; PermissionsView.swift L22-28: Screen Recording card with explanation, L30-36: Microphone card; VoxSliceApp.swift L10: auto-show on missing permissions |
| 3 | User can open Settings and enter API keys for STT and AI providers, with keys stored in macOS Keychain (not UserDefaults) | VERIFIED | KeychainService.swift uses Security framework (SecItemAdd/SecItemCopyMatching/SecItemDelete); ProviderSettingsView.swift L55-58: saves to Keychain after validation; no UserDefaults usage for API keys |
| 4 | User can select and validate their STT provider choice in settings | VERIFIED | ProviderSettingsView.swift L9: `@AppStorage(AppConstants.sttProviderKey)`, L17-28: Picker with all STTProvider cases; ProviderValidationService.swift L19-37: `validateSTTKey()` calls GET /models |

**PLAN 01 must-haves (UIUX-03):**

| # | Truth (Plan 01) | Status | Evidence |
|---|-----------------|--------|----------|
| 5 | App launches and shows a menu bar icon with the waveform.circle SF Symbol | VERIFIED | VoxSliceApp.swift L39: `MenuBarExtra("VoxSlice", systemImage: "waveform.circle")` |
| 6 | Clicking the menu bar icon shows a dropdown with Settings, About, and Quit items | VERIFIED | MenuBarView.swift L6-34: Text("VoxSlice"), SettingsLink, Button("About VoxSlice"), Button("Quit VoxSlice") |
| 7 | App does NOT appear in the Dock (LSUIElement=true) | VERIFIED | Info.plist L25-26: `<key>LSUIElement</key><true/>` |
| 8 | Command+Q quits the app from any state | VERIFIED | MenuBarView.swift L33: `.keyboardShortcut("q", modifiers: .command)` |
| 9 | Command+, opens the Settings window (even if empty placeholder) | VERIFIED | MenuBarView.swift L15: `.keyboardShortcut(",", modifiers: .command)` on SettingsLink; VoxSliceApp.swift L44-46: Settings scene with SettingsView |

**PLAN 02 must-haves (RECD-05):**

| # | Truth (Plan 02) | Status | Evidence |
|---|-----------------|--------|----------|
| 10 | On first launch, if Screen Recording or Microphone permission is missing, the Permissions window appears automatically | VERIFIED | VoxSliceApp.swift L8-13: AppDelegate checks `permissionManager.hasMissingPermissions` and calls `showPermissionsWindow()` |
| 11 | Each permission shows a card with icon, title, description, status badge, and Open System Settings button | VERIFIED | PermissionsView.swift L20-38: PermissionCard with iconName, title, description, isGranted, openSettingsAction |
| 12 | Clicking Open System Settings deep-links to the correct macOS Privacy pane | VERIFIED | PermissionManager.swift L55: `x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture`; L63: `?Privacy_Microphone` |
| 13 | When the user returns from System Settings, the app re-checks permission status | VERIFIED | PermissionsView.swift L52-54: `.onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification))` calls `permissionManager.onWindowBecameActive()` |
| 14 | If Screen Recording is newly granted, the app shows a restart alert with Restart/Later buttons | VERIFIED | PermissionManager.swift L42-44: detects state change, sets `showRestartAlert = true`; PermissionsView.swift L56-63: `.alert` with Restart and Later buttons |
| 15 | When all permissions are granted, the Permissions window auto-dismisses | VERIFIED | PermissionsView.swift L64-68: `.onChange(of: permissionManager.allPermissionsGranted)` calls `dismiss()` |

**PLAN 03 must-haves (UIUX-02):**

| # | Truth (Plan 03) | Status | Evidence |
|---|-----------------|--------|----------|
| 16 | User can open Settings via menu bar or cmd+, | VERIFIED | VoxSliceApp.swift L44-46: Settings scene; MenuBarView.swift L12-15: SettingsLink with cmd+, |
| 17 | User can set the output folder via NSOpenPanel in the General tab | VERIFIED | GeneralSettingsView.swift L33-44: `chooseOutputFolder()` creates NSOpenPanel with `canChooseDirectories = true` |
| 18 | User can select STT provider and AI provider with pickers, enter API keys in SecureFields, validate via API, and keys are stored in Keychain | VERIFIED | ProviderSettingsView.swift L9: STTProvider @AppStorage, L113: AIProvider @AppStorage; L35/139: SecureField; L46-60/150-161: validate + save to Keychain |

**Score:** 18/18 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `VoxSlice/VoxSliceApp.swift` | App entry point with MenuBarExtra | VERIFIED | 48 lines. @main struct, MenuBarExtra, Settings scene, AppDelegate with permissions window. All wired. |
| `VoxSlice/Views/MenuBarView.swift` | Menu bar dropdown menu | VERIFIED | 40 lines. SettingsLink, About, Quit with keyboard shortcuts. Referenced from VoxSliceApp. |
| `VoxSlice/Info.plist` | LSUIElement configuration | VERIFIED | 34 lines. LSUIElement=true, both usage descriptions present, LSMinimumSystemVersion=14.0. |
| `VoxSlice/Utils/Constants.swift` | App-wide constants | VERIFIED | 22 lines. AppConstants with all key names, paths, directory names. |
| `VoxSlice/Services/StorageService.swift` | Output directory management | VERIFIED | 42 lines. @Observable, UserDefaults-backed, auto-creates directory structure. |
| `VoxSlice/Services/PermissionManager.swift` | Permission checking and monitoring | VERIFIED | 88 lines. CGPreflightScreenCaptureAccess, AVAudioApplication, deep-links, restart flow. |
| `VoxSlice/Views/PermissionsView.swift` | Card-based permission UI | VERIFIED | 127 lines. PermissionCard component, restart alert, auto-dismiss, didBecomeActive polling. |
| `VoxSlice/Models/Provider.swift` | STT and AI provider enums | VERIFIED | 75 lines. STTProvider (3 cases), AIProvider (3 cases), displayNames, endpoints, keychainAccounts. |
| `VoxSlice/Services/KeychainService.swift` | Keychain CRUD for API keys | VERIFIED | 74 lines. Security framework, save/read/delete with upsert pattern, kSecAttrAccessibleAfterFirstUnlock. |
| `VoxSlice/Services/ProviderValidationService.swift` | API key validation | VERIFIED | 79 lines. GET /models with Bearer token, HTTPS enforcement, ValidationState state machine. |
| `VoxSlice/Views/Settings/SettingsView.swift` | TabView settings window | VERIFIED | 23 lines. 3 tabs (General, STT Provider, AI Provider), 520x420pt frame. |
| `VoxSlice/Views/Settings/GeneralSettingsView.swift` | Output folder picker | VERIFIED | 46 lines. NSOpenPanel with directory-only selection, StorageService binding. |
| `VoxSlice/Views/Settings/ProviderSettingsView.swift` | Provider config with validation | VERIFIED | 206 lines. STTProviderSettingsView + AIProviderSettingsView, SecureField, validate button, state machine UI. |
| `VoxSlice.xcodeproj/project.pbxproj` | Xcode project with all sources | VERIFIED | All 12 Swift files listed in PBXBuildFile and PBXSourcesBuildPhase. Build succeeds. |

All 14 artifacts: exist, are substantive (no stubs), and are wired into the application.

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| VoxSliceApp.swift | MenuBarView.swift | MenuBarExtra body references MenuBarView | WIRED | VoxSliceApp.swift L40: `MenuBarView()` |
| VoxSliceApp.swift | PermissionsView.swift | AppDelegate shows PermissionsView as NSWindow | WIRED | VoxSliceApp.swift L17: `let contentView = PermissionsView(permissionManager: permissionManager)` |
| VoxSliceApp.swift | SettingsView.swift | Settings scene references SettingsView | WIRED | VoxSliceApp.swift L45: `SettingsView(storageService: storageService)` |
| PermissionsView.swift | PermissionManager.swift | View observes PermissionManager state | WIRED | PermissionsView.swift L4: `@Bindable var permissionManager: PermissionManager`; L24/34: reads granted state; L26/36: calls openSettings; L58: calls restartApp |
| SettingsView.swift | GeneralSettingsView.swift | Tab 1 content | WIRED | SettingsView.swift L8: `GeneralSettingsView(storageService: storageService)` |
| SettingsView.swift | STTProviderSettingsView | Tab 2 content | WIRED | SettingsView.swift L12: `STTProviderSettingsView(storageService: storageService)` |
| SettingsView.swift | AIProviderSettingsView | Tab 3 content | WIRED | SettingsView.swift L16: `AIProviderSettingsView(storageService: storageService)` |
| ProviderSettingsView.swift | KeychainService.swift | Save/load API keys | WIRED | L55-58: `KeychainService.shared.save(...)`; L99/102/200/203: `KeychainService.shared.read(...)` |
| ProviderSettingsView.swift | ProviderValidationService.swift | Validate key button triggers API call | WIRED | L6/110: `@State private var validationService = ProviderValidationService()`; L48/151: calls validate methods |
| GeneralSettingsView.swift | StorageService.swift | Output folder path stored in StorageService | WIRED | L4: `@Bindable var storageService: StorageService`; L29/43: reads/writes `storageService.outputFolderPath` |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|--------------------|--------|
| PermissionsView | permissionManager.screenRecordingGranted | CGPreflightScreenCaptureAccess() | Yes -- macOS system API | FLOWING |
| PermissionsView | permissionManager.microphoneGranted | AVAudioApplication.shared.recordPermission | Yes -- macOS system API | FLOWING |
| GeneralSettingsView | outputFolderPath | storageService.outputFolderPath (UserDefaults) | Yes -- real file path | FLOWING |
| STTProviderSettingsView | apiKey | KeychainService.shared.read() | Yes -- Keychain data | FLOWING |
| AIProviderSettingsView | apiKey | KeychainService.shared.read() | Yes -- Keychain data | FLOWING |
| ProviderValidationService | validateKey result | URLSession.shared.data(for:) -> HTTP response | Yes -- real HTTP GET to /models | FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Xcode project builds | `xcodebuild -project VoxSlice.xcodeproj -scheme VoxSlice -configuration Debug build` | BUILD SUCCEEDED | PASS |
| Anti-pattern scan (TODO/FIXME/placeholder) | grep across all .swift files | No matches found | PASS |
| Empty return patterns | grep for `return null`, `return {}`, `return []` | No matches found | PASS |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-----------|-------------|--------|----------|
| RECD-05 | Plan 02 | App requests and handles macOS Screen Recording and Microphone permissions gracefully | SATISFIED | PermissionManager.swift: CGPreflightScreenCaptureAccess + AVAudioApplication. PermissionsView.swift: card-based UI with deep-links, restart flow, auto-dismiss. VoxSliceApp.swift: AppDelegate auto-opens permissions window. |
| UIUX-02 | Plan 03 | Settings screen for selecting STT provider, managing API keys, and configuring local models with validation | SATISFIED | SettingsView.swift: 3-tab layout. ProviderSettingsView.swift: provider pickers, SecureField, custom endpoint, validate button with state machine. KeychainService.swift: secure storage. |
| UIUX-03 | Plan 01 | Menu bar integration for quick access to recording controls | SATISFIED | VoxSliceApp.swift: MenuBarExtra with waveform.circle. MenuBarView.swift: Settings, About, Quit. Info.plist: LSUIElement=true (menu bar only). |

**Orphaned requirements check:** REQUIREMENTS.md traceability table maps RECD-05, UIUX-02, UIUX-03 to Phase 1. All three are claimed by plans. No orphaned requirements found.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| ProviderSettingsView.swift | 5, 109 | Unused `@Bindable var storageService` parameter | Info | storageService is threaded through from SettingsView but never read in STT/AI provider views (data flows via @AppStorage and KeychainService.shared instead). Not a blocker -- the parameter exists for future use and the views function correctly without it. |

No blocker or warning-level anti-patterns found. No TODO/FIXME/placeholder comments. No empty return statements. No hardcoded empty data in non-test code.

### Human Verification Required

The following items require running the app on macOS and observing visual/runtime behavior:

### 1. Menu bar icon and no dock icon

**Test:** Launch VoxSlice.app and check the menu bar and Dock
**Expected:** waveform.circle icon appears in menu bar. App does NOT appear in Dock (LSUIElement=true).
**Why human:** Requires running the app and observing macOS UI behavior

### 2. Permissions window auto-open on first launch

**Test:** On a machine without Screen Recording/Microphone permission granted to VoxSlice, launch the app
**Expected:** A 440x320pt centered window titled "VoxSlice Permissions" appears with two permission cards
**Why human:** Requires running the app without system permissions already granted

### 3. Permission deep-links to System Settings

**Test:** Click "Open System Settings" on the Screen Recording permission card
**Expected:** macOS System Settings opens to Privacy & Security > Screen Recording pane
**Why human:** Requires running the app and observing macOS System Settings navigation

### 4. Permission re-check on return from System Settings

**Test:** After returning from System Settings (with or without granting permission), observe the permission card status
**Expected:** Status badge updates (Granted/Not Granted) to reflect current permission state
**Why human:** Requires running the app and triggering the didBecomeActive re-check flow

### 5. Screen Recording restart alert

**Test:** After granting Screen Recording permission and returning to the app, verify the restart alert
**Expected:** Alert dialog with "VoxSlice needs to restart" title and Restart/Later buttons
**Why human:** Requires granting a system permission and observing the alert flow

### 6. Settings window with 3 tabs

**Test:** Click the menu bar icon > Settings... (or press Cmd+,)
**Expected:** Settings window opens at 520x420pt with General, STT Provider, AI Provider tabs
**Why human:** Requires running the app and observing window layout and dimensions

### 7. Output folder picker

**Test:** In General tab, click Choose... button
**Expected:** NSOpenPanel opens allowing directory selection. Selected path updates in the text field.
**Why human:** Requires running the app and interacting with NSOpenPanel

### 8. API key validation flow

**Test:** In STT Provider tab, select a provider, enter a real API key, click "Validate Key"
**Expected:** Button shows spinner during validation, then green checkmark "Key verified" on success or red error message on failure
**Why human:** Requires running the app with a real API key and observing async UI state transitions

### 9. Keychain storage verification

**Test:** After validating and saving an API key, check macOS Keychain Access
**Expected:** API key stored under service "com.voxslice.app" with the provider's keychain account name. Key NOT present in ~/Library/Preferences/com.voxslice.app.plist.
**Why human:** Requires checking macOS Keychain Access utility and filesystem after app interaction

### Gaps Summary

No code-level gaps found. All 14 artifacts exist, are substantive (no stubs), are properly wired, and have real data flowing through them. The Xcode project builds successfully with all 12 source files included. All 3 requirement IDs (RECD-05, UIUX-02, UIUX-03) are satisfied with implementation evidence.

The phase is in `human_needed` status because all observable behaviors require launching and interacting with a macOS app -- permission flows, menu bar rendering, window layouts, async validation states, and Keychain storage can only be fully verified by a human on a Mac.

---

_Verified: 2026-04-06T19:30:00Z_
_Verifier: Claude (gsd-verifier)_
