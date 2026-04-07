# Phase 3: Transcription Pipeline - Context

**Gathered:** 2026-04-07
**Status:** Ready for planning

<domain>
## Phase Boundary

Multi-provider STT transcription for recorded dual-stream audio files, with speaker diarization, timestamps, and long-recording chunking. Delivers a transcription service that connects to a user-managed whisperX HTTP service, processes recordings after capture, and outputs standardized JSON transcripts to the transcripts/ directory. Does NOT include AI analysis, Markdown output, or dashboard UI — those are separate phases.

</domain>

<decisions>
## Implementation Decisions

### whisperX 集成方式
- **D-01:** 使用本地 HTTP 服务方式调用 whisperX — 用户自行安装和管理 whisperX 服务（FastAPI），app 通过 HTTP API 通信
- **D-02:** 用户在 Settings 中配置 whisperX 服务地址（host:port，如 `http://localhost:8000`）— 与现有 Provider Settings 模式一致
- **D-03:** App 不负责启动/停止 whisperX 服务 — 用户手动管理服务生命周期；如果服务不可用，app 显示连接错误提示

### 转录引擎
- **D-04:** whisperX 作为主要转录引擎 — 支持多语言自动检测（中文/英文/混合），内置 pyannote 说话人分离
- **D-05:** whisperX 通过 HTTP API 接收音频文件，返回带时间戳和说话人标签的转录结果
- **D-06:** 仍然保留云端 STT 提供商支持框架（OpenAI/Google/AssemblyAI）— 已在 Phase 1 建立，作为备选方案，Claude's discretion 决定具体实现优先级

### 转录输出格式
- **D-07:** 转录结果存储为 app 标准化 JSON 格式 — 不依赖 whisperX 的原始输出结构，定义自己的数据模型
- **D-08:** 标准化 JSON 包含字段：segments（每段文本 + 起止时间戳 + 说话人标签）、language（检测到的语言）、duration（总时长）、speakers（说话人列表）
- **D-09:** 转录文件命名与录音文件对应：`YYYY-MM-DD_HH-MM-SS_transcript.json`，存储在 `transcripts/` 目录

### 处理流程
- **D-10:** 录音结束后自动触发转录 — RecordingCoordinator 在 recordingDidStop 后自动启动 TranscriptionService
- **D-11:** 长时间录音（60+ 分钟）采用客户端预分割策略 — app 端根据文件大小/时长将音频分割为多个 chunk，逐个发送转录，最后合并结果
- **D-12:** 转录进度通过菜单栏状态指示显示 — 菜单栏图标变为转录状态（如文本图标），下拉菜单显示进度百分比
- **D-13:** 双流音频合并后发送给 whisperX — 将 mic 和 system 两个 M4A 文件合并为一个文件再转录，简化处理流程；或分别转录再合并（Claude's discretion）

### Claude's Discretion
- whisperX HTTP API 的具体端点设计和请求/响应格式
- 客户端预分割的 chunk 大小和时间策略
- 双流音频合并 vs 分开转录的具体实现方式
- 转录失败的重试策略
- 标准化 JSON 的精确 schema 定义
- Settings 中 whisperX 配置的 UI 细节
- 转录状态的数据模型和状态机

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Prior Phase Context
- `.planning/phases/01-app-shell-permissions-settings/01-CONTEXT.md` — STT 提供商框架（D-01/D-02）、Settings UI 模式（D-21~D-25）、Keychain 存储模式
- `.planning/phases/02-audio-capture-engine/02-CONTEXT.md` — 双流音频格式（D-01/D-02）、录音文件命名（D-10）、元数据 JSON（D-11）

### Project Context
- `.planning/PROJECT.md` — Vision、约束（macOS only、多语言支持、BYOK 模式）
- `.planning/REQUIREMENTS.md` — TRSC-01~TRSC-05 是 Phase 3 需求
- `.planning/ROADMAP.md` — Phase 3 goal、success criteria、依赖 Phase 2

### Research
- `.planning/research/STACK.md` — OpenAI gpt-4o-transcribe 模型推荐
- `.planning/research/ARCHITECTURE.md` — 组件边界和数据流

### Codebase Integration Points
- `VoxSlice/Models/Provider.swift` — STTProvider enum，可能需要添加 whisperX/local 类型
- `VoxSlice/Services/StorageService.swift` — `transcripts/` 目录管理
- `VoxSlice/Services/RecordingCoordinator.swift` — 录音生命周期，auto-transcribe 触发点
- `VoxSlice/Models/RecordingInfo.swift` — 录音元数据模型
- `VoxSlice/Utils/Constants.swift` — AppConstants，需要添加转录相关常量
- `VoxSlice/Views/Settings/ProviderSettingsView.swift` — Settings UI 模式参考
- `VoxSlice/Views/MenuBarView.swift` — 菜单栏 UI，需要添加转录状态

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **STTProvider enum**: 已定义 openAI、google、assemblyAI 三个提供商，每个有 displayName、description、defaultEndpoint、keychainAccount — 可扩展添加 whisperX 类型
- **StorageService**: `transcripts/` 目录已创建，`directoryURL(for:)` 方法可获取子目录路径
- **RecordingCoordinator**: 完整的录音生命周期管理，`recordingDidStop` 通知是自动转录的触发点
- **RecordingInfo**: 包含 micFilePath、systemFilePath、duration 等字段 — 转录服务需要这些路径和元数据
- **ProviderValidationService**: 提供商验证模式（validate → validating → valid/invalid）可复用于 whisperX 连接验证

### Established Patterns
- `@Observable` class 用于服务（不是 Combine/ObservableObject）
- Services 放在 `VoxSlice/Services/` 目录
- Models 放在 `VoxSlice/Models/` 目录
- AppConstants 集中管理常量
- Combine publishers + NotificationCenter 用于跨服务通信
- Settings 使用 TabView 分 tab 管理不同配置

### Integration Points
- RecordingCoordinator.recordingDidStop → 触发 TranscriptionService 开始转录
- MenuBarView → 需要显示转录进度状态
- SettingsView → 需要添加 whisperX 服务地址配置
- StorageService.transcripts/ → 转录结果存储位置
- RecordingInfo.micFilePath / systemFilePath → 转录服务的输入文件路径

</code_context>

<specifics>
## Specific Ideas

- whisperX 通过 pyannote 实现说话人分离，输出 Speaker 1、Speaker 2 等标签 — 满足 TRSC-05 需求
- 双流录音（mic=本地说话人，system=远程）为说话人识别提供了天然线索，但 whisperX 的 pyannote 会做更精确的声纹级别分离
- 用户偏好自己管理 whisperX 服务 — app 只需连接能力，不需要内置 Python 环境

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 03-transcription-pipeline*
*Context gathered: 2026-04-07*
