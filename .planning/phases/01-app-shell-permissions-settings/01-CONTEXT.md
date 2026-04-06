# Phase 1: App Shell + Permissions + Settings - Context

**Gathered:** 2026-04-06
**Status:** Ready for planning

<domain>
## Phase Boundary

Deliver the app lifecycle foundation: menu bar app shell, macOS permission handling (Screen Recording + Microphone), and Settings window with secure API key storage for both STT and AI providers. This is the foundation all subsequent phases build on. Does NOT include audio recording, transcription, or AI analysis — those are separate phases.

</domain>

<decisions>
## Implementation Decisions

### STT Provider Strategy
- **D-01:** Build a unified STT provider protocol/abstraction layer from day one, not just OpenAI hardcoded
- **D-02:** v1 supports: OpenAI Whisper API, Google Speech-to-Text, AssemblyAI
- **D-03:** Domestic Chinese platforms (Deepseek STT, iFlytek, Baidu, Alibaba) — defer to post-v1; if they offer OpenAI-compatible interfaces, they may work with minimal effort
- **D-04:** Provider selection is done in Settings via a Picker UI with provider name and description

### AI Provider Configuration
- **D-05:** STT and AI analysis providers are configured SEPARATELY with different API keys
- **D-06:** AI analysis providers supported in v1: OpenAI (GPT-4o), Deepseek, 智谱大模型 (ZhipuAI/GLM)
- **D-07:** Support custom API endpoint URL for each provider — many Chinese AI providers use OpenAI-compatible APIs with custom base URLs
- **D-08:** Settings UI has separate sections/tabs for "STT Provider" and "AI Provider", each with provider picker, API key field, endpoint URL field, and validation button

### Data Storage Architecture
- **D-09:** Unified output directory approach — all data stored under user-configured output folder (default: ~/Documents/VoxSlice)
- **D-10:** Directory structure under output folder:
  ```
  ~/Documents/VoxSlice/
  ├── recordings/    # Raw audio files (Phase 2)
  ├── transcripts/   # Transcription text files (Phase 3)
  ├── analysis/      # AI analysis Markdown files (Phase 4)
  └── config/        # App configuration (provider preferences, settings)
  ```
- **D-11:** API keys stored in macOS Keychain via Security framework, NEVER in UserDefaults or flat files
- **D-12:** App preferences (selected providers, output folder path, window positions) stored in UserDefaults (standard macOS pattern)

### App Shell
- **D-13:** Menu bar only app (LSUIElement = true in Info.plist) — no dock icon
- **D-14:** Menu bar icon: SF Symbol `waveform.circle` (template mode, 18x18pt)
- **D-15:** Dropdown menu items: Settings..., About VoxSlice, Quit VoxSlice

### Permission Handling
- **D-16:** On first launch, show Permissions window automatically if any permission missing
- **D-17:** Card-based UI for each permission (Screen Recording, Microphone) with status badge and "Open System Settings" deep link
- **D-18:** Poll permission status on window activation (when user returns from System Settings)
- **D-19:** Screen Recording restart alert: "VoxSlice needs to restart" with Restart/Later buttons
- **D-20:** After all permissions granted, window auto-dismisses

### Settings Window
- **D-21:** Fixed size window (520x420pt), TabView with tabs: General | STT Provider | AI Provider | API Keys
- **D-22:** General tab: output folder picker (default ~/Documents/VoxSlice)
- **D-23:** Each provider tab: provider picker, API key SecureField, optional custom endpoint URL field, Validate button
- **D-24:** Validation calls the provider's API to verify key works (e.g., OpenAI models endpoint)
- **D-25:** Validation states: Idle → Validating (spinner) → Valid (green checkmark) or Invalid (red error message)

### Claude's Discretion
- Exact SwiftUI view hierarchy and file organization
- Error handling patterns for permission edge cases
- Keychain item naming conventions
- Minimum macOS version target (recommend macOS 13+ for ScreenCaptureKit, macOS 14+ for SwiftData)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### UI Design
- `.planning/phases/01-app-shell-permissions-settings/01-UI-SPEC.md` — Complete UI design contract with spacing, typography, color, component inventory, interaction patterns, and copywriting

### Project Context
- `.planning/PROJECT.md` — Vision, constraints, key decisions
- `.planning/REQUIREMENTS.md` — v1 requirements with REQ-IDs (RECD-05, UIUX-02, UIUX-03 are Phase 1)
- `.planning/ROADMAP.md` — Phase 1 goal, success criteria, dependency chain

### Research
- `.planning/research/STACK.md` — Technology stack recommendations (Swift, SwiftUI, ScreenCaptureKit)
- `.planning/research/ARCHITECTURE.md` — Component boundaries and data flow
- `.planning/research/PITFALLS.md` — Permission pitfalls and API limits

No external specs — requirements fully captured in decisions above and UI-SPEC.md.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
None — this is a greenfield project. Phase 1 creates the foundation.

### Established Patterns
- Native macOS app using Swift + SwiftUI + AppKit
- No third-party dependencies (zero-dependency approach from research)
- macOS Keychain for secrets, UserDefaults for preferences
- SF Symbols for icons

### Integration Points
- Menu bar (NSStatusItem/MenuBarExtra) — entry point for user interaction
- Settings window — STT and AI provider configuration consumed by Phases 2-4
- Output directory structure — consumed by Phases 2-4 for file storage
- Permission state — consumed by Phase 2 (audio capture requires permissions)

</code_context>

<specifics>
## Specific Ideas

- Many Chinese AI providers (Deepseek, ZhipuAI) offer OpenAI-compatible API interfaces — leverage this for unified provider abstraction
- Settings should allow custom base URL per provider so users can point to any OpenAI-compatible endpoint
- User explicitly wants multi-provider support from Phase 1 for both STT and AI analysis

</specifics>

<deferred>
## Deferred Ideas

- WhisperKit local model support — marked as "(Coming Soon)" in UI, implementation deferred to post-v1
- Domestic Chinese STT platforms (iFlytek, Baidu, Alibaba) — post-v1 unless OpenAI-compatible
- App update mechanism — Phase 6 scope
- Import/export of settings — not in v1 scope

</deferred>

---

*Phase: 01-app-shell-permissions-settings*
*Context gathered: 2026-04-06*
