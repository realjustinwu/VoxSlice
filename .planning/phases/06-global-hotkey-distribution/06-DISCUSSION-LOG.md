# Phase 6: Global Hotkey + Distribution - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-08
**Phase:** 06-global-hotkey-distribution
**Areas discussed:** Hotkey Implementation, Hotkey Configuration, Hotkey Feedback, DMG Distribution

---

## Hotkey Implementation

| Option | Description | Selected |
|--------|-------------|----------|
| NSEvent global monitor | No Accessibility permission needed, simpler API, sufficient for key combo detection. Research recommended starting point. | Yes |
| CGEvent tap | Lower-level, can intercept/suppress keys. Requires Accessibility permission (extra prompt). More powerful but adds friction. | |
| KeyboardShortcuts library | Clean SwiftUI API, handles recording/validation. Adds third-party dependency to zero-dependency project. | |

**User's choice:** NSEvent global monitor
**Notes:** Matches research recommendation. No extra permission needed.

### Default Shortcut

| Option | Description | Selected |
|--------|-------------|----------|
| Cmd+Shift+R | Common pattern for media/recording apps, easy to remember, unlikely to conflict | Yes |
| Cmd+Option+R | More distinctive, less conflicts, slightly harder to press | |
| No default | User must configure on first launch | |

**User's choice:** Cmd+Shift+R

### Toggle Behavior

| Option | Description | Selected |
|--------|-------------|----------|
| Toggle | Same shortcut starts and stops. Matches menu bar click behavior (Phase 2 D-04) | Yes |
| Separate shortcuts | More explicit control, but two bindings to configure | |

**User's choice:** Toggle

---

## Hotkey Configuration

| Option | Description | Selected |
|--------|-------------|----------|
| General tab section | Add "Recording Shortcut" section in existing General tab. No new tab needed. | Yes |
| New "Recording" tab | Dedicated tab for recording settings. Heavy for a single setting. | |
| Menu bar dropdown | More accessible but less discoverable, mixes concerns. | |

**User's choice:** General tab section

### Hotkey Recorder UI

| Option | Description | Selected |
|--------|-------------|----------|
| Button-triggered recorder | Click "Record Shortcut" button, press key combo, display captured combination. Standard macOS pattern. | Yes |
| Inline editable field | Shows current shortcut as clickable text field. More compact but less intuitive. | |

**User's choice:** Button-triggered recorder

---

## Hotkey Feedback

| Option | Description | Selected |
|--------|-------------|----------|
| Icon change only | Menu bar icon changes (already implemented Phase 2 D-05). Clean, minimal. | Yes |
| Icon + system notification | More noticeable when in another app. | |
| Icon + sound | Audible confirmation without visual clutter. | |
| All feedback | Maximum feedback, potentially annoying. | |

**User's choice:** Icon change only

---

## DMG Distribution

| Option | Description | Selected |
|--------|-------------|----------|
| create-dmg tool | Community tool (brew install), generates professional DMG with background, Applications shortcut, window positioning | Yes |
| Manual hdiutil | No extra tool dependency, requires custom shell scripts | |
| Build + package script | Makefile/script that builds, archives, packages in one step | |

**User's choice:** create-dmg tool

### Code Signing

| Option | Description | Selected |
|--------|-------------|----------|
| Unsigned for v1 | No signing/notarization. Users see Gatekeeper warnings (bypass via right-click). Simplest for v1. | Yes |
| Signed + notarized | Requires Apple Developer cert ($99/year) + notarization setup. Users won't see warnings. | |

**User's choice:** Unsigned for v1

---

## Claude's Discretion

- Exact NSEvent monitor implementation details
- Hotkey recorder SwiftUI component
- DMG background image and window layout
- Build script structure
- Hotkey conflict handling
- Edge cases (hotkey during transcription/analysis)

## Deferred Ideas

None — discussion stayed within phase scope
