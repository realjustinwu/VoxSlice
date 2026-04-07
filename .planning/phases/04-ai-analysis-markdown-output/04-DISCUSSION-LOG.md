# Phase 4: AI Analysis + Markdown Output - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-07
**Phase:** 04-ai-analysis-markdown-output
**Areas discussed:** Analysis structure & prompt design, Markdown output format, Analysis trigger & UX flow, In-app interaction with results

---

## Analysis Structure & Prompt Design

| Option | Description | Selected |
|--------|-------------|----------|
| Single structured prompt | One API call returns all sections as JSON. Simpler, faster. | ✓ |
| Separate prompts per section | One prompt per section. More API calls, more tokens. | |
| You decide | Claude discretion | |

**User's choice:** Single structured prompt (Recommended)
**Notes:** One API call returning structured JSON with all sections — summary, action items, decisions, topics.

| Option | Description | Selected |
|--------|-------------|----------|
| Concise (3-5 sentences) | Quick to read, good for scanning | |
| Detailed (full paragraph) | Full context but longer | |
| TL;DR + Detailed summary | Both quick-scan and deep-read. More output. | ✓ |

**User's choice:** TL;DR + Detailed summary
**Notes:** One-line TL;DR plus a detailed paragraph — covers both use cases.

| Option | Description | Selected |
|--------|-------------|----------|
| Auto-detect from transcript | Match transcript language | |
| Always English | Consistent but loses nuance for Chinese | |
| User-configurable language | Preferred language in Settings | ✓ |

**User's choice:** User-configurable language
**Notes:** User picks output language in Settings, regardless of meeting language.

---

## Markdown Output Format

| Option | Description | Selected |
|--------|-------------|----------|
| Summary → Actions → Decisions → Topics | Big picture first, details after | ✓ |
| Actions → Decisions → Summary → Topics | Actionable takeaways first | |
| You decide | Claude discretion | |

**User's choice:** Summary → Actions → Decisions → Topics (Recommended)

| Option | Description | Selected |
|--------|-------------|----------|
| Minimal frontmatter | date, duration, language, topics only | ✓ |
| Rich frontmatter | Include speaker_count, provider, model etc. | |

**User's choice:** Minimal frontmatter (Recommended)

| Option | Description | Selected |
|--------|-------------|----------|
| Timestamp-based | YYYY-MM-DD_HH-MM-SS_analysis.md | ✓ |
| Timestamp + topic slug | AI-generated slug, potential encoding issues | |

**User's choice:** Timestamp-based (Recommended)

---

## Analysis Trigger & UX Flow

| Option | Description | Selected |
|--------|-------------|----------|
| Auto after transcription | Same chain pattern as recording → transcription | ✓ |
| Manual trigger only | User must explicitly trigger | |
| Auto with toggle | Auto by default, toggle in Settings | |

**User's choice:** Auto after transcription (Recommended)

| Option | Description | Selected |
|--------|-------------|----------|
| Menu bar indicator | Sparkles icon + "Analyzing..." in dropdown | ✓ |
| Silent background | No visual feedback | |
| Notification on complete | macOS notification when done | |

**User's choice:** Menu bar indicator (Recommended)

| Option | Description | Selected |
|--------|-------------|----------|
| Menu bar error + retry | Error in dropdown with Retry button | ✓ |
| Silent fail, retry from dashboard | Less visible | |

**User's choice:** Menu bar error + retry (Recommended)

---

## In-App Interaction with Results

| Option | Description | Selected |
|--------|-------------|----------|
| Menu bar dropdown view | Scrollable view of sections in dropdown | ✓ |
| Popout window | Separate window for results | |
| Open in Finder only | Reveal file, no in-app view | |

**User's choice:** Menu bar dropdown view (Recommended)

| Option | Description | Selected |
|--------|-------------|----------|
| Per-section copy buttons | Copy individual sections to clipboard | ✓ |
| Copy entire analysis | One button for everything | |
| Both per-section and copy all | Most flexible but more UI | |

**User's choice:** Per-section copy buttons (Recommended)

---

## Claude's Discretion

- Exact JSON schema for AI response parsing
- AI prompt wording and system message design
- Markdown formatting details
- Retry strategy for analysis failures
- Very long transcript handling (context window limits)
- Error message wording
- Analysis state data model

## Deferred Ideas

None — discussion stayed within phase scope
