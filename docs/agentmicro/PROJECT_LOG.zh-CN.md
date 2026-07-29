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

### `implementation`：完成 M2 菜单产品化

变化：

- 新增原生设置窗口，支持开机启动、仅项目名/任务标题/任务标题加项目名三种名称模式，以及最近完成任务开关。
- 默认只显示项目名以保护任务标题隐私；最近完成任务默认显示，继续使用状态引擎固定的 5 分钟保留窗口。
- 菜单将结束任务明确标记为 `Recently completed`，并按设置决定是否显示项目副标题或隐藏结束任务。
- 新增基于 `SMAppService.mainApp` 的开机启动管理，注册失败时恢复系统真实状态并在设置页显示错误。
- 新增 `AgentMicro.app` 本地打包和启动脚本、Makefile 入口、最小 `Info.plist`、菜单栏应用标记与 ad-hoc 签名验证。
- 新增 `--show-settings` 本地验收入口，只用于稳定打开设置窗口，不改变正常启动行为。

影响：

- AgentMicro 已能作为独立 `.app` 从 Finder 或 `make agentmicro-start` 启动，不再局限于 `swift run` 的命令行产物。
- 用户可以在不修改代码的情况下选择隐私与最近任务展示方式，并可选择随 macOS 登录启动。
- 本地开发包可直接使用；Developer ID 签名、公证、安装器和自动更新仍属于后续发布工程。

验证：

- `make test`：727 个 selections、61 个 groups 全部一次通过，0 失败、0 重试、0 超时。
- `AGENTMICRO_BUILD_ONLY=1 swift test --disable-automatic-resolution --filter AgentMicro`：AgentMicro 聚焦测试通过。
- SwiftFormat lint 和 SwiftLint strict 对 AgentMicro 源码与测试均通过。
- `./Scripts/package_agentmicro.sh debug`：`Info.plist` 校验、ad-hoc 签名和 `codesign --verify --deep --strict` 通过，产物为 Apple Silicon `AgentMicro.app`。
- `./Scripts/run_agentmicro.sh debug`：从应用包启动后进程持续运行。
- 通过 macOS UI 自动化实际打开并检查设置窗口，确认默认项目名模式、最近完成任务开启、开机启动开关和本地隐私说明可见。

限制：

- 当前 UI 自动化接口能读取设置窗口，但不暴露隐藏在系统菜单栏中的状态项；未使用坐标猜测点击。菜单内容由模型测试覆盖，真实点击和多任务状态联动进入 M3 人工场景验收。
- 开机启动的系统注册写操作未在自动测试中执行；注册分支由注入式单元测试覆盖，避免修改开发机登录项。
- 本地应用使用 ad-hoc 签名，不适合作为面向外部用户的正式分发包。
- 上游快照仍缺少 `.github/workflows/ci.yml`，完整 `make check` 的既有阻塞未消除。

### `implementation`：完成 M3 真实 Desktop/CLI 场景验证

变化：

- rollout reducer 新增明确 turn 生命周期：`task_started` / `user_message` 标记活跃，`task_complete` / `turn_aborted` 标记结束；没有独立 PID 的 Desktop 主任务可以显示 Thinking、Executing、Waiting 或 Done。
- 识别 guardian/subagent 元数据并在 AgentMicro V1 中排除，避免子任务的新文件覆盖主任务。
- 支持 ChatGPT.app 与 Codex.app 内置的 Codex CLI，且显式 `exec` 来源优先于 Desktop originator。
- 解析 `codex exec -C/--cd` 的显式工作目录并用它覆盖 launcher CWD，消除 rollout 与 PID 任务重复。
- 同一目录并发多个 CLI 时启用严格所有权策略：不按时间猜测 PID 与 rollout，只保留各自 file-only rollout 任务。
- 刷新策略调整为 Desktop 应用运行、任务工作中或任务有 PID 时 2 秒，其余 15 秒。
- 聚焦操作不主动触发 Accessibility 权限提示；已有权限时精确定位，否则降级为激活应用。
- 新增 `--diagnose-once` 与 `--diagnose-focus <id>` 开发验收入口，输出隐私安全的状态快照并复用菜单点击聚焦路径。

影响：

- Codex Desktop 主任务不再因缺少独立任务 PID 长期显示 `Unknown`。
- Desktop 主任务、真实 CLI 任务和历史结束任务可同时独立展示，不被 guardian rollout 或 launcher CWD 串线。
- 所有权证据不足时返回能力会诚实降级，不会为了可点击而关联到错误终端。

验证：

- 真实 Codex Desktop 主任务与只读 Codex CLI 任务同时运行；CLI 显示独立 Session ID、PID、`Executing` 和 `exec_command · sleep 12`，结束后转为 `Done` 且无重复 PID 记录。
- Desktop 当前主任务显示正确 rollout、Desktop 来源和执行态，guardian rollout 未进入顶层任务。
- 完成态单次 `--diagnose-once` 扫描约 388 毫秒，结合 2 秒轮询满足 3 秒状态时效目标。
- `--diagnose-focus <desktop-session-id>` 返回 `focused`，且使用与菜单点击相同的无提示聚焦路径。
- AgentMicro 聚焦测试 28 个 tests 全部通过；进程和 rollout 关联聚焦测试 19 个 tests、2 个 suites 全部通过。
- `make test`：729 个 selections、61 个 groups 首轮全部通过，0 失败、0 重试、0 超时。

限制：

- 当前 UI 自动化无法读取系统菜单栏状态项，且出于 Computer Use 安全边界不能检查 Codex/ChatGPT 窗口；没有使用坐标猜测。设置窗口已在 M2 视觉验收，M3 菜单行为由菜单模型测试、真实诊断快照和聚焦结果交叉验证。
- `ps` 的命令展示字符串不能可靠保留带空格 `-C/--cd` 路径的 argv 边界，已记录为 AM-008。
- 同一目录并发多个 CLI 时当前不提供精确终端窗口返回，已记录为 AM-009。
- 本地应用仍使用 ad-hoc 签名，正式发布需要 Developer ID、公证和发布渠道。

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
