# Phase 3: Transcription Pipeline - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-07
**Phase:** 03-transcription-pipeline
**Areas discussed:** whisperX 集成方式, 转录输出格式, 处理流程

---

## whisperX 集成方式

### 调用方式

| Option | Description | Selected |
|--------|-------------|----------|
| CLI 子进程 | app 通过 Process 调用 whisperx 命令行，解析 JSON 输出 | |
| 本地 HTTP 服务 | FastAPI 包装 whisperX，app 通过 HTTP API 调用 | ✓ |
| Python 脚本桥接 | 内嵌 Python 脚本调用 whisperX API，通过 Process 执行 | |

**User's choice:** 本地 HTTP 服务
**Notes:** 更稳定，支持进度查询，用户自行安装管理 whisperX 服务

### 服务生命周期

| Option | Description | Selected |
|--------|-------------|----------|
| 随 app 自动启停 | app 启动时自动启动 whisperX 服务，退出时停止 | |
| 手动管理 | 用户在 Settings 配置服务地址，自行启停服务 | ✓ |

**User's choice:** 手动管理
**Notes:** 用户配置 host:port（如 http://localhost:8000），app 只负责连接

---

## 转录输出格式

| Option | Description | Selected |
|--------|-------------|----------|
| 原始 JSON | 直接存储 whisperX 的原始输出 | |
| 标准化 JSON | 转换为 app 自有的标准化 JSON 格式 | ✓ |
| JSON + Markdown 双格式 | 同时存储原始 JSON 和可读 Markdown | |

**User's choice:** 标准化 JSON
**Notes:** 定义自己的数据模型，不依赖 whisperX 输出结构。包含 segments（文本+时间戳+说话人）、language、duration、speakers。

---

## 处理流程

### 触发方式

| Option | Description | Selected |
|--------|-------------|----------|
| 录音后自动转录 | 录音结束后自动开始转录 | ✓ |
| 手动触发 | 用户从录音列表手动点击转录 | |
| 可配置（默认自动） | 默认自动，用户可在 Settings 关闭 | |

**User's choice:** 录音后自动转录

### 长时间录音分割

| Option | Description | Selected |
|--------|-------------|----------|
| 服务端处理 | whisperX 服务内部处理分割 | |
| 客户端预分割 | app 端根据文件大小预分割，逐个发送再合并 | ✓ |

**User's choice:** 客户端预分割
**Notes:** app 端负责分割长音频为多个 chunk，发送转录后合并结果

### 进度反馈

| Option | Description | Selected |
|--------|-------------|----------|
| 菜单栏状态指示 | 菜单栏显示转录中状态 + 进度百分比 | ✓ |
| 通知推送 | 通过 macOS 通知中心推送转录完成通知 | |

**User's choice:** 菜单栏状态指示

---

## Claude's Discretion

- 云端 STT 提供商支持 — 用户未选择讨论此区域，Claude 决定是否保留 Phase 1 已建的多提供商框架
- whisperX HTTP API 端点设计和请求/响应格式
- 客户端预分割的 chunk 大小和时间策略
- 双流音频合并 vs 分开转录的具体实现方式
- 转录失败的重试策略
- 标准化 JSON 的精确 schema
- Settings 中 whisperX 配置 UI 细节

## Deferred Ideas

None — discussion stayed within phase scope
