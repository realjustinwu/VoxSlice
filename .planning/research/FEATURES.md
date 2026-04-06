# Feature Landscape

**Domain:** Mac desktop audio recording + AI transcription/analysis
**Researched:** 2026-04-06

## Competitors Analyzed

| Product | Type | Platform | Recording Method | AI Analysis |
|---------|------|----------|-----------------|-------------|
| MacWhisper | Native Mac app | macOS | Mic + System audio | Optional (bring own API key for ChatGPT/Claude) |
| Aiko | Native Mac/iOS app | macOS + iOS | Mic only | None (transcription-only) |
| Granola | Web + native app | Cross-platform | System audio (no bots) | Built-in AI summaries, templates, Q&A |
| tl;dv | Browser extension + web | Cross-platform | Meeting bot joins call | AI summaries, CRM integration, multi-meeting insights |
| Fireflies | Web platform + bots | Cross-platform | Meeting bot joins call | AI summaries, 200+ AI skills, CRM, team analytics |
| Fathom | Browser extension + desktop | Cross-platform | Meeting bot joins call | AI summaries, action items, CRM sync |
| Descript | Native desktop app | macOS + Windows | Screen/mic recording | Full editing suite, transcription, AI tools |
| Plaud | Hardware + desktop app | macOS + Windows + mobile | Hardware device + desktop system audio | AI summaries, templates, Q&A, 112 languages |

---

## Table Stakes

Features users expect. Missing = product feels incomplete.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| One-click recording start/stop | Core interaction model. Every competitor has a prominent record button. Users will not tolerate multi-step workflows to begin capturing. | Low | Global keyboard shortcut is a strong differentiator on Mac. MacWhisper has menubar + spotlight access. |
| Simultaneous mic + system audio capture | Meetings happen on Zoom/Meet/Teams. Users need both their own voice AND the remote participants. Single-source recording is a dealbreaker. | Med | Requires macOS screen recording permission. Granola advertises "no bots" system audio capture as a feature. |
| Transcription with timestamps | Every single competitor transcribes. Without it, the product is just a voice recorder. Timestamps are needed for navigation and citation. | Med | OpenAI Whisper API handles this well. On-device (MacWhisper, Aiko) vs cloud tradeoff. |
| Auto language detection (Chinese/English/mixed) | Critical for VoxSlice's target audience. Competitors like Fireflies and MacWhisper support 100+ languages with auto-detect. | Low (API feature) | Whisper handles this natively. The challenge is accuracy on code-switching mid-sentence. |
| AI-generated summary | Every major competitor (Granola, tl;dv, Fireflies, Fathom, Plaud) produces an automatic meeting summary. This is THE core value proposition. | Med | Summary quality is a major differentiator. Users compare across tools. |
| Action items extraction | Present in Granola, Fathom, tl;dv, Fireflies. Users explicitly cite this as their favorite feature. Without it, summaries feel incomplete. | Low | Requires careful prompt engineering. Format matters (assignee, deadline, context). |
| Recording history / dashboard | Users need to find past recordings. Even Aiko (minimalist) shows a list. Granola, Fathom, tl;dv all have full dashboards. | Med | Search across transcripts is table stakes once you have history. |
| Export to common formats | Users need to get data OUT. Every competitor supports copy/paste at minimum. MacWhisper supports SRT/VTT/CSV/DOCX/PDF/MD/HTML. | Low | Markdown export is VoxSlice's chosen format. Ensure copy-to-clipboard works. |
| Configurable output folder | Power users organize files their own way. MacWhisper has "Watch Folder" for automated workflows. | Low | Simple settings UI. Path picker. |
| API key management (BYOK) | Users who choose desktop apps over SaaS often prefer controlling their own API costs. MacWhisper supports OpenAI, Claude, Groq, Ollama, custom endpoints. | Low | Settings screen with key input fields. Validate keys on save. |
| Visual recording indicator | Users need to know recording is active without checking the app. Menubar icon, floating indicator, or status bar item. | Low | MacWhisper uses menubar. Could add a subtle floating dot. |

---

## Differentiators

