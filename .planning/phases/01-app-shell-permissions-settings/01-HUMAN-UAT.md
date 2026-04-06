---
status: partial
phase: 01-app-shell-permissions-settings
source: [01-VERIFICATION.md]
started: 2026-04-06T19:35:00Z
updated: 2026-04-06T19:35:00Z
---

## Current Test

[awaiting human testing]

## Tests

### 1. Menu bar icon + no Dock icon
expected: App appears ONLY as menu bar icon (waveform.circle), with NO dock icon. LSUIElement=true in Info.plist.
result: [pending]

### 2. Permissions window auto-opens on first launch
expected: If Screen Recording or Microphone permission is missing, a centered window titled 'VoxSlice Permissions' appears with two permission cards.
result: [pending]

### 3. Permission deep-links to System Settings
expected: Clicking 'Open System Settings' on either card opens the correct macOS Privacy pane (Screen Recording or Microphone).
result: [pending]

### 4. Permission re-check on app re-activation
expected: After returning from System Settings, the app re-checks permission status automatically.
result: [pending]

### 5. Screen Recording restart prompt
expected: After granting Screen Recording, an alert with 'VoxSlice needs to restart' message and Restart/Later buttons appears.
result: [pending]

### 6. App restart flow
expected: Clicking Restart terminates the current instance and launches a new one.
result: [pending]

### 7. Settings window with 3 tabs
expected: Settings window opens at 520x420pt with General, STT Provider, AI Provider tabs. Accessible via Cmd+, and menu bar.
result: [pending]

### 8. Output folder selector via NSOpenPanel
expected: In General tab, clicking Choose... opens NSOpenPanel. Selected folder path updates in UI.
result: [pending]

### 9. API key validation and Keychain storage
expected: In provider tabs, enter API key in SecureField, click Validate Key — spinner shows, then green checkmark on success or red error. Keys stored in macOS Keychain, NOT UserDefaults.
result: [pending]

## Summary

total: 9
passed: 0
issues: 0
pending: 9
skipped: 0
blocked: 0

## Gaps
