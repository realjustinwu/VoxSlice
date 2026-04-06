<!-- GSD:project-start source:PROJECT.md -->
## Project

**VoxSlice**

VoxSlice is a native Mac desktop application that records audio from both microphone and system audio, transcribes it using STT APIs (OpenAI Whisper etc.), and uses AI to analyze meeting transcripts — extracting summaries, action items, decisions, and key topics. Results are saved as timestamped Markdown files to a user-configured folder.

**Core Value:** One-click meeting recording → structured AI analysis in a Markdown file you can share immediately.

### Constraints

- **Platform**: macOS only — Mac-specific APIs for audio capture and global shortcuts
- **Audio**: Must capture both microphone and system audio — requires screen recording permission on macOS
- **API**: Requires external STT and AI APIs — user must provide their own keys
- **Distribution**: Must be a proper installable Mac app — not a CLI or web app
<!-- GSD:project-end -->

<!-- GSD:stack-start source:research/STACK.md -->
## Technology Stack

## Recommended Stack
### Core Framework
| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| Swift | 5.9+ | Primary language | Required for macOS native development. Async/await, structured concurrency, and Sendable support mature since 5.9. Apple's first-class language. |
| SwiftUI | macOS 13+ | UI framework | Declarative UI with live previews. Sufficient for dashboard/settings views. Use `NSViewRepresentable` for AppKit interop where SwiftUI falls short (e.g., menu bar, global shortcuts). |
| AppKit | macOS 13+ | System integration | Required for features SwiftUI cannot handle: global hotkeys (CGEvent taps), menu bar icon, window management, permission dialogs. |
| Swift Concurrency | Swift 5.9+ | Async operations | `async/await` for API calls, audio processing, file I/O. `Actor` for thread-safe audio engine state. Eliminates callback hell. |
### Audio Capture
| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| ScreenCaptureKit | macOS 12.3+ | System audio capture | Apple's official framework for capturing screen AND audio content. Uses `SCStream` with `SCStreamConfiguration` to capture audio as `CMSampleBuffer`. Requires screen recording permission. This is the only reliable way to capture system audio (Zoom/Meet output) on macOS. |
| AVAudioEngine | macOS 10.10+ | Microphone capture | Apple's audio processing graph. `inputNode` provides microphone input. Combine with `mainMixerNode` for processing. Supports real-time audio format conversion. Requires microphone permission. |
| AVFoundation | macOS 10.7+ | Audio file I/O | Write recorded audio to disk as WAV or M4A. `AVAudioFile` for file operations. Format conversion for OpenAI API compatibility. |
| CoreMedia | macOS 10.0+ | Sample buffer handling | `CMSampleBuffer` handling for ScreenCaptureKit audio output. Convert to `AVAudioPCMBuffer` for processing and file writing. |
### API Integration
| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| OpenAI Speech-to-Text API | `gpt-4o-transcribe` model | Transcription | Superior to `whisper-1` for multilingual (Chinese/English/mixed). Supports streaming, verbose_json with timestamps, and higher quality. `gpt-4o-mini-transcribe` available as cheaper alternative. |
| OpenAI Chat Completions API | `gpt-4o` or `gpt-4o-mini` model | Meeting analysis | Extract summary, action items, decisions, key topics from transcript. Structured JSON output with function calling or structured outputs. `gpt-4o-mini` sufficient for most analysis tasks and cheaper. |
| URLSession | Foundation | HTTP requests | Built-in HTTP client. Multipart form upload for audio files to Whisper endpoint. JSON request/response for Chat Completions. No third-party dependency needed. |
### Security & Storage
| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| Keychain Services | macOS 10.0+ | API key storage | Apple's secure credential storage. Encrypts API keys at rest. Standard macOS security practice. Accessible via `Security` framework or Swift wrapper. |
| FileManager | Foundation | File I/O | Create timestamped Markdown output files. Manage recording storage. User-configurable output directory. |
| Swift Codable | Swift 4+ | Serialization | JSON encoding/decoding for recording metadata, app settings, API responses. Built-in, no dependencies. |
### Distribution
| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| Xcode | 15+ | Project management | Apple's IDE. Project file, build settings, code signing, archiving. Required for Mac app development. |
| create-dmg | Latest | DMG creation | Community tool for creating professional DMG installers with background images and application shortcuts. Simpler than custom DMG tooling. |
| Swift Package Manager | Swift 5.3+ | Dependency management | Built-in. Use for any third-party dependencies (e.g., hotkey library). Preferred over CocoaPods or Carthage for new projects. |
## Supporting Libraries
| Library | Purpose | When to Use | Confidence |
|---------|---------|-------------|------------|
| KeyboardShortcuts (sindresorhus) | Global hotkey registration | If custom CGEvent tap proves too fragile. Provides clean SwiftUI-integrated API for global shortcuts. SPM-compatible. | MEDIUM - Could not verify latest version via docs |
| Magnet | Global hotkey alternative | If KeyboardShortcuts is insufficient. Lower-level hotkey binding. SPM-compatible. | LOW - Could not verify current maintenance status |
| AttributedText or Down | Markdown rendering | If in-app Markdown preview is needed. Standard Swift Markdown parsing/rendering. | LOW - Defer until feature is scoped |
## Alternatives Considered
| Category | Recommended | Alternative | Why Not |
|----------|-------------|-------------|---------|
| Language | Swift | Objective-C | Swift is Apple's modern language. ObjC has no advantage for a greenfield 2026 project. |
| UI Framework | SwiftUI + AppKit interop | Pure AppKit (Storyboard) | SwiftUI is the future. Storyboards are legacy. But AppKit needed for system integration features SwiftUI cannot handle. |
| UI Framework | SwiftUI + AppKit interop | Electron / Tauri | Electron: bloated (~200MB), poor Mac integration for audio capture and global shortcuts. Tauri: uses system webview, still limited for low-level audio. Neither can use ScreenCaptureKit natively. |
| UI Framework | SwiftUI + AppKit interop | Qt | Overkill, C++ dependency, non-native feel, commercial licensing concerns. |
| System Audio | ScreenCaptureKit | CoreAudio/AudioUnit | CoreAudio cannot capture system audio on modern macOS without third-party kernel extensions (BlackHole, Soundflower). ScreenCaptureKit is Apple's official solution and works without kernel extensions. |
| System Audio | ScreenCaptureKit | BlackHole / Soundflower | Third-party virtual audio drivers. Require separate installation. Unreliable across macOS updates. ScreenCaptureKit is built into macOS. |
| Transcription | OpenAI gpt-4o-transcribe | whisper-1 | whisper-1 is the original model. gpt-4o-transcribe provides higher quality, especially for Chinese/English mixing. Same API endpoint. |
| Transcription | OpenAI API | Local Whisper (whisper.cpp) | Requires bundling a large model (~1-3GB). Apple Silicon GPU inference is possible but adds significant complexity. API is simpler and higher quality for v1. |
| Transcription | OpenAI API | Apple Speech Framework | Apple's on-device transcription exists but quality is notably worse than Whisper for Chinese and mixed languages. No speaker diarization. |
| AI Analysis | OpenAI Chat Completions | Anthropic Claude API | Good alternative, but adds a second API provider. Start with OpenAI for both STT and analysis to simplify the user experience (one API key). |
| AI Analysis | OpenAI Chat Completions | Local LLM (Ollama) | Requires user to run Ollama. Variable quality. Extra setup friction. API is simpler and more reliable. |
| HTTP Client | URLSession | Alamofire | Alamofire adds a dependency for functionality URLSession already provides. Multipart upload is straightforward with URLSession. |
| Dependency Manager | Swift Package Manager | CocoaPods | CocoaPods is legacy. SPM is built into Xcode and Swift. |
| Dependency Manager | Swift Package Manager | Carthage | Carthage is minimally maintained. SPM is the standard. |
## Installation
# No npm/pip installs needed - this is a native Swift project.
# Clone and open in Xcode
# Build dependencies via SPM (Xcode resolves automatically)
# File > Packages > Resolve Package Versions
# For DMG creation (CI/release only)
# Run from Xcode
# Product > Run (Cmd+R)
## Confidence Assessment
| Recommendation | Confidence | Reason |
|----------------|------------|--------|
| Swift + SwiftUI | HIGH | Apple official frameworks, verified documentation |
| ScreenCaptureKit for system audio | HIGH | Verified Apple docs confirm audio capture capability |
| AVAudioEngine for microphone | HIGH | Apple official, well-documented, standard pattern |
| OpenAI gpt-4o-transcribe | HIGH | Verified OpenAI docs, confirmed model names and capabilities |
| OpenAI Chat Completions for analysis | HIGH | Industry standard, well-documented |
| Keychain Services for API keys | HIGH | Apple official security framework |
| Zero third-party dependencies (start) | HIGH | Reduces risk, SPM available if needed |
| CGEvent/NSEvent for global hotkeys | MEDIUM | Known Apple APIs, but implementation details may require iteration |
| create-dmg for distribution | MEDIUM | Community tool, widely used but not Apple official |
| Specific third-party libraries | LOW | Could not verify current maintenance status via docs |
## Sources
- Apple ScreenCaptureKit Documentation: https://developer.apple.com/documentation/screencapturekit (verified 2026-04-06)
- Apple AVAudioEngine Documentation: https://developer.apple.com/documentation/avfaudio/avaudioengine (verified 2026-04-06)
- Apple SwiftUI Documentation: https://developer.apple.com/documentation/swiftui (verified 2026-04-06)
- Apple Keychain Services: https://developer.apple.com/documentation/security/keychain-services (verified 2026-04-06)
- OpenAI Speech-to-Text Guide: https://platform.openai.com/docs/guides/speech-to-text (verified 2026-04-06)
- OpenAI Chat Completions API: https://platform.openai.com/docs/guides/chat (industry standard)
- create-dmg: https://github.com/create-dmg/create-dmg (community tool)
<!-- GSD:stack-end -->

