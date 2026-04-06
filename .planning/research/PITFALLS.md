# Pitfalls Research

**Domain:** Mac desktop audio recording + AI transcription/analysis
**Researched:** 2026-04-06
**Confidence:** MEDIUM-HIGH (Apple official docs, OpenAI official docs; some community patterns from training data)

---

## Critical Pitfalls

### Pitfall 1: Screen Recording Permission Requires App Restart

**What goes wrong:**
On macOS, capturing system audio requires the Screen Recording permission (granted via System Settings > Privacy & Security > Screen Recording). When a user grants this permission for the first time, macOS requires the app to be fully quit and relaunched before the permission takes effect. Many apps show a "grant permission" dialog but do not force a restart, leading to the user granting the permission, assuming it works, and then getting silent failures or errors when trying to record.

**Why it happens:**
The Screen Recording permission is enforced at the process level by the WindowServer. The permission state is cached when the app launches. Unlike Microphone permission (which can be granted and used immediately), Screen Recording permission changes are not picked up by a running process. Apple's own sample code for ScreenCaptureKit explicitly states: "After you grant permission, you need to restart the app to enable capture."

**How to avoid:**
- Detect when Screen Recording permission is missing and show a clear onboarding flow
- After the user grants the permission, programmatically quit and relaunch the app (use `NSApplication.terminate` and a helper/login item or `open` command to relaunch)
- On every app launch, check permission status BEFORE initializing any recording UI
- Use `CGPreflightScreenCaptureAccess()` to check status and `CGRequestScreenCaptureAccess()` to prompt
- Display the current permission state visibly in the app's status bar or settings

**Warning signs:**
- `SCShareableContent` calls return empty arrays or throw errors
- `SCStream.startCapture()` fails silently or throws permission-related errors
- Users report "recording doesn't work" after a fresh install
- Works in development (Xcode grants permissions differently) but fails in production builds

**Phase to address:**
Phase 1 (Audio Capture Foundation) -- permission handling must be the first thing built, not an afterthought. Every recording flow depends on correct permissions.

---

### Pitfall 2: 25 MB File Upload Limit Destroys Long Recordings

**What goes wrong:**
The OpenAI Whisper API (`whisper-1`) has a hard 25 MB file upload limit. A 2-hour meeting recorded as uncompressed WAV (44.1 kHz, stereo) is approximately 1.5 GB. Even as MP3 at 128 kbps, that is roughly 115 MB -- still well over the limit. Developers who record meetings without considering this limit will find that transcription fails for any recording longer than about 25-30 minutes (depending on format and bitrate).

**Why it happens:**
The OpenAI API uses multipart form uploads with a 25 MB cap. This is an infrastructure limit, not a model limit. Developers test with short recordings during development and do not discover the limit until real users record actual meetings. WAV format makes this problem acute (roughly 10 MB per minute for stereo 44.1 kHz), but even compressed formats hit the ceiling for long meetings.

