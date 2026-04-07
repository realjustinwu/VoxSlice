# Requirements: VoxSlice

**Defined:** 2026-04-06
**Core Value:** 一键会议录音 → 结构化 AI 分析 Markdown 文件

## v1 Requirements

Requirements for initial release. Each maps to roadmap phases.

### Audio Recording

- [ ] **RECD-01**: User can start/stop recording via global keyboard shortcut from any context
- [x] **RECD-02**: App records both microphone and system audio simultaneously
- [x] **RECD-03**: Visual indicator shows recording status (menu bar icon + floating indicator)
- [x] **RECD-04**: Recording continues when app window is hidden or minimized
- [ ] **RECD-05**: App requests and handles macOS Screen Recording and Microphone permissions gracefully

### Transcription

- [x] **TRSC-01**: App supports multiple STT providers (OpenAI Whisper API, local models like WhisperKit, and other third-party STT APIs)
- [x] **TRSC-02**: Transcription auto-detects language (Chinese/English/mixed)
- [x] **TRSC-03**: Transcript includes timestamps for navigation
- [x] **TRSC-04**: Long recordings are automatically chunked to handle API upload limits
- [x] **TRSC-05**: Transcript identifies speakers (Speaker 1, Speaker 2, Speaker 3, etc.) via speaker diarization

### AI Analysis

- [x] **ANLY-01**: AI generates concise meeting summary
- [x] **ANLY-02**: AI extracts action items from discussion
- [x] **ANLY-03**: AI identifies key decisions made during meeting
- [x] **ANLY-04**: AI extracts main discussion topics with descriptions
- [x] **ANLY-05**: All analysis results are structured and clearly formatted

### Output

- [x] **OUTP-01**: Analysis results are saved as Markdown files with YAML frontmatter (date, duration, topics)
- [x] **OUTP-02**: User can configure the output folder for saved files
- [x] **OUTP-03**: User can copy analysis sections to clipboard

### User Interface

- [ ] **UIUX-01**: Full window dashboard showing recording history with status
- [x] **UIUX-02**: Settings screen for selecting STT provider, managing API keys, and configuring local models with validation
- [x] **UIUX-03**: Menu bar integration for quick access to recording controls
- [ ] **UIUX-04**: Audio playback synced to transcript position (click transcript to hear that moment)

### Distribution

- [ ] **DIST-01**: App is distributable as an installable Mac application (DMG)

## v2 Requirements

Deferred to future release. Tracked but not in current roadmap.

### Advanced Analysis

- **AANL-01**: Custom AI analysis templates (e.g., technical requirements vs sales objections)
- **AANL-02**: Chat with transcript (Q&A against meeting content)
- **AANL-03**: Cross-meeting search across all transcripts

### Advanced Features

- **AADV-01**: Real-time transcription during recording
- **AADV-02**: On-device transcription via WhisperKit (offline mode)
- **AADV-03**: Post-meeting AI actions (draft follow-up email, create tasks)

## Out of Scope

| Feature | Reason |
|---------|--------|
| Meeting bot joining calls | Direct system audio capture is a differentiator |
| Video recording | Audio-only keeps scope manageable and privacy-friendly |
| Cloud storage/sync | Local-first for privacy; users can use Dropbox/iCloud |
| Collaboration/team features | Single-user tool for v1 |
| CRM integrations | Export to Markdown; users can manually copy to CRM |
| Subscription billing | BYOK model; users bring their own API keys |
| Mobile app | macOS desktop only |
| Proprietary file formats | Plain Markdown always |
| Enterprise admin features | Focus on individual professionals |
| In-app transcript editor | Export and edit in preferred editor |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| RECD-01 | Phase 6 | Pending |
| RECD-02 | Phase 2 | Complete |
| RECD-03 | Phase 2 | Complete |
| RECD-04 | Phase 2 | Complete |
| RECD-05 | Phase 1 | Pending |
| TRSC-01 | Phase 3 | Complete |
| TRSC-02 | Phase 3 | Complete |
| TRSC-03 | Phase 3 | Complete |
| TRSC-04 | Phase 3 | Complete |
| TRSC-05 | Phase 3 | Complete |
| ANLY-01 | Phase 4 | Complete |
| ANLY-02 | Phase 4 | Complete |
| ANLY-03 | Phase 4 | Complete |
| ANLY-04 | Phase 4 | Complete |
| ANLY-05 | Phase 4 | Complete |
| OUTP-01 | Phase 4 | Complete |
| OUTP-02 | Phase 4 | Complete |
| OUTP-03 | Phase 4 | Complete |
| UIUX-01 | Phase 5 | Pending |
| UIUX-02 | Phase 1 | Complete |
| UIUX-03 | Phase 1 | Complete |
| UIUX-04 | Phase 5 | Pending |
| DIST-01 | Phase 6 | Pending |

**Coverage:**
- v1 requirements: 23 total
- Mapped to phases: 23
- Unmapped: 0

---
*Requirements defined: 2026-04-06*
*Last updated: 2026-04-06 after roadmap creation*
