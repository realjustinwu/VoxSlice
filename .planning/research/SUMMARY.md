# Project Research Summary

**Project:** VoxSlice
**Domain:** Mac desktop audio recording + AI transcription/analysis
**Researched:** 2026-04-06
**Overall confidence:** HIGH

## Executive Summary

VoxSlice is a native macOS menu bar application that captures both microphone and system audio simultaneously, transcribes meetings using OpenAI's gpt-4o-transcribe API, and produces structured AI analysis (summary, action items, decisions, key topics) as shareable Markdown files. Competitive analysis of 8 products (MacWhisper, Aiko, Granola, tl;dv, Fireflies, Fathom, Descript, Plaud) confirms this is a well-understood product category with clear table stakes and meaningful differentiation opportunities. Experts in this space build with Apple-native frameworks for audio capture and delegate intelligence to cloud APIs, which is exactly the right approach here.

The recommended technology stack is unambiguous and leaves no room for meaningful debate: Swift 5.9+ with SwiftUI for the UI layer, ScreenCaptureKit (the only Apple-sanctioned method) for system audio, AVAudioEngine for microphone capture, and OpenAI's gpt-4o-transcribe + GPT-4o Chat Completions for transcription and analysis. Start with zero third-party dependencies. The architecture is a strict unidirectional pipeline -- capture completes before processing begins, processing is never coupled to recording -- which guarantees recording reliability even when network calls fail.

The three highest-risk engineering challenges, which must be solved correctly in the first phase, are: (1) the macOS Screen Recording permission requires an app restart to take effect, (2) the OpenAI Whisper API has a hard 25 MB upload limit that breaks recordings over roughly 25-30 minutes without chunking, and (3) dual-source audio capture produces two streams at different sample rates that must be recorded separately and merged post-capture rather than mixed in real-time. These pitfalls are confirmed by Apple's own documentation and define the hardest engineering work in the entire project.

## Key Findings

### Recommended Stack

The stack is entirely Apple-native on the client side with OpenAI cloud APIs for intelligence. No credible alternatives exist for the core choices.

**Core technologies:**
- **Swift + SwiftUI (macOS 13+):** Primary language and UI framework. Use `NSViewRepresentable` for AppKit interop where SwiftUI falls short (menu bar, global shortcuts). `MenuBarExtra` for the primary interface.
- **ScreenCaptureKit (macOS 12.3+):** The ONLY official way to capture system audio on macOS. Requires Screen Recording permission. CoreAudio, AudioUnit, and third-party drivers (BlackHole, Soundflower) are dead ends.
- **AVAudioEngine:** Microphone capture via `inputNode`. Well-documented, standard pattern. Separate from ScreenCaptureKit.
- **OpenAI gpt-4o-transcribe:** Superior to whisper-1 for Chinese/English/mixed language transcription. Same API endpoint, higher quality.
- **OpenAI GPT-4o Chat Completions:** Meeting analysis (summary, action items, decisions, topics). GPT-4o-mini sufficient for analysis and cheaper.
- **SwiftData (macOS 14+):** Recording metadata persistence without Core Data boilerplate.
- **Keychain Services:** API key storage. Never UserDefaults for credentials.
- **URLSession:** HTTP client. No need for Alamofire -- multipart upload and JSON handling are straightforward with built-in APIs.

**Zero third-party dependencies to start.** Add libraries (e.g., KeyboardShortcuts by sindresorhus) only if raw CGEvent/NSEvent hotkey implementation proves unmanageable.

### Expected Features

**Must have (table stakes -- Phase 1):**
- One-click recording start/stop (global hotkey is a strong Mac differentiator)
- Simultaneous mic + system audio capture (dealbreaker if missing for meeting use case)
- Post-meeting transcription with timestamps via Whisper API
- AI-generated summary + action items + decisions + key topics
- Markdown export to configurable output folder
- Recording history dashboard
- API key management (BYOK model, stored in Keychain)
- Visual recording indicator (menu bar icon state)