**How to avoid:**
- Record directly to a compressed format (AAC or MP3 at 64-128 kbps) to maximize duration within the 25 MB limit
- At 64 kbps mono AAC, 25 MB covers approximately 50 minutes of audio -- still not enough for long meetings
- Implement audio chunking: split recordings into segments under 25 MB before uploading
- Split at silence boundaries (use simple amplitude-based silence detection) to avoid cutting mid-sentence
- Pass the transcript of the previous chunk as context to the next chunk's prompt parameter to maintain continuity
- Consider using PyDub-equivalent logic in Swift (AVFoundation's `AVAssetExportSession` with time ranges)
- For the newer `gpt-4o-transcribe` models, the same 25 MB limit applies to file uploads
- Display estimated file size during recording so users know when they are approaching limits

**Warning signs:**
- API returns 413 Payload Too Large or similar errors for long recordings
- Transcription works for short test recordings but fails for real meetings
- Users report "transcription failed" for recordings over 30 minutes
- File sizes in the app's storage directory grow unbounded (uncompressed recording)

**Phase to address:**
Phase 2 (Transcription Pipeline) -- chunking logic must be built into the transcription pipeline from the start. Recording format choice (compressed vs. uncompressed) must be decided in Phase 1.

---

### Pitfall 3: System Audio Capture Requires ScreenCaptureKit, Not Core Audio

**What goes wrong:**
Developvers try to capture system audio (what the speakers are playing) using Core Audio APIs (`AVAudioEngine`, `AVCaptureDevice`) which only capture microphone input. System audio capture on macOS requires ScreenCaptureKit (available macOS 12.3+, with audio capture improvements in macOS 13+). Attempting to use Core Audio or third-party kernel extensions for system audio capture results in either failure, deprecation warnings, or requiring SIP-disabled Macs.

**Why it happens:**
macOS intentionally restricts system audio capture for privacy/security. The only official API is ScreenCaptureKit's audio capture feature, which requires Screen Recording permission (not Microphone permission). Developers coming from other platforms or older macOS versions may not know this. The older approach of using third-party kernel extensions (like Soundflower or BlackHole) requires System Integrity Protection (SIP) to be disabled, which is unacceptable for most users.

**How to avoid:**
- Use ScreenCaptureKit exclusively for system audio capture
- Configure `SCStreamConfiguration` with `capturesAudio = true` and `excludesCurrentProcessAudio = true`
- Add a separate `SCStreamOutput` with `type: .audio` to receive audio sample buffers
- Convert CMSampleBuffer to AVAudioPCMBuffer using the audio buffer list approach from Apple's sample code
- For microphone capture, use AVAudioEngine separately and merge the two audio streams
- Target macOS 13+ minimum (ScreenCaptureKit audio capture is more reliable on macOS 13+)
- Never depend on third-party audio drivers (Soundflower, BlackHole) for production

**Warning signs:**
- System audio recordings are silent or empty
- Only microphone audio is captured despite expecting both
- App requires SIP-disabled machines to work
- Crash logs show Core Audio errors when trying to capture output audio

**Phase to address:**
Phase 1 (Audio Capture Foundation) -- this is the foundational architecture decision. Get this wrong and the entire recording pipeline must be rebuilt.

---

### Pitfall 4: Merging Microphone + System Audio Into a Single File

**What goes wrong:**
ScreenCaptureKit provides system audio as one stream and AVAudioEngine provides microphone audio as another stream. These arrive at different sample rates, with different buffer sizes, and potentially different latencies. Developers try to concatenate raw buffers from both sources, resulting in desynchronized audio, garbled playback, or crashes when buffer sizes mismatch.

**Why it happens:**
ScreenCaptureKit delivers system audio as CMSampleBuffer objects at the system's audio sample rate (typically 48 kHz). AVAudioEngine delivers microphone audio at whatever format the engine is configured for (often 44.1 kHz by default). Simply interleaving or appending buffers from these two sources without resampling and time-aligning produces broken audio. There is no built-in macOS API that merges both streams automatically.

**How to avoid:**
- Record both streams to separate temporary files (one for mic, one for system audio)
- Use AVFoundation's `AVAsset` composition to merge them post-recording using `AVMutableComposition`
- Alternatively, resample both streams to a common sample rate in real-time and mix to a stereo file (left = system, right = microphone, or vice versa)
- Use `AVAudioMixerNode` if mixing in real-time, but be aware of latency differences
- The simplest approach: record both streams independently, then merge using `AVMutableComposition` + `AVMutableCompositionTrack` with time alignment
- For transcription, you can send each stream separately to the STT API (two transcriptions) rather than merging, which also gives you speaker separation

**Warning signs:**
- Merged audio plays back with clicking, popping, or gaps
- Audio duration mismatch between the two streams
- Transcription quality degrades (STT gets confused by garbled audio)
- Memory usage spikes during real-time mixing

**Phase to address:**
Phase 1 (Audio Capture Foundation) -- the decision of whether to mix in real-time or merge post-recording determines the entire recording architecture. Make this decision early.

---

### Pitfall 5: API Key Storage in Plaintext

**What goes wrong:**
The app requires users to enter OpenAI API keys (and potentially other provider keys) in the settings UI. These keys are stored in plaintext in UserDefaults, a plist file, or a local database. Any process running on the user's machine (including malware) can read UserDefaults plists from `~/Library/Preferences/`. API keys are high-value targets because they provide direct access to billing.

**Why it happens:**
UserDefaults is the easiest way to persist settings in a Mac app. Developers use it for convenience without considering that it stores data in plaintext XML/binary plist files. There is no "secure UserDefaults" on macOS -- Keychain is the only secure credential store.

**How to avoid:**
- Store ALL API keys in the macOS Keychain using `Security` framework or the Swift `KeychainAccess` library
- Never store API keys in UserDefaults, flat files, or unencrypted databases
- When displaying the key in settings UI, mask it (show only last 4 characters)
- Provide a "delete key" option that removes the key from Keychain
- Consider validating the key by making a small test API call when the user enters it
- Document that keys are stored in Keychain so users trust the app

**Warning signs:**
- API keys visible in `~/Library/Preferences/com.yourapp.plist`
- Users report unauthorized API usage after using the app
- No Keychain usage in the codebase
- Settings UI stores keys in `@AppStorage` (which uses UserDefaults under the hood)

**Phase to address:**
Phase 2 (Transcription Pipeline) -- API key management is needed as soon as the app calls external APIs. Build Keychain storage into the settings UI from day one.

---

### Pitfall 6: No Progress Indication During Transcription

**What goes wrong:**
Uploading a 20-minute audio file to the Whisper API takes time (upload + processing can be 30-120 seconds depending on file size and queue). The app appears frozen with no feedback. Users think the app crashed and force-quit it, wasting the upload and potentially corrupting local state.

**Why it happens:**
The OpenAI Whisper API does not provide upload progress callbacks or processing progress indicators. It is a synchronous request-response: you upload the file, wait, and get the full transcript back. There is no way to know how far along the transcription is. Developers implement the API call as a simple async task with no intermediate UI updates.

**How to avoid:**
- Show an indeterminate progress indicator (spinning bar) during transcription
- Display meaningful status messages: "Uploading audio..." -> "Transcribing..." -> "Processing..."
- Track upload progress if using a streaming upload approach
- For long recordings that are chunked, show "Transcribing part 1 of 5..." progress
- Make the transcription cancellable (store the task reference, allow user to cancel)
- Never block the main thread -- run all API calls on background queues
- Consider showing an estimated time remaining based on audio duration

**Warning signs:**
- App beach-balls during transcription
- Users report "app freezes after recording"
- Activity Monitor shows the app is not responding
- No loading indicators in the UI during API calls

**Phase to address:**
Phase 2 (Transcription Pipeline) -- progress indication should be built alongside the transcription feature, not added later.

---

### Pitfall 7: Silent Failures in Audio Recording

**What goes wrong:**
The app appears to be recording (shows a timer, red indicator) but the resulting audio file is empty, silent, or corrupted. This happens when the audio session is interrupted (phone call on iPhone, system audio route change on Mac), when permissions are revoked mid-recording, or when the audio buffer chain has a bug.

**Why it happens:**
macOS can interrupt audio sessions for various reasons: another app takes exclusive control of an audio device, the user changes audio output devices (plugs in headphones), or the system decides to revoke a permission. ScreenCaptureKit streams can stop delivering samples without explicitly stopping. If the app does not monitor for these events, it continues "recording" but writes silence.

**How to avoid:**
- Monitor audio levels during recording -- if levels stay at zero for more than a few seconds, alert the user
- Implement `SCStreamDelegate` methods to detect stream errors and interruptions
- For AVAudioEngine microphone capture, handle `AVAudioSession.interruptionNotification`
- Validate the recorded file after stopping: check file size, duration, and that it is not silence
- Write a "recording health check" that runs periodically: verify the stream is still delivering valid samples
- If the stream dies unexpectedly, attempt to restart it and log the error
- Never trust that a recording is valid just because the start call succeeded

**Warning signs:**
- Recorded file size is 0 bytes or suspiciously small
- Users report "I recorded a 1-hour meeting but the file is empty"
- Transcription returns empty text or "no speech detected"
- Audio level meters show no activity during "recording"

**Phase to address:**
Phase 1 (Audio Capture Foundation) -- recording health monitoring must be built into the recording engine from the start. Detecting silent recording is a critical reliability feature.

---

### Pitfall 8: Not Handling macOS Audio Device Changes

**What goes wrong:**
A user starts recording with their external microphone, then unplugs it or switches to AirPods mid-recording. The recording either stops, crashes, or continues but captures silence from the now-disconnected device.

**Why it happens:**
macOS changes the audio routing when devices are connected/disconnected. AVAudioEngine's input node may become invalid. The system may switch to a different input device, but the engine is still tied to the old device's format (different sample rate, channel count). ScreenCaptureKit audio capture is more resilient (it captures system audio regardless of output device), but microphone capture via AVAudioEngine is directly affected.

**How to avoid:**
- Listen for `AVAudioSession.routeChangeNotification` (or macOS equivalent: audio device change notifications via Core Audio)
- When a device change occurs during recording, re-initialize the audio engine with the new device
- If no suitable replacement device is found, pause recording and alert the user
- Test with Bluetooth devices that have different sample rates and latency
- Consider locking the audio session to a specific device during recording (prevent automatic switching)
- Provide UI to let the user select their preferred microphone device

**Warning signs:**
- Recording stops or crashes when headphones are connected/disconnected
- Audio quality changes mid-recording (sampling artifacts)
- App freezes when AirPods switch between Mac and iPhone

**Phase to address:**
Phase 1 (Audio Capture Foundation) -- device change handling is part of robust audio capture. Test with multiple device scenarios.

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Store API keys in UserDefaults | Ship settings UI in 1 hour | Security vulnerability, keys readable by any process | Never |
| Record to WAV (uncompressed) | Simpler code, no encoding overhead | Disk space explosion, 25 MB API limit hit quickly | Only for initial audio capture prototype, must switch to compressed before transcription |
| Use single audio stream (mic only) | Simpler architecture, avoids ScreenCaptureKit complexity | Core value proposition broken -- cannot capture meeting audio from Zoom/Meet | Never -- system audio capture is a core requirement |
| Synchronous API calls on main thread | Simpler code | UI freezes, app appears broken, force-quits | Never -- all API calls must be async |
| Skip audio chunking, upload full file | Simpler transcription code | Fails for recordings over ~25-30 minutes (API limit) | Acceptable for MVP if you limit recording duration, but must implement before public release |
| Hard-code OpenAI as only provider | Ship faster | Users locked into one provider, no price competition, provider outage = total failure | Acceptable for MVP, but abstract the STT interface from day one |
| No retry logic for API calls | Simpler code | Transcription fails on network hiccups, users must manually retry | Never -- implement exponential backoff retry at minimum |

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| ScreenCaptureKit | Requesting Microphone permission instead of Screen Recording permission for system audio | System audio requires Screen Recording permission (CGPreflightScreenCaptureAccess), NOT Microphone permission. Request BOTH permissions since you need mic permission too. |
| ScreenCaptureKit | Not restarting the app after Screen Recording permission is granted | Detect that permission was just granted and force quit + relaunch. There is no way around this macOS requirement. |
| OpenAI Whisper API | Uploading WAV files (huge) instead of compressed formats | Convert to MP3/AAC/M4A before upload. Use AVAssetExportSession to compress. This drastically reduces upload time and stays under the 25 MB limit. |
| OpenAI Whisper API | Ignoring the `prompt` parameter for multi-chunk continuity | When splitting audio into chunks, pass the transcript of the previous chunk as the `prompt` parameter so the model maintains context across chunk boundaries. |
| OpenAI Whisper API | Using `whisper-1` for Chinese/English mixed language | The newer `gpt-4o-transcribe` model handles mixed languages better than `whisper-1`. Test both and compare quality for CJK+English mixing. |
| OpenAI Chat API | Sending raw transcript without structure instructions for analysis | Use a carefully crafted system prompt that specifies exactly what to extract (summary, action items, decisions, key topics) with output format instructions. |
| AVAudioEngine | Not handling the engine's `stop()` during interruptions | Restart the engine and re-connect nodes when an interruption ends. AVAudioEngine stops itself during interruptions and does not auto-restart. |
| Keychain | Using Keychain without an access group | If you ever plan to share credentials with an extension or helper app, set up an access group from the start. Refactoring Keychain access later is painful. |

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Real-time audio mixing of mic + system audio | CPU spikes, audio glitches, dropped frames | Record to separate files, merge post-recording using AVComposition | First real meeting with both audio sources |
| Accumulating CMSampleBuffers in memory | Memory usage grows linearly with recording duration, eventually crashes | Write audio to disk incrementally (stream to file) rather than buffering in memory | Recordings over 10-15 minutes |
| Loading full recording waveform in UI | UI becomes sluggish, high memory usage for long recordings | Render waveform at reduced resolution (downsample), use lazy loading for waveform display | Recordings over 30 minutes |
| Storing recordings in app container | Disk space grows unbounded, no user control over storage location | Let user configure output folder outside app container, implement auto-cleanup policy | After 50+ recordings |
| Transcribing multiple recordings simultaneously | API rate limits hit, costs spiral, UI becomes confusing | Queue transcriptions (one at a time), show queue position, let user prioritize | When user records 5+ meetings before transcribing |
| Sending full transcript to GPT for analysis | Token limit exceeded for long meetings (GPT-4o has 128K context) | Chunk analysis: summarize sections first, then combine summaries. Or use GPT-4o-mini for longer context. | Meetings over 60-90 minutes produce transcripts exceeding 50K+ tokens |

## Security Mistakes

| Mistake | Risk | Prevention |
|---------|------|------------|
| Storing API keys in UserDefaults/plist | Any process on the Mac can read the plist file and steal the key | Use macOS Keychain exclusively. Keychain items are encrypted and access-controlled. |
| Logging API keys in debug output | Keys appear in Console.app, crash logs, or developer tools | Never log API keys, even in debug builds. Redact sensitive fields in all log output. |
| Transmitting API keys over non-HTTPS | Man-in-the-middle can intercept keys | All OpenAI API calls are HTTPS by default. Never proxy or intercept API calls in ways that downgrade security. |
| Storing raw audio recordings unencrypted | Meeting audio contains sensitive business information. Other users of the same Mac could access it. | Store recordings in app's container (protected by macOS sandbox). For standalone distribution, consider encrypting at rest or warning users about storage location. |
| Not validating API key input | Malformed keys cause confusing errors later | Validate key format when entered. Make a test API call (small transcription) to verify the key works before accepting it. |
| Including API keys in crash reports | Keys leak to crash reporting services | Filter crash report data to exclude any Keychain-accessed values. |

## UX Pitfalls

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| No visual feedback during recording | Users do not know if recording is active, may double-record or miss recording entirely | Persistent menu bar indicator (microphone icon that pulses while recording). Show recording duration timer. |
| Confusing permission flow | Users grant permission but app still does not work (requires restart) | Step-by-step onboarding: 1) Explain why permission is needed 2) Open System Settings to correct pane 3) Detect when granted 4) Prompt for restart |
| No way to cancel in-progress transcription | Users accidentally transcribe a 2-hour file and cannot stop it. Wastes API credits. | Cancel button during transcription. Estimated cost shown before starting. |
| Recording stops when app window is closed | Users close the window thinking recording continues in background, but it stops | Menu bar app that persists regardless of window state. Closing window does not stop recording. Global shortcut to stop. |
| No recording history | Users lose track of what they recorded, cannot find previous analyses | Dashboard showing recording history with search, date filters, and quick access to transcripts and analyses. |
| Markdown output not opened after generation | Users do not know where the file was saved or that it was created | Auto-open the Markdown file after generation. Show the file path. Optionally show a preview in-app. |
| No estimated cost before API call | Users are surprised by API charges | Show estimated cost before transcription/analysis: "This 45-minute recording will cost approximately $0.15 to transcribe" |
| No error messages for failed recordings | Recording silently fails, user thinks they have a recording but they do not | Clear error alerts with actionable messages: "Microphone disconnected. Recording saved (partial). Reconnect and try again." |

