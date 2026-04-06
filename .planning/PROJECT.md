# VoxSlice

## What This Is

VoxSlice is a native Mac desktop application that records audio from both microphone and system audio, transcribes it using STT APIs (OpenAI Whisper etc.), and uses AI to analyze meeting transcripts — extracting summaries, action items, decisions, and key topics. Results are saved as timestamped Markdown files to a user-configured folder.

## Core Value

One-click meeting recording → structured AI analysis in a Markdown file you can share immediately.

## Requirements

### Validated

<!-- Shipped and confirmed valuable. -->

- [x] In-app settings to configure API keys (STT provider, AI provider) — Validated in Phase 1

### Active

<!-- Current scope. Building toward these. -->

- [ ] Global keyboard shortcut to start/stop recording from anywhere on Mac
- [ ] Record both microphone and system audio simultaneously
- [ ] Transcribe audio using OpenAI Whisper API (or compatible STT APIs) with auto language detection (Chinese/English/mixed)
- [ ] Save raw transcripts with timestamps
- [ ] AI analysis extracts: summary, action items, decisions, key topics
- [ ] Export analysis results as Markdown files to a configurable output folder
- [ ] Full window app with dashboard showing recording history and status
- [ ] Installable Mac application (DMG or similar distributable)

### Out of Scope

<!-- Explicit boundaries. Includes reasoning to prevent re-adding. -->

- Real-time transcription during recording — defer to v2, adds significant complexity
- Cloud sync of recordings — local-only for v1, privacy first
- Multi-platform (Windows/Linux) — Mac-only for now
- Video recording — audio only
- Collaboration features — single-user tool

## Context

- Target platform: macOS (Apple Silicon + Intel)
- Primary use case: meeting recording and analysis
- Meetings may be in Chinese, English, or mixed languages
- System audio capture needed for Zoom/Meet/etc. output
- Users need to bring their own API keys (OpenAI, etc.)
- Output should be shareable Markdown — no proprietary formats

## Constraints

- **Platform**: macOS only — Mac-specific APIs for audio capture and global shortcuts
- **Audio**: Must capture both microphone and system audio — requires screen recording permission on macOS
- **API**: Requires external STT and AI APIs — user must provide their own keys
- **Distribution**: Must be a proper installable Mac app — not a CLI or web app

## Key Decisions

<!-- Decisions that constrain future work. Add throughout project lifecycle. -->

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Mac desktop app (not Electron web app) | Better system integration for audio capture and global shortcuts | — Pending |
| OpenAI Whisper for STT | Best multilingual support including Chinese/English mixing | — Pending |
| Markdown output format | Human-readable, shareable, no special tools needed | — Pending |
| Local file storage | Privacy — meeting audio stays on user's machine | — Pending |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd-transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd-complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-04-06 after Phase 1 completion*
