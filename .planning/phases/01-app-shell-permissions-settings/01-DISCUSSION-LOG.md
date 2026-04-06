# Phase 1: App Shell + Permissions + Settings - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-06
**Phase:** 01-app-shell-permissions-settings
**Areas discussed:** STT Provider Strategy, AI Provider Configuration, Data Storage Architecture

---

## STT Provider Strategy

| Option | Description | Selected |
|--------|-------------|----------|
| 仅 OpenAI | v1 只支持 OpenAI Whisper API，后续加其他供应商 | |
| 多供应商抽象层 | 从第一天建 provider 协议，v1 实现 OpenAI + 本地 WhisperKit | |
| 多云供应商 | 支持 OpenAI + 其他云供应商（Google、AssemblyAI 等） | ✓ |

**User's choice:** 多云供应商
**Notes:** 还需要支持国内平台。用户认为如果接口兼容 OpenAI，可以一次适配大部分。差异大的单独考虑。

---

## AI Provider Configuration

| Option | Description | Selected |
|--------|-------------|----------|
| 共用一个 key | STT 和 AI 分析用同一个配置，简化体验 | |
| 分开配置 | STT 和 AI 分析分开配置，支持不同供应商 | ✓ |

**User's choice:** 分开配置
**Notes:** AI 分析供应商支持 OpenAI、Deepseek、智谱大模型、自定义端点。国内平台多提供 OpenAI 兼容接口。

---

## Data Storage Architecture

| Option | Description | Selected |
|--------|-------------|----------|
| 统一输出目录 | 所有数据在用户配置的文件夹下（如 ~/Documents/VoxSlice） | ✓ |
| 系统目录 + 输出目录分开 | 元数据在 ~/Library/Application Support，输出文件在用户目录 | |

**User's choice:** 统一输出目录
**Notes:** 默认 ~/Documents/VoxSlice，子目录分为 recordings/、transcripts/、analysis/、config/

---

## Claude's Discretion

- Exact SwiftUI view hierarchy
- Error handling patterns
- Keychain naming conventions
- Minimum macOS version target

## Deferred Ideas

- WhisperKit local model support — post-v1
- Domestic Chinese STT platforms — post-v1 unless OpenAI-compatible
- App update mechanism — Phase 6
- Import/export settings — not in v1