## "Looks Done But Isn't" Checklist

- [ ] **Audio capture:** Often missing system audio -- verify BOTH mic and system audio produce non-silent files
- [ ] **Permission handling:** Often missing the restart requirement -- verify the full grant-then-restart flow works
- [ ] **Long recordings:** Often broken by the 25 MB limit -- verify transcription works for a 60+ minute recording
- [ ] **Audio device changes:** Often crashes on device disconnect -- verify recording survives unplugging/replugging headphones
- [ ] **API key settings:** Often storing in UserDefaults -- verify keys are in Keychain by checking `~/Library/Preferences/` does NOT contain the key
- [ ] **Transcription of mixed languages:** Often degrades on Chinese/English mixing -- verify with a real mixed-language recording, not just English
- [ ] **Global shortcut:** Often conflicts with system shortcuts -- verify the shortcut works across all apps without conflicts
- [ ] **Background recording:** Often stops when app loses focus -- verify recording continues when the app is in the background or minimized
- [ ] **Markdown output:** Often has formatting issues with special characters from transcript -- verify output renders correctly in a Markdown viewer
- [ ] **Disk space:** Often does not handle full disk -- verify the app handles disk-full gracefully without data loss

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Stored API keys in UserDefaults | LOW | Migrate to Keychain in next release. Read from UserDefaults, write to Keychain, delete from UserDefaults. One-time migration on app launch. |
| Built audio capture without ScreenCaptureKit | HIGH | Rewrite entire audio capture layer. This is a fundamental architecture change. Estimated 1-2 weeks of work. |
| No audio chunking for long recordings | MEDIUM | Add chunking layer between recording and transcription. Must also handle re-transcription of existing long recordings. |
| No Keychain integration for API keys | LOW | Add Keychain wrapper, migrate existing keys. Can be done incrementally. |
| UI blocks during API calls | MEDIUM | Refactor to async/await with proper main actor isolation. Requires touching all API call sites. |
| Real-time audio mixing instead of post-merge | MEDIUM | Switch to dual-file recording + post-recording merge. Requires changes to recording engine, but does not affect transcription pipeline. |
| No error handling for interrupted recordings | MEDIUM | Add recording health monitoring. Partial recordings may still be usable. Add recovery logic that detects and offers to transcribe partial files. |

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| Screen Recording permission requires restart | Phase 1: Audio Capture | Test fresh install flow: deny permission, grant it, verify app prompts for restart, verify recording works after restart |
| 25 MB file upload limit | Phase 1: Audio Capture (format choice) + Phase 2: Transcription | Record a 60+ minute meeting, verify the full pipeline (record + compress + chunk + transcribe) works end-to-end |
| System audio requires ScreenCaptureKit | Phase 1: Audio Capture | Verify system audio is captured by playing music while recording and checking the output file |
| Merging mic + system audio | Phase 1: Audio Capture | Record with both sources, play back the merged file, verify both sources are audible and synchronized |
| API key plaintext storage | Phase 2: Transcription Pipeline | Check `~/Library/Preferences/` plist files for the app -- API keys must NOT appear in plaintext |
| No progress during transcription | Phase 2: Transcription Pipeline | Transcribe a 30+ minute recording, verify progress indicator is visible and the app remains responsive |
| Silent recording failures | Phase 1: Audio Capture | Simulate failure: disconnect mic during recording, verify the app detects and alerts |
| Audio device changes mid-recording | Phase 1: Audio Capture | Plug/unplug headphones during recording, verify recording continues or alerts gracefully |
| Mixed language transcription quality | Phase 2: Transcription Pipeline | Test with real Chinese/English mixed meeting audio, verify quality is acceptable |
| Global shortcut conflicts | Phase 3: Polish & Distribution | Test shortcut across multiple apps, verify no conflicts with system or common app shortcuts |
| Background recording | Phase 3: Polish & Distribution | Start recording, switch to other apps, use other apps for 10+ minutes, verify recording is complete |
| Cost estimation | Phase 2: Transcription Pipeline | Show estimated cost for a known-duration recording, verify estimate is reasonably accurate |

## Sources

- Apple ScreenCaptureKit official documentation (capturing-screen-content-in-macos) -- verified 2026-04-06
- OpenAI Speech-to-Text API documentation (platform.openai.com/docs/guides/speech-to-text) -- verified 2026-04-06
- OpenAI API Pricing page (openai.com/api/pricing) -- verified 2026-04-06
- WWDC22 Session 10156: Meet ScreenCaptureKit
- WWDC22 Session 10155: Take ScreenCaptureKit to the next level
- WWDC23 Session 10136: What's new in ScreenCaptureKit
- WWDC24 Session 10088: Capture HDR content with ScreenCaptureKit
- Confidence: MEDIUM-HIGH for Apple-specific pitfalls (from official docs), MEDIUM for community patterns (from training data)

---
*Pitfalls research for: Mac desktop audio recording + AI transcription/analysis*
*Researched: 2026-04-06*