**Should have (competitive differentiation -- Phase 1 or early Phase 2):**
- Structured Markdown output with YAML frontmatter (no competitor does this well)
- No meeting bot required (direct system audio capture -- emphasize in positioning)
- Audio playback synced to transcript (users need to verify accuracy)
- Copy-to-clipboard for analysis sections
- Decision extraction (uncommon and valuable for accountability)
- Cost estimation before API calls

**Defer (v2+):**
- Speaker diarization (Whisper API does not do this natively; significant additional complexity)
- Custom analysis templates
- Chat with transcript (Q&A)
- Cross-meeting search
- Real-time transcription (explicitly deferred in PROJECT.md -- correct decision)
- On-device transcription (Whisper.cpp / WhisperKit)

**Explicitly do NOT build:** Meeting bots, video recording, cloud storage/sync, collaboration features, CRM integrations, mobile app, in-app transcript editor, subscription billing.

### Architecture Approach

VoxSlice uses a layered pipeline architecture with four distinct layers: UI (SwiftUI), State (Observable ViewModels), Services (actor-isolated classes), and Persistence (files + SwiftData). Data flows in one direction: audio capture -> file persistence -> transcription -> analysis -> Markdown output. Recording is fully independent from processing -- a processing failure never affects the saved audio file.

**Major components:**
1. **AudioCaptureService (actor):** Captures system audio via ScreenCaptureKit and microphone via AVAudioEngine. Records both streams to separate files. Handles permission checks, device changes, and recording health monitoring.
2. **ProcessingPipeline:** Orchestrates post-recording async workflow: chunk audio -> upload to STT -> receive transcript -> send to AI for analysis -> write Markdown. Manages retries, progress reporting, and error handling.
3. **STTClient:** Stateless HTTP client for OpenAI Whisper API. Handles multipart upload, chunking under 25 MB, and transcript continuity via the prompt parameter.
4. **AIClient:** Stateless HTTP client for OpenAI Chat Completions. Sends structured analysis prompts with transcript input, receives JSON output.
5. **StorageService:** File I/O for audio files and Markdown output. SwiftData for recording metadata. Handles folder creation and file naming.
6. **HotkeyService:** Global keyboard shortcut via Carbon/NSEvent APIs. Triggers start/stop recording from any context.
7. **SettingsManager:** User preferences (API keys in Keychain, output folder, hotkey binding) via UserDefaults for non-sensitive settings.
8. **RecordingViewModel (@Observable):** State machine (idle -> recording -> processing -> complete/failed). Coordinates AudioCaptureService and ProcessingPipeline. UI observes this.

**App lifecycle:** Menu bar app (`MenuBarExtra`) as primary interface. Optional `WindowGroup` for dashboard/history. Recording persists regardless of window state.

### Critical Pitfalls

1. **Screen Recording permission requires app restart** -- macOS caches permission state at process launch. After user grants permission, the app must quit and relaunch. Use `CGPreflightScreenCaptureAccess()` to check, `CGRequestScreenCaptureAccess()` to prompt. Detect and force restart. Failure to handle this produces silent recording failures on fresh installs.

2. **25 MB Whisper API upload limit** -- A 2-hour WAV is ~1.5 GB. Even compressed AAC at 128 kbps hits ~115 MB for long meetings. Must record directly to compressed format (AAC at 64-128 kbps) AND implement audio chunking with silence-based splitting. Pass previous chunk transcript as context via the prompt parameter.

3. **Dual-source audio capture at different sample rates** -- ScreenCaptureKit delivers system audio at 48 kHz, AVAudioEngine delivers mic audio at potentially 44.1 kHz. Do NOT mix in real-time. Record both to separate files, merge post-recording using `AVMutableComposition`. For transcription, uploading system audio alone (which contains meeting content) is the simpler v1 approach.

4. **API key plaintext storage** -- UserDefaults stores data in plaintext plist files readable by any process. All API keys MUST go in macOS Keychain. Never use `@AppStorage` for credentials (it uses UserDefaults under the hood).

