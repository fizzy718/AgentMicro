# AgentMicro V1 规格

## 版本名称

**AgentMicro V1：Codex Task Pulse**

## 版本目标

V1 是本地、只读、Codex-only 的 macOS 菜单栏任务观察器。

它需要让用户在一次点击内看到：

- 当前任务数量。
- 任务标题或项目名。
- Desktop、CLI 或 IDE 来源。
- 任务状态。
- 当前动作。
- 最后活动时间或运行时长。
- 返回任务的入口。

## 支持范围

### 必须支持

- macOS 14 及以上。
- Codex Desktop。
- Codex CLI。
- 本机任务。
- Apple Silicon 首先完成和验证。

### 尽力支持

- Codex IDE 来源识别。
- Intel Mac 构建。
- 精确定位 Codex Desktop 中的具体任务窗口。

尽力支持项不能降低必须支持项的交付质量。

## 任务模型

一个任务由一个 Codex thread/rollout 表示。建议的视图模型字段：

```text
id
title
projectName
source
state
currentAction
pid
startedAt
lastActivityAt
transcriptPath
focusTarget
```

`transcriptPath` 和原始进程信息只用于本地关联，不进入菜单，不上传。

## 状态模型

| 状态 | 判断依据 | 用户文案 |
|---|---|---|
| `thinking` | 用户请求之后尚未出现对应模型回复，且任务仍活跃 | Thinking |
| `executing` | 存在未结束的工具调用或可确认的活跃子进程 | Executing |
| `waiting` | 任务进程仍存在，但没有待完成的模型或工具事件 | Waiting |
| `rateLimited` | 会话中存在明确的限流事件 | Rate limited |
| `unknown` | 找到最近会话，但不能可靠确认进程或事件归属 | Unknown |
| `done` | 已确认原任务进程结束，且仍处于最近任务保留窗口 | Done |

### V1 不提供的状态

- `Waiting for approval`
- `Failed`
- `Succeeded`

这些状态只有在本地证据足够可靠后才能加入。`waiting` 不能被描述为“需要用户处理”，也不能直接触发注意力通知。

## 状态归约规则

- 进程存在不是 `thinking` 的充分条件。
- rollout 文件最近更新不是 `executing` 的充分条件。
- 未配对的用户请求可以形成 `thinking`。
- 未配对的工具调用可以形成 `executing`。
- 工具输出到达后必须结束对应执行状态。
- 长时间运行工具要结合子进程存活情况，避免仅凭文件静默误判为 `waiting`。
- 找不到可靠 owner 的最近 Desktop rollout 使用 `unknown`，不能伪造 PID 归属。
- Codex Desktop 的 app-server 可能同时持有多个 rollout，不能按 app-server PID 合并成一个任务。

## 标题解析顺序

1. Codex 显式线程标题。
2. `session_index.jsonl` 的线程名称。
3. 首个有效用户请求的安全预览。
4. 项目目录名称。
5. 缩短后的 Session ID。

必须忽略 IDE 环境注入、`AGENTS.md` 内容、系统上下文和 subagent 元数据等非用户标题。

默认菜单使用项目名。用户启用任务标题后才显示可能包含敏感文本的标题。

## 当前动作

V1 可以显示经过清理的工具名称和最小参数预览，例如：

```text
exec_command · npm test
apply_patch · collector.swift
read · Package.swift
web search
```

不得显示：

- 命令完整输出。
- 文件内容。
- 工具返回内容。
- 完整 Prompt。
- 环境变量和凭证。

## 菜单结构

```text
AgentMicro                         2 active

◉ 修复同步状态
  Executing · npm test · token-monitor · 18s

● 重构任务扫描器
  Thinking · Codex App · AgentMicro · 7s

○ 分析菜单栏方案
  Waiting · Codex CLI · abtop · 3m

◌ 最近完成：修复额度展示
  Done · token-monitor · 2m ago

────────────────────────
Refresh
Settings…
Quit
```

排序规则：

1. `thinking` 和 `executing`。
2. `rateLimited`。
3. `waiting`。
4. `unknown`。
5. `done`。
6. 同一组内按最近活动时间倒序。

## 菜单栏图标

- 使用 macOS template image，不依赖颜色表达语义。
- 无任务时显示静态基础图标。
- 有活动任务时可显示活动任务数。
- V1 不要求持续动画，避免额外能耗和视觉干扰。
- 图标不能仅凭 `waiting` 状态显示紧急提示。

## 返回任务

- CLI：尽力定位并激活对应终端窗口。
- Desktop：优先匹配窗口；失败时至少激活 Codex App。
- IDE：能够确认来源时激活对应编辑器。
- 精确窗口定位需要 Accessibility 权限时，应说明原因并提供只激活应用的降级路径。

## 刷新策略

- 菜单始终先使用缓存状态立即打开。
- 打开菜单时触发一次异步刷新。
- 有活跃 Codex 进程时，目标刷新间隔约 2 秒。
- 无活跃任务时，降低到 15–30 秒。
- rollout 采用增量读取，保存文件 offset，并处理半行、截断和轮转。
- 进程、`lsof` 和目录扫描分频执行，避免每 2 秒完成一次全量扫描。

## 设置

V1 设置页只包含：

- 开机启动。
- 任务名称显示方式：
  - 仅项目名，默认。
  - 任务标题。
  - 任务标题 + 项目名。
- 是否显示最近结束的任务。

最近结束任务默认显示，保留时间固定为 5 分钟；V1 不增加高级轮询设置。

## 明确不做

- Claude、OpenCode 或其他 Agent。
- Token、成本和账户额度。
- 历史会话全文浏览。
- Resume、Fork、删除和归档。
- 审批、停止、继续或修改任务。
- Provider 切换和本地代理。
- 远程设备和云同步。
- 手机端、硬件和语音。
- 基于 `waiting` 的注意力通知。

## 技术方案

V1 保持单进程原生 Swift：

- 复用 CodexBar 的菜单栏生命周期、设置和窗口唤起。
- 复用现有 `LocalAgentSessionScanner` 的进程、CWD、rollout 和标题发现能力。
- 将 abtop 的 Codex 状态归约逻辑移植为独立 Swift 模块。
- 吸收 cc-switch 在 Codex 标题和会话格式容错方面的实现经验。
- 不运行 Electron、Tauri 或外部 abtop 二进制。

建议模块：

```text
CodexTaskScanner
CodexRolloutTailer
CodexTaskStateReducer
CodexTaskStore
AgentMicroMenuDescriptor
SessionWindowFocuser
```

## 验收标准

- 新任务启动后 3 秒内出现在菜单。
- 有新会话事件时，状态在 3 秒内更新。
- 多个 Desktop 与 CLI 任务不重复、不串线。
- 工具输出结束后不继续显示 `executing`。
- 任务进程退出后显示 `done`，5 分钟后移除。
- 菜单使用缓存即时打开，不等待扫描完成。
- CLI 任务点击后能唤起对应终端或明确降级。
- 断网时所有 V1 功能正常。
- 不出现 Keychain 或 Full Disk Access 权限提示。
- 解析器使用固定 fixtures 覆盖每种状态及异常 JSONL。