<!-- GSD:conventions-start source:CONVENTIONS.md -->
## Conventions

Conventions not yet established. Will populate as patterns emerge during development.
<!-- GSD:conventions-end -->

<!-- GSD:architecture-start source:ARCHITECTURE.md -->
## Architecture

Architecture not yet mapped. Follow existing patterns found in the codebase.
<!-- GSD:architecture-end -->

<!-- GSD:skills-start source:skills/ -->
## Project Skills

No project skills found. Add skills to any of: `.claude/skills/`, `.agents/skills/`, `.cursor/skills/`, or `.github/skills/` with a `SKILL.md` index file.
<!-- GSD:skills-end -->

<!-- GSD:workflow-start source:GSD defaults -->
## GSD Workflow Enforcement

Before using Edit, Write, or other file-changing tools, start work through a GSD command so planning artifacts and execution context stay in sync.

Use these entry points:
- `/gsd-quick` for small fixes, doc updates, and ad-hoc tasks
- `/gsd-debug` for investigation and bug fixing
- `/gsd-execute-phase` for planned phase work

Do not make direct repo edits outside a GSD workflow unless the user explicitly asks to bypass it.
<!-- GSD:workflow-end -->



<!-- GSD:profile-start -->
## Developer Profile

> Profile not yet configured. Run `/gsd-profile-user` to generate your developer profile.
> This section is managed by `generate-claude-profile` -- do not edit manually.
<!-- GSD:profile-end -->
