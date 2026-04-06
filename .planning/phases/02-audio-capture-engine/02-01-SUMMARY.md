---
phase: 02-audio-capture-engine
plan: 01
status: completed
completed: 2026-04-06
requirements: [RECD-02, RECD-04]
---

## Plan 02-01: Dual-Stream Audio Capture Engine

### What was built

Core dual-stream audio capture engine that simultaneously records microphone audio (via AVAudioEngine) and system audio (via ScreenCaptureKit) to separate M4A files.

### Key Files

**Created:**
- `VoxSlice/Models/RecordingInfo.swift` — RecordingState enum, RecordingError enum, AudioDeviceChange struct, RecordingInfo model with all required fields
- `VoxSlice/Services/AudioCaptureService.swift` — Full dual-stream capture engine with silence detection, device change handling, audio level metering
- `VoxSlice/Utils/Constants.swift` (modified) — Added audio constants: sample rate 44100Hz, bitrate 128kbps, silence timeout 30s, file extensions

**Modified:**
- `VoxSlice.xcodeproj/project.pbxproj` — Added new source files to project

### Architecture

- `AudioCaptureService` (@Observable, @MainActor) — Main service class with:
  - `startRecording()` — Checks permissions, creates dual AVAudioFile outputs, starts AVAudioEngine mic tap + SCStream system audio capture
  - `stopRecording()` — Stops both streams, closes files, saves metadata JSON
  - `checkSilence()` — 30-second silence detection with auto-stop
  - `handleDeviceChange()` — Restarts mic capture on audio device changes
- `AudioStreamOutput` (private class) — SCStreamOutput/SCStreamDelegate handling system audio CMSampleBuffer → AVAudioPCMBuffer conversion

### Decisions

- Continued recording if only one stream (mic OR system) starts successfully
- Made `calculateRMS` nonisolated static for safe background-queue calls
- Used `AVAudioConverter` for format conversion when input sample rate differs from target 44100Hz

### Issues Resolved

- Fixed extra closing brace in `startDurationTimer` that prematurely closed the class
- Fixed Swift 6 concurrency issues: `@MainActor` isolation on `AudioStreamOutput.service` and `calculateRMS`

## Self-Check: PASSED

- [x] AudioCaptureService.swift compiles and builds
- [x] RecordingInfo model has all required fields (RecordingState, RecordingError, AudioDeviceChange, RecordingInfo)
- [x] startRecording() checks permissions before proceeding
- [x] Dual-stream capture writes to separate M4A files
- [x] Silence detection auto-stops after 30 seconds
- [x] Device change handling restarts mic capture
- [x] Audio format: M4A/AAC at 44.1kHz/128kbps
- [x] SCStream configured with capturesAudio=true, excludesCurrentProcessAudio=true