Features that set product apart. Not expected, but valued.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Zero-latency local-first architecture | Most competitors are cloud-dependent. VoxSlice keeps all audio local (privacy). MacWhisper and Aiko do on-device transcription, but lack the AI analysis pipeline. Combining local privacy with cloud AI analysis is a unique middle ground. | High | Requires careful architecture to keep audio local while still using API for transcription/analysis. |
| Global hotkey with instant capture | MacWhisper has spotlight-style access, Granola has no-meeting-bot capture. A global hotkey that starts recording from ANY context (even when app is hidden) is rare and highly valued. Fathom users praise auto-start, but it only works for calendar meetings. | Med | macOS CGEvent / global shortcut API. Need to handle permission dialogs gracefully. |
| Structured Markdown output with frontmatter | No competitor produces clean, immediately shareable Markdown files. Granola shares to Slack/Notion/CRM but not as files. MacWhisper exports MD but not with structured AI analysis. Output like YAML frontmatter (date, duration, attendees, topics) + structured sections is unique. | Low | Design the Markdown template carefully. Make it beautiful by default. |
| Decision extraction | Granola extracts "decision-making insights." Most competitors focus on summary + action items. Explicitly calling out DECISIONS made in a meeting is uncommon and highly valuable for accountability. | Low | Additional prompt section. Need to distinguish decisions from discussion topics. |
| Key topics / themes extraction | tl;dv offers "AI topics." Fireflies has "channels." Plaud has "multidimensional summaries." Extracting named topics with descriptions adds structure that raw summaries lack. | Low | Prompt engineering. Consider weighting by frequency and importance. |
| No meeting bot required | Granola and Plaud Desktop specifically advertise "no bots joining your call." Users find bots intrusive and they sometimes get blocked by enterprise IT. Direct system audio capture is a genuine advantage. | Med (already in design) | VoxSlice already plans this. Emphasize in marketing. |
| Custom AI analysis templates | Granola has templates for "customer discovery calls, user interviews, 1 on 1s." Plaud has "10,000+ official templates." Allowing users to define their own analysis structure (e.g., "extract technical requirements" vs "extract sales objections") is powerful. | Med | Start with 3-4 built-in templates, add custom template editor in v2. |
| Chat with transcript (Q&A) | Granola, Fireflies, Rev, and Plaud all offer "ask questions about your meeting." This is extremely valuable for recalling specific details without re-reading the whole transcript. | Med | Requires transcript to be in a queryable format. Can use LLM context window for shorter meetings. |
| Speaker diarization (who said what) | Fireflies, Fathom, MacWhisper Pro, Plaud all identify speakers. Critical for multi-person meetings. Without it, transcripts are a wall of text. | High | MacWhisper uses local models (M-series) or ElevenLabs/Deepgram. OpenAI Whisper API does not do diarization natively. This is a significant gap. |
| Real-time transcription preview | Aiko plans it. MacWhisper Pro has "realtime captions." tl;dv shows live transcript. Showing transcription as it happens lets users verify capture quality mid-meeting. | High (deferred) | PROJECT.md explicitly defers this to v2. Correct call -- adds significant complexity to audio pipeline. |
| Post-meeting AI actions | Granola generates follow-up emails. tl;dv drafts emails and CRM updates. Fireflies has 200+ "AI Skills." After analysis, offering one-click "draft follow-up email" or "create Jira tickets from action items" saves real time. | Med | Can be prompt-driven. Offer 2-3 actions initially (email draft, action items to clipboard). |
| Cross-meeting search | Fathom and Fireflies offer search across all transcripts. Once users accumulate many recordings, finding "what did we decide about X in that meeting 3 weeks ago" becomes critical. | Med | Requires local indexing. SQLite FTS5 or similar. Could defer to Spotlight integration on macOS. |
| Offline operation / on-device transcription | Aiko and MacWhisper do full on-device transcription. VoxSlice could offer a hybrid mode: on-device transcription for privacy-sensitive content, cloud for better accuracy. Apple's WhisperKit / Whisper models running locally. | High | Significant engineering. M-series Macs can run Whisper models. Intel Macs struggle (per MacWhisper docs). Defer to v2. |
| Audio playback synced to transcript | MacWhisper, Fathom, and Descript all sync audio playback to transcript position. Click a transcript line, hear that moment. Essential for verification. | Med | Requires timestamped transcription (Whisper provides word-level timestamps). Audio player + text sync UI. |

---

## Anti-Features

Features to explicitly NOT build.

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| Meeting bot that joins calls | Bot-based capture is the model for tl;dv, Fireflies, Otter, Fathom. It creates friction (enterprise IT blocks bots, participants notice and feel surveilled, bot can crash). VoxSlice's direct system audio capture is a differentiator. Keep it bot-free. | Record system audio directly via macOS APIs. |
| Video recording | Descript is a full video editor. That is a different product entirely. Video adds massive storage, processing, and UI complexity. Audio-only is simpler and more privacy-friendly. | Audio only. If users want video, they can use OBS or built-in screen recording. |
| Cloud storage / sync | PROJECT.md explicitly states "local-only for v1, privacy first." Cloud sync means servers, authentication, data residency, GDPR compliance, and cost. Granola, tl;dv, Fireflies all have cloud backends. VoxSlice's local-first approach is a differentiator. | Save files to user's local filesystem. Let users sync via Dropbox/iCloud if they want. |
| Collaboration / team features | Fireflies has user groups, channels, team analytics. tl;dv has team-wide insights. These require multi-user architecture, permissions, billing. Single-user is the right scope for v1. | Single-user tool. Share by exporting/sending Markdown files. |
| CRM integrations | Fathom, Fireflies, tl;dv all integrate with Salesforce/HubSpot. This is sales-team focused and requires API integrations, OAuth, and ongoing maintenance of third-party API changes. | Export to Markdown. Users can copy into CRM manually. CRM integration is v2+ if demand exists. |
| Real-time transcription | Already correctly scoped out in PROJECT.md. The audio pipeline complexity doubles when you need streaming transcription. Post-meeting transcription is simpler and sufficient for most users. | Process audio after recording stops. |
| Built-in subscription billing | MacWhisper charges a one-time payment. Aiko is a single purchase. Avoid building billing infrastructure. Let users bring their own API keys for STT/AI and keep the app itself as a one-time purchase or free. | BYOK model. No subscription. |
| Mobile app | Aiko, Plaud, Otter have mobile apps. Mobile requires completely different audio capture APIs, UI, and app store distribution. Focus on Mac desktop excellence first. | macOS only. |
| Proprietary file formats | Some tools use custom formats (MacWhisper has .whisper files). VoxSlice's Markdown output is a strength. Do not lock users into a format they cannot read without the app. | Plain Markdown files. Always. |
| Enterprise / admin features | Fireflies advertises SOC2, GDPR, HIPAA, enterprise admin controls. These require significant compliance overhead. Not appropriate for a v1 single-user tool. | Focus on individual professionals. |
| In-app transcript editor | Aiko explicitly refuses to add editing ("Export the transcription and edit it in a proper text editor"). Descript is a full editor. Transcript editing adds significant UI complexity and is not the core value. | Export Markdown. Let users edit in their preferred editor. |