5. **Silent recording failures** -- ScreenCaptureKit streams can stop delivering samples without explicit errors. Monitor audio levels during recording; if levels stay at zero for more than a few seconds, alert the user. Validate recorded file after stopping (check file size, duration). Never assume recording succeeded just because `startCapture()` returned success.

## Implications for Roadmap

Based on combined research, the project should follow 5 phases. The ordering is driven by technical dependencies (the build order from ARCHITECTURE.md), risk severity (the hardest problems get solved earliest), and the principle that recording reliability is the foundation everything else depends on.

### Phase 1: App Shell + Permissions + Settings

**Rationale:** Every subsequent feature depends on correct permission state and a working app lifecycle. The Screen Recording permission restart requirement (Pitfall 1) must be handled before any audio work begins. Settings with Keychain-based API key storage (Pitfall 5) must exist before any API calls.

**Delivers:** Menu bar app with `MenuBarExtra`, permission onboarding flow (Screen Recording + Microphone), settings screen with Keychain-backed API key input/validation, app lifecycle management.

**Addresses features:** API key management (BYOK), visual recording indicator (menu bar icon).

**Avoids pitfalls:** Permission-requires-restart (Pitfall 1), API key plaintext storage (Pitfall 5), confusing permission flow (UX pitfall).

**Research flag:** Standard patterns. Apple's `MenuBarExtra` and Keychain Services are well-documented. Skip deep research.

### Phase 2: Audio Capture Engine

**Rationale:** This is the highest-risk, highest-complexity component. ScreenCaptureKit + AVAudioEngine dual-stream capture with correct format handling, file writing, and device change resilience. Getting this wrong requires rebuilding the entire recording layer. Record directly to compressed format (AAC) to partially mitigate the 25 MB limit from the start.

**Delivers:** `AudioCaptureService` actor with system audio capture (ScreenCaptureKit), microphone capture (AVAudioEngine), dual-stream recording to separate files, audio file persistence (compressed AAC), recording health monitoring (zero-level detection), audio device change handling, and recording state machine.

**Addresses features:** Simultaneous mic + system audio capture, one-click recording start/stop (UI trigger -- hotkey comes later), configurable output folder.

**Avoids pitfalls:** Wrong API for system audio (Pitfall 3), real-time mixing crashes (Pitfall 4), silent recording failures (Pitfall 7), audio device change crashes (Pitfall 8), unbounded disk usage (performance trap).

**Research flag:** Needs deeper research. The dual-stream capture and merge strategy, silence-based audio splitting for chunking, and `AVMutableComposition` post-recording merge need implementation-time experimentation. Consider `/gsd-research-phase` during planning.

**Critical verification:** Record a 60+ minute meeting with both sources. Verify both files are non-silent. Verify app survives headphone disconnect/reconnect. Verify recording continues when app is in background.

### Phase 3: Transcription + Analysis Pipeline

**Rationale:** With reliable audio capture and stored API keys, the processing pipeline can be built. This phase delivers the core value: turning audio into structured intelligence. Audio chunking for the 25 MB limit is essential here, not optional.

**Delivers:** `STTClient` (Whisper API with chunking), `AIClient` (GPT-4o analysis), `ProcessingPipeline` orchestrator, audio compression + chunking logic, transcript continuity across chunks (prompt parameter), structured analysis output (summary, action items, decisions, topics), Markdown file generation with YAML frontmatter, progress indication during processing.

**Addresses features:** Post-meeting transcription with timestamps, AI-generated summary, action items extraction, decision extraction, key topics extraction, Markdown export.

**Avoids pitfalls:** 25 MB upload limit (Pitfall 2), frozen UI during upload (Pitfall 6), no progress indication (UX pitfall), no estimated cost (UX pitfall).

