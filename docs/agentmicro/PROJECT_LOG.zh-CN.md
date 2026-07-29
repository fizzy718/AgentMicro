# AgentMicro 项目改动日志

本文件记录 AgentMicro 自身的产品、架构和实现变化。它不替代上游 CodexBar 的根目录 `CHANGELOG.md`。

## 记录格式

每条记录包含：

- 日期。
- 类型：`product`、`architecture`、`implementation`、`research`、`docs` 或 `release`。
- 变化内容。
- 影响范围。
- 验证方式。
- 已知限制或后续工作。

仅记录实际发生的变化。计划中的需求进入 `ROADMAP` 或 `BACKLOG`。

## 2026-07-28

### `research`：完成现有项目能力盘点

变化：

- 分析 AgentMicro/CodexBar、abtop、cc-switch 和 token-monitor。
- 明确四者分别承担原生菜单栏、实时状态、会话恢复、用量与同步能力。
- 确认可视化工作目录为空。

影响：

- 建立 AgentMicro 的能力复用边界。
- 避免把 Electron、Tauri 或完整 Rust TUI 直接引入原生 V1。

验证：

- 检查各项目 README、构建清单、核心采集器、会话模型、菜单/托盘代码和测试结构。

限制：

- 本次为源码级分析，没有执行所有项目的完整测试套件。

### `product`：重新定义 V1

变化：

- 将 V1 从简单 `active/idle` 菜单改为 **Codex Task Pulse**。
- 定义 Thinking、Executing、Waiting、Rate limited、Unknown、Done。
- 将当前动作、项目、来源和点击返回任务纳入 V1。
- 明确 V1 为本地、只读、Codex-only。

影响：

- 现有 `AgentSession.State` 需要扩展或替换。
- 现有 30 秒扫描不足以满足 V1 状态时效。
- V1 不再沿用完整 CodexBar Provider 产品结构。

验证：

- 对照 CodexBar 当前扫描能力和 abtop Codex 状态实现确认可行性。

限制：

- 状态仍是本地观察结果，不是 Codex Desktop 权威事件。
- V1 不提供审批和任务控制。

### `architecture`：确定 V1 能力组合

变化：

- CodexBar 作为原生应用和任务发现底座。
- abtop 的 Codex 状态归约逻辑作为移植来源。
- cc-switch 作为标题解析和后续 Resume 参考。
- token-monitor 推迟到用量与多设备阶段。

影响：

- V1 保持纯 Swift 单进程。
- 不把 abtop、Electron 或 Tauri 作为运行时依赖。

验证：

- 形成 `CAPABILITY_MAP` 和 `V1_SPEC`。

### `docs`：建立产品文档体系

变化：

- 新增产品定义、V1 规格、路线图、能力地图、项目日志和未来需求池。
- 在项目指引中加入持续维护要求。

影响：

- 后续产品与实现变化必须有对应文档沉淀。

### `implementation`：完成 M0 菜单栏垂直切片

变化：

- 新增独立 `AgentMicro` SwiftPM 可执行入口和 AppKit 菜单栏生命周期。
- 复用 `LocalAgentSessionScanner` 发现本机任务，只保留 Codex 会话。
- 菜单显示 active/idle、来源、项目和最后活动时间，支持点击任务返回对应应用或窗口。
- 默认以项目名作为标题，避免直接展示可能敏感的线程标题。
- 有进程时每 5 秒、无进程时每 15 秒轮询；菜单打开时额外触发异步刷新。
- 新增独立 `AgentMicroTests`，覆盖过滤、排序、隐私标题回退和活动时间格式。
- 增加 `AGENTMICRO_BUILD_ONLY=1` 开发模式，隔离上游 CodexBar 的 Sparkle 二进制制品。

影响：

- AgentMicro 已具有从扫描到菜单展示再到任务跳转的可运行端到端骨架。
- 正常 CodexBar 构建保持原有产品、目标和依赖；独立模式只用于 AgentMicro 开发循环。
- AgentMicro 仍链接完整 `CodexBarCore`，后续可在状态引擎稳定后拆出更小的任务观察核心。

验证：

- `AGENTMICRO_BUILD_ONLY=1 swift test --disable-automatic-resolution --filter AgentMicroMenuModelTests`
- 4 个 Swift Testing 用例通过。
- SwiftFormat 对 4 个 AgentMicro Swift 文件检查通过；SwiftLint strict 为 0 violations。
- `AGENTMICRO_BUILD_ONLY=1 swift run --disable-automatic-resolution AgentMicro` 编译成功，进程持续运行后手动结束。

限制：

- M0 只有上游 `active/idle`，尚未实现 V1 六态和当前动作。
- M0 使用 5 秒活跃轮询，尚未达到 V1 的约 2 秒目标。
- 本次烟测确认进程生命周期，没有完成菜单逐项视觉与窗口定位验证。
- 上游快照缺少 `.github/workflows/ci.yml`，因此完整 `make check` 在 CI 路径门禁脚本处提前中止；已单独完成 AgentMicro 文件的格式、静态检查和聚焦测试。

### `implementation`：完成 M1 Task State Engine

变化：

- 新增增量 rollout 读取器，按文件保存 offset 和 reducer，支持半行续读、文件截断或轮转重置、异常 JSONL 跳过和单行大小保护。
- 将 Codex 事件归约为 Thinking、Executing、Waiting、Rate limited、Unknown、Done 六态。
- 配对新旧 schema 的 function、custom、patch、web、MCP 工具调用；长时间运行的 `exec_command` 通过后续 `write_stdin` / `wait` 轮询保持执行态，直到明确退出。
- 当前动作只保留工具名与最小参数预览，并清理控制字符、常见 token、Authorization、API key 和密码。
- 菜单改用 V1 状态优先级，展示状态、当前动作、来源和活动时间；活动进程轮询从 5 秒提高到 2 秒。
- 新增固定 rollout fixtures 和状态引擎测试，覆盖六态、时间戳乱序、文件边界、异常输入、工具配对、限流恢复与凭证脱敏。

影响：

- 菜单状态不再依赖上游粗粒度 `active/idle`。
- 读取成本随 rollout 新增内容增长，不需要每 2 秒重读完整文件。
- 近期但无法确认 owner 的 Desktop rollout 明确显示 `Unknown`，不会借 app-server PID 伪造精确归属。

验证：

- `AGENTMICRO_BUILD_ONLY=1 swift test --disable-automatic-resolution --filter AgentMicro`
- 15 个 Swift Testing 用例、2 个 suite 全部通过。
- SwiftFormat 对 AgentMicro 源码和测试检查通过；SwiftLint strict 为 0 violations。
- `AGENTMICRO_BUILD_ONLY=1 swift run --disable-automatic-resolution AgentMicro` 构建成功，进程持续运行后手动结束。
- `git diff --check` 通过，`Package.resolved` 未变化。

限制：

- `swift run` 启动的是无 `.app` 包的命令行产物，macOS 辅助功能应用列表无法识别，因此本次只完成运行生命周期烟测；菜单逐项视觉和点击验收进入 M2 打包工作。
- Desktop rollout 的精确 owner 与窗口关联仍需 M3 真实多任务场景验证。
- 上游快照仍缺少 `.github/workflows/ci.yml`，完整 `make check` 的既有阻塞未消除。

## 后续记录模板

```markdown
## YYYY-MM-DD

### `implementation`：变化标题

变化：

- ...

影响：

- ...

验证：

- `swift test --filter ...`

限制：

- ...
```
