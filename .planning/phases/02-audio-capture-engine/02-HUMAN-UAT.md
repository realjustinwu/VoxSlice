---
status: partial
phase: 02-audio-capture-engine
source: [02-VERIFICATION.md]
started: 2026-04-06T15:23:23Z
updated: 2026-04-06T15:23:23Z
---

## Current Test

[awaiting human testing]

## Tests

### 1. Dual-stream audio capture
expected: Start recording, verify both `_mic.m4a` and `_system.m4a` files are created in recordings directory with audible content
result: [pending]

### 2. Background continuity
expected: Recording continues when app window is hidden, minimized, or app is in background
result: [pending]

### 3. Device change resilience
expected: Recording survives audio device changes (headphone disconnect/reconnect) without crashing
result: [pending]

### 4. Menu bar visual state
expected: Menu bar icon changes to red circle (record.circle) when recording, reverts to waveform.circle silently when stopped
result: [pending]

### 5. Silence detection auto-stop
expected: Recording auto-stops after 30 seconds of silence with notification
result: [pending]

## Summary

total: 5
passed: 0
issues: 0
pending: 5
skipped: 0
blocked: 0

## Gaps