**Research flag:** Needs deeper research. The chunk boundary transcript continuity strategy (using Whisper's prompt parameter) and the optimal analysis prompt structure for mixed Chinese/English content need testing. Consider `/gsd-research-phase` during planning.

**Critical verification:** Transcribe a 60+ minute recording. Verify chunked transcription produces coherent output. Test with Chinese/English mixed audio. Verify Markdown renders correctly.

### Phase 4: Dashboard + History + Playback

**Rationale:** With the core pipeline working end-to-end, build the user-facing views that make the product usable day-to-day. SwiftData for metadata, SwiftUI for views, audio playback synced to transcript.

**Delivers:** `RecordingViewModel` state coordination, `HistoryViewModel` with SwiftData queries, dashboard view (recording history list), recording detail view, audio playback synced to transcript timestamps, copy-to-clipboard for analysis sections, search/filter across recordings.

**Addresses features:** Recording history dashboard, audio playback synced to transcript, export functionality.

**Avoids pitfalls:** No recording history (UX pitfall), Markdown output not opened after generation (UX pitfall).

**Research flag:** Standard patterns. SwiftUI + SwiftData is well-documented. Audio playback with transcript sync uses standard AVFoundation APIs. Skip deep research.

### Phase 5: Global Hotkey + Polish + Distribution

**Rationale:** Global hotkey is a strong differentiator but depends on the recording engine being stable. Polish and distribution come last because they only matter when the product works correctly.

**Delivers:** `HotkeyService` with CGEvent/NSEvent global shortcuts, hotkey configuration UI, error handling and edge cases, recording cost estimation, DMG creation, code signing, notarization, hardened runtime configuration.

**Addresses features:** Global hotkey recording trigger, no-meeting-bot positioning.

**Avoids pitfalls:** Global shortcut conflicts (UX pitfall), background recording stops (UX pitfall), cost surprise (UX pitfall).

**Research flag:** Needs deeper research. CGEvent/NSEvent global hotkey implementation has edge cases across macOS versions. Apple notarization and hardened runtime requirements for ScreenCaptureKit access need current documentation. Consider `/gsd-research-phase` during planning.

### Phase Ordering Rationale

- **Permissions before capture** because ScreenCaptureKit silently fails without proper permissions, and the restart requirement means you cannot retroactively fix this.
- **Capture before processing** because processing depends on audio files existing. Recording reliability is the foundation.
- **Transcription before analysis** because analysis consumes transcript output. These are sequential API calls.
- **Core pipeline before UI** because views depend on ViewModels which depend on services. The pipeline must work before you build views on top of it.
- **Hotkey and distribution last** because they are additive on top of a working product, not prerequisites for it.

### Research Flags

Phases likely needing deeper research during planning:
- **Phase 2 (Audio Capture):** Dual-stream capture architecture, silence-based audio splitting, AVMutableComposition merge, CMSampleBuffer-to-AVAudioPCMBuffer conversion, audio device change resilience. Highest research need in the project.
- **Phase 3 (Transcription):** Whisper chunk boundary continuity with prompt parameter, optimal chunk size, mixed-language transcription quality testing, analysis prompt engineering for structured output.
- **Phase 5 (Global Hotkey):** CGEvent/NSEvent global hotkey edge cases across macOS versions, shortcut conflict detection, notarization requirements for ScreenCaptureKit.

Phases with standard patterns (skip research-phase):
- **Phase 1 (App Shell):** MenuBarExtra, Keychain Services, SwiftUI Settings -- all well-documented.
- **Phase 4 (Dashboard):** SwiftData queries, SwiftUI lists, AVFoundation playback -- standard patterns.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | All core technologies verified against Apple official docs (ScreenCaptureKit, AVAudioEngine, SwiftUI, Keychain) and OpenAI official docs (gpt-4o-transcribe, Chat Completions). Zero ambiguity in core technology choices. |
| Features | HIGH | Competitive analysis of 8 products with direct verification. Feature categorization (table stakes vs differentiators vs anti-features) well-supported by market evidence. MVP scope aligned with PROJECT.md constraints. |
| Architecture | HIGH | Component boundaries and data flow verified against Apple sample code for ScreenCaptureKit audio capture. Build order reflects actual technical dependencies. Actor-isolated services pattern is standard Swift concurrency. |
| Pitfalls | HIGH | Screen Recording permission restart requirement confirmed in Apple's own ScreenCaptureKit sample code. Whisper 25 MB limit documented on OpenAI's platform. Dual-stream sample rate mismatch is inherent in using two different Apple audio APIs. |

**Overall confidence:** HIGH. This is not a project with ambiguous technology choices or unproven approaches. The risks are well-understood implementation challenges (audio pipeline complexity, permission handling), not unknown unknowns.

### Gaps to Address

- **Speaker diarization:** OpenAI Whisper API does not natively identify speakers. No clean API-based solution exists for v1. The `gpt-4o-transcribe` model was verified to handle mixed languages well, but speaker identification remains unsolved. Deferred to v2. Test Deepgram or ElevenLabs diarization APIs as add-ons during v2 planning.
- **macOS minimum deployment target:** SwiftData requires macOS 14+. ScreenCaptureKit audio capture is most reliable on macOS 13+. The research recommends macOS 14+ to get both, but this should be confirmed with the project owner -- macOS 13+ would require Core Data instead of SwiftData for metadata.
- **Audio chunking strategy details:** The 25 MB limit requires chunking, but the optimal strategy (silence-based splitting vs. fixed-duration segments vs. hybrid) needs implementation-time benchmarking. The prompt parameter for chunk continuity is documented but needs quality testing with real mixed-language audio.
- **Intel Mac support:** ScreenCaptureKit works on Intel Macs, but audio pipeline performance (AVAudioEngine, buffer handling) may differ from Apple Silicon. The project should decide early whether Intel is supported or Apple Silicon-only.
- **Notarization for ScreenCaptureKit:** Hardened runtime entitlements required for ScreenCaptureKit access in a distributed (non-App Store) app need verification against current Apple documentation. This is a Phase 5 concern but could affect architecture decisions if entitlements are restrictive.

## Sources

### Primary (HIGH confidence)
- Apple ScreenCaptureKit Documentation (developer.apple.com/documentation/screencapturekit) -- audio capture API, permission requirements, sample code
- Apple AVAudioEngine Documentation (developer.apple.com/documentation/avfaudio/avaudioengine) -- microphone capture, audio format handling
- Apple SwiftUI Documentation (developer.apple.com/documentation/swiftui) -- MenuBarExtra, @Observable, SwiftUI app lifecycle
- Apple Keychain Services (developer.apple.com/documentation/security/keychain-services) -- secure credential storage
- OpenAI Speech-to-Text Guide (platform.openai.com/docs/guides/speech-to-text) -- gpt-4o-transcribe model, API format, 25 MB limit
- OpenAI Chat Completions API (platform.openai.com/docs/guides/chat) -- structured output, function calling

### Secondary (MEDIUM confidence)
- WWDC22/23/24 ScreenCaptureKit sessions (10156, 10155, 10136, 10088) -- best practices, edge cases, HDR capture
- Competitive product analysis: MacWhisper, Aiko, Granola, tl;dv, Fireflies, Fathom, Descript, Plaud -- feature landscapes, pricing models, UX patterns
- Apple "Capturing screen content in macOS" sample code -- verified ScreenCaptureKit audio capture implementation pattern
- create-dmg (github.com/create-dmg/create-dmg) -- DMG creation for distribution

### Tertiary (LOW confidence)
- KeyboardShortcuts library (sindresorhus) -- could not verify latest version via docs, evaluate at implementation time
- Magnet library -- could not verify current maintenance status
- CGEvent/NSEvent global hotkey patterns -- known Apple APIs but implementation edge cases need testing
- Whisper prompt parameter for chunk continuity -- documented but quality with mixed-language audio needs empirical testing

---
*Research completed: 2026-04-06*
*Ready for roadmap: yes*
