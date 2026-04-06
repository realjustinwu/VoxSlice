# Phase 2: Audio Capture Engine - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-06
**Phase:** 02-audio-capture-engine
**Areas discussed:** 音频格式与质量, 录制控制交互, 设备切换处理, 录制文件管理

---

## 音频格式与质量

| Option | Description | Selected |
|--------|-------------|----------|
| M4A (AAC) | Apple native compressed format, good quality/size ratio, STT compatible | ✓ |
| WAV (PCM) | Uncompressed, huge files (~600MB/hr), best STT compatibility but wasteful | |
| CAF | Apple Core Audio Format, flexible but poor cross-platform compatibility | |

**User's choice:** M4A (AAC)
**Notes:** Recommended for balance of file size, quality, and STT API compatibility

---

| Option | Description | Selected |
|--------|-------------|----------|
| 分开保存两个文件 | Mic and system audio as separate files with sync timestamps | ✓ |
| 合并为双声道文件 | Mic left, system right — single file but can't adjust per-stream volume | |
| 两者都保存 | Both separate and merged — flexible but storage-wasteful | |

**User's choice:** 分开保存两个文件
**Notes:** User asked about best approach for STT + speaker diarization. Separate files provide natural speaker separation (mic = local, system = remote), which is more reliable than algorithm-based diarization. Phase 3 can mix if needed.

---

| Option | Description | Selected |
|--------|-------------|----------|
| 44.1kHz / 128kbps | Full voice range, ~60MB/hr, all STT APIs support | ✓ |
| 48kHz / 192kbps | Higher quality, ~90MB/hr, overkill for voice | |
| 可配置 | User-selectable in Settings — adds complexity most won't use | |

**User's choice:** 44.1kHz / 128kbps

---

## 录制控制交互

| Option | Description | Selected |
|--------|-------------|----------|
| 单击切换开始/停止 | Click menu bar icon to toggle — simple, intuitive | ✓ |
| 下拉菜单明确按钮 | Separate start/stop buttons in dropdown — safer but extra step | |
| 浮动录制控制窗口 | Floating window with controls — good visibility but screen space | |

**User's choice:** 单击切换开始/停止

---

| Option | Description | Selected |
|--------|-------------|----------|
| 红色圆点指示器 | Red dot overlay on icon — clear, like macOS screen recording | ✓ |
| 切换 SF Symbol | Change to different icon — subtle, may be missed | |
| 动画脉冲效果 | Pulsing animation — complex to implement in NSStatusItem | |

**User's choice:** 红色圆点指示器

---

| Option | Description | Selected |
|--------|-------------|----------|
| 时长 + 停止按钮 | Show elapsed time and stop button in dropdown | ✓ |
| 时长 + 音量指示器 | Time + live audio level bars — visually rich but complex | |
| 只显示时长 | Time only — minimal but user may not find stop control | |

**User's choice:** 时长 + 停止按钮

---

| Option | Description | Selected |
|--------|-------------|----------|
| 系统通知 | Notification on stop with duration — informative, non-blocking | |
| 无提示 | Icon reverts only — minimal, user relies on visual state | ✓ |
| 弹出摘要窗口 | Popup with recording summary — informative but interrupts workflow | |

**User's choice:** 无提示（图标恢复即可）

---

## 设备切换处理

| Option | Description | Selected |
|--------|-------------|----------|
| 自动切换到新设备 | Seamless device switch, recording continues uninterrupted | ✓ |
| 暂停录制用户恢复 | Pause on disconnect, manual resume — safe but loses content | |
| 继续录制（可能有静默） | Keep recording with potential silence — file complete but has gaps | |

**User's choice:** 自动切换到新设备

---

| Option | Description | Selected |
|--------|-------------|----------|
| 静默切换 + 通知 | Auto-switch with system notification — user informed, no interruption | ✓ |
| 完全静默 | No notification at all — simplest but user unaware of quality change | |
| 弹窗确认 | Confirmation dialog — safe but disruptive during meetings | |

**User's choice:** 静默切换 + 系统通知

---

## 录制文件管理

| Option | Description | Selected |
|--------|-------------|----------|
| 时间戳命名 | YYYY-MM-DD_HH-MM-SS format — sortable, unambiguous | ✓ |
| 用户自定义名称 | Prompt user to name — flexible but interrupts workflow | |
| 时间戳 + 后续可重命名 | Timestamp default, rename later in dashboard — best of both worlds | |

**User's choice:** 时间戳命名

---

| Option | Description | Selected |
|--------|-------------|----------|
| 基础元数据 | Duration, sample rate, channels, start/end time, device info | ✓ |
| 基础 + 设备切换日志 | Basic + device change events — good for debugging but complex | |
| 不存元数据 | No metadata — simplest but Phase 3/5 must infer from files | |

**User's choice:** 基础元数据

---

| Option | Description | Selected |
|--------|-------------|----------|
| JSON 文件 | Companion .json file per recording — simple, Phase 3/5 can read directly | ✓ |
| 嵌入音频文件 metadata | M4A metadata tags — single file but needs audio parsing to read | |

**User's choice:** JSON 文件

---

| Option | Description | Selected |
|--------|-------------|----------|
| 静默检测 + 自动停止 | Monitor audio buffer, auto-stop after 30s silence | ✓ |
| 仅崩溃恢复 | Handle engine crashes only — can't detect silent recordings | |
| 无监控 | Rely on system stability — risk of invalid recordings | |

**User's choice:** 静默检测 + 自动停止

---

## Claude's Discretion

- ScreenCaptureKit stream configuration and audio format conversion
- AVAudioEngine tap installation and buffer management
- Audio device change detection implementation
- Silence detection algorithm and threshold
- File write error handling and recovery
- Memory management for long recordings

## Deferred Ideas

None — discussion stayed within phase scope