---

## Feature Dependencies

```
Audio Capture (mic + system)
  -> Raw Audio File
    -> Transcription (Whisper API)
      -> Timestamped Transcript
        -> AI Analysis (LLM API)
          -> Summary
          -> Action Items
          -> Decisions
          -> Key Topics
        -> Markdown Export
          -> File saved to output folder

Global Hotkey -> triggers Audio Capture start/stop (independent of UI)

Settings (API keys) -> required before Transcription + AI Analysis can work

Recording History Dashboard -> depends on saved Markdown files + metadata

Speaker Diarization -> depends on Transcription (separate processing step)

Chat with Transcript -> depends on stored Transcript + LLM integration

Audio Playback Sync -> depends on Timestamped Transcript + Audio File retention
```

**Critical path:** Audio Capture -> Transcription -> AI Analysis -> Markdown Export

Everything else is additive.

---

## MVP Recommendation

Prioritize (Phase 1 -- must ship):

1. **Global hotkey to start/stop recording** -- the interaction model
2. **Simultaneous mic + system audio capture** -- the core technical capability
3. **Post-meeting transcription via Whisper API** -- the foundation
4. **AI analysis extracting summary + action items + decisions + topics** -- the core value
5. **Markdown export to configurable folder** -- the output
6. **Simple dashboard showing recording history** -- the home screen
7. **API key settings screen** -- the onboarding

Strongly consider for Phase 1 (high impact, moderate effort):

8. **Audio playback synced to transcript** -- users need to verify accuracy
9. **Copy-to-clipboard for analysis sections** -- immediate sharing

Defer to Phase 2:

- **Speaker diarization** -- significant additional complexity, no clean API solution
- **Custom analysis templates** -- good differentiator but not MVP
- **Chat with transcript** -- valuable but needs architecture for transcript storage/indexing
- **Cross-meeting search** -- needs accumulation of recordings first
- **Real-time transcription** -- explicitly deferred in PROJECT.md, correct decision

---

## Competitive Positioning for VoxSlice

**Where VoxSlice wins:**
- Local-first privacy (audio never leaves machine, unlike Granola/tl;dv/Fireflies)
- No meeting bot (unlike Otter/tl;dv/Fireflies/Fathom)
- Structured Markdown output (no competitor does this well)
- BYOK model (no subscription, unlike Granola/tl;dv/Fathom)
- Chinese/English mixed-language support (few competitors handle this well)

**Where VoxSlice is weaker (accept and don't chase):**
- No team collaboration (Granola, Fireflies excel here)
- No CRM integrations (Fathom, tl;dv have deep CRM pipelines)
- No real-time transcription (tl;dv, MacWhisper Pro offer this)
- No video (Descript is a full video suite)
- No mobile (Otter, Plaud, Aiko have mobile apps)

---

## Sources

- MacWhisper (macwhisper.com) -- full feature list, pricing model, on-device vs cloud options
- Aiko (sindresorhus.com/aiko) -- minimalist transcription-only approach, on-device Whisper
- Granola (granola.so) -- AI notepad model, system audio capture, templates, sharing
- tl;dv (tldv.io) -- meeting bot model, CRM integration, multi-meeting AI insights
- Fireflies (fireflies.ai) -- enterprise features, 200+ AI skills, team analytics
- Fathom (fathom.video) -- free tier model, highlight/bookmark UX, CRM sync
- Descript (descript.com) -- full editing suite, video focus, pricing tiers
- Plaud (plaud.ai) -- hardware + software model, desktop system audio capture, templates
- VoxSlice PROJECT.md -- project scope, constraints, and out-of-scope decisions
