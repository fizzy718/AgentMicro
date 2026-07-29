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

## 2026-07-29

### `implementation`：采用 Codex Micro 五态与八槽虚正方形

变化：

- 状态模型直接采用 Codex Micro 官网五态与色值：Idle 白、Unread chat 绿、Thinking 蓝、Needs approval or answer 橙、Error 红；无法证明状态时保留无填充的 Unknown 回退。
- Thinking 同时覆盖模型思考和工具运行，具体工具动作继续显示在菜单副标题；普通静默归为 Idle，完成任务归为 Unread chat，明确额度耗尽归为 Error。
- 未完成的 `request_user_input`，以及明确携带 `sandbox_permissions = require_escalated` 的工具调用归为 Needs approval or answer；不会用静默状态猜测。
- 菜单栏图标改为由 8 个小正方形组成的 3×3 外围虚正方形，按最近活动时间跟踪最近 8 个任务。
- 任一任务工作时，高亮每 160 毫秒顺时针移动一格；无工作任务或系统启用减少动态效果时保持静止。
- 菜单最多显示相同顺序的最近 8 个任务；每一行左侧显示同一个八槽虚正方形，并点亮该任务对应的槽位，项目归属始终可见。

影响：

- 菜单栏、任务排序和菜单行共享同一套八槽身份，用户可以从菜单栏中的方块位置直接对应到具体任务。
- 状态颜色不再使用 AgentMicro 自定义映射，与 Codex Micro 产品页展示保持一致。
- 工具执行不会产生独立颜色状态，避免 Thinking/Executing 在菜单栏中造成颜色跳变。

验证：

- `AGENTMICRO_BUILD_ONLY=1 swift test --disable-automatic-resolution --filter AgentMicro`：32 个 tests、5 个 suites 全部通过。
- `make agentmicro-package`：debug 应用编译、Info.plist 校验与签名全部成功。
- 新增五种官网颜色、八槽顺时针布局、最近 8 任务上限和统一排序测试。

限制：

- 批准或回答状态依赖 rollout 中明确的工具调用；旧版本 Codex 若不记录这些调用，会回退到 Thinking 或 Unknown。
- `unknown` 为状态诚实所需的无颜色诊断回退，不属于 Codex Micro 五态。
- 菜单栏动效仍需在新打包的 AgentMicro.app 中进行最终视觉验收。

### `implementation`：实时同步与单方块任务行

变化：

- 增加 Codex 会话变化监听：监听 sessions 日期目录和已发现 rollout 文件，事件发生后 200ms 防抖刷新；刷新中的新事件排队补扫。
- 空闲兜底轮询从 15 秒缩短为 5 秒，避免目录事件被系统合并或遗漏后长期显示空列表。
- rollout 首行时间戳进入 `startedAt`，菜单显示任务累计运行时长，不再把最后活动时间显示成“几秒前”。
- 任务副标题只保留项目名与运行时长，移除状态、当前动作及 Codex App/CLI 来源。
- 每行左侧改为一个完整状态方块；Thinking 方块以 0.85 秒周期呼吸。
- Unread 只通过任务行最右侧的绿色强调点表达，左侧方块使用 Idle 外观，副标题不再出现 Unread chat。
- 从 AgentMicro 点击任务会清除该会话的本地未读点；会话开始新 turn 后可再次进入未读。

影响：

- 新建任务和 rollout 增量写入能近实时进入菜单；5 秒轮询仅作为可靠性兜底。
- 任务行更安静，状态、来源和活动时间不会挤占项目与运行时长信息。
- 菜单栏仍保留八槽虚正方形；单方块仅用于菜单中的具体任务行。

验证：

- `AGENTMICRO_BUILD_ONLY=1 swift test --disable-automatic-resolution --filter AgentMicro`：33 个 tests、5 个 suites 全部通过。
- `swift test --disable-automatic-resolution --filter CodexSessionRolloutTests`：13 个 tests、1 个 suite 全部通过。
- 两次真实诊断扫描当前运行任务均低于 0.5 秒，并正确识别项目、状态和 rollout。
- `make agentmicro-start`：最终 debug 应用完成编译、Info.plist 校验、签名、打包并成功常驻运行。

限制：

- 文件系统监听以本机 sessions 目录和已发现 rollout 为边界；CODEX_HOME 指向网络文件系统时主要依赖 5 秒兜底轮询。

### `implementation`：修复父任务发现、未读颜色与自动审批误判

变化：

- AgentMicro 继续排除普通 subagent，但允许 guardian 作为父任务发现线索；通过父任务 ID 和 Codex 只读线程索引找回原始父 rollout，不把 guardian 单独显示成任务。
- 文件任务扫描窗口和完成态保留窗口统一从 30 分钟/5 分钟延长为 24 小时，避免待查看任务过早消失。
- 已读状态改为按“会话 + 最后活动时间”持久化；重启 AgentMicro 后仍保持已读，同一会话产生更新的完成事件时会重新进入未读。
- 未读任务左侧方块改用 Codex Micro 官方绿色，并保留最右侧绿色强调点；点击查看后方块恢复 Idle 白色。
- 橙色只由明确的 `request_user_input` 触发；`require_escalated` 不再直接变橙，因为该请求可能由 Codex guardian 自动处理。
- turn 从用户请求开始直到明确的 `task_complete` / `turn_aborted` 都保持 Thinking；工具调用之间不再短暂闪回 Idle 白色。
- Desktop 任务点击改用 Codex 官方 `codex://threads/<session-id>` 深链直接导航到对应任务；窗口标题匹配只作为降级路径。
- 大型长会话首次观察只归约末尾 4 MiB 的完整 JSONL 行，随后按 offset 增量读取，避免两个长期运行任务使首次菜单同步阻塞数秒。

影响：

- 运行多天但仍在追加事件的 Desktop 父任务可通过近期 guardian 重新进入扫描范围，并由真实父 rollout 判断状态。
- “待查看”不会在 5 分钟后消失，颜色也与 Codex Micro 五态语义一致。
- 自动审批期间保持 Thinking 蓝色，不再短暂伪装成需要用户操作的橙色。

验证：

- AgentMicro 状态、菜单、设置持久化及刷新策略聚焦测试。
- Codex guardian/父 rollout、线程索引和 rollout 扫描聚焦测试。
- 使用真实 Template 父任务执行 `--diagnose-once`，确认显示父任务而非 guardian。

限制：

- 完成任务当前最多保留 24 小时；这是菜单“最近 8 个任务”而非永久收件箱。

### `implementation`：校正菜单 hover、单 turn 时长与八任务顺序

变化：

- 自定义任务行进入 hover 时主动清除同一菜单内其他任务行的 hover，避免鼠标扫过后多行同时残留蓝色选中背景。
- rollout reducer 记录当前 turn 的开始时间和最后状态变化时间；菜单时长不再使用整个会话的创建时间。
- Thinking 状态的时长持续增长；停止、完成、等待输入和错误状态冻结在最后事件时间。
- 菜单与菜单栏八槽统一按最后状态变化时间排序；没有改变状态的 token、日志和工具事件不再挤占最近 8 个位置。

影响：

- 长期会话中的新任务显示本轮实际运行分钟数，不再出现 42h、70h 之类的会话总年龄。
- 鼠标一次只高亮一行，八槽顺序表达状态变化而不是事件噪声。

验证：

- 增加运行/停止时长、状态变化排序和 turn 生命周期时间戳测试。
- 重新打包后使用真实多任务菜单验证。

### `implementation`：缩短完成态同步并消除已查看竞态

变化：

- 将已知任务的 rollout 尾部对账从完整任务发现中拆出；菜单打开、任务点击和文件变化
  可以直接增量读取当前 rollout，不再等待进程、SQLite 与目录扫描结束。
- 菜单打开和任务点击后增加三次有界快速对账，覆盖最终回复与 `task_complete` 分步写入
  造成的短暂蓝色残留。
- 用户在 Thinking 状态点击进入任务时，只为当前 turn 保存 5 秒“正在查看”标记；如果
  同一 turn 的完成事件随后到达，直接持久化为已读，不会先变绿或继续显示蓝色。
- “正在查看”标记以 turn 开始时间隔离，下一 turn 或超出窗口的完成事件仍正常显示未读。

影响：

- 已知任务完成后主要受 rollout 写入和 200ms 文件防抖影响，不再叠加约 1 秒的完整扫描。
- 用户已经进入刚完成的任务时，AgentMicro 不会因完成事件稍晚落盘而显示错误的未读状态。

验证：

- `AGENTMICRO_BUILD_ONLY=1 swift test --disable-automatic-resolution --filter AgentMicro`：
  44 个 tests、5 个 suites 全部通过。
- 新增快速对账时序、同一 turn 自动已读、跨 turn 与超时不误吞未读的聚焦测试。
- 同步控制器与 turn 查看跟踪器通过 SwiftLint strict 聚焦检查，0 violations。
- 最终应用完成打包、ad-hoc 签名验证并安装到 `/Applications/AgentMicro.app`；安装包与
  本地产物 SHA-256 一致，且只运行一个安装版进程。

限制：

- AgentMicro 只能确认从自身菜单点击进入的查看动作；用户直接在 Codex App 内切换会话时，
  当前没有官方只读事件可用于可靠判断“已查看”。
- 完整 `make check` 仍被上游快照缺少 `.github/workflows/ci.yml` 阻塞；失败发生在
  CI 路径门禁前，AgentMicro 聚焦测试与新增同步代码的 strict lint 已独立通过。

### `docs`：将产品沉淀设为交付前必做动作

变化：

- 在项目唯一代理指引 `AGENTS.md` 中加入 AgentMicro 产品文档收尾清单。
- 要求每次产品或行为任务结束前逐项检查 `PRODUCT`、`V1_SPEC`、`README`、`ROADMAP`、
  `BACKLOG`、`CAPABILITY_MAP` 和 `PROJECT_LOG`，不能只更新规格与实现日志。
- 要求跨文档搜索已经失效的状态名、时间、颜色、UI 字段、保留窗口、里程碑和产品承诺。
- 要求最终交付明确列出已更新的产品文档和仍存在的文档缺口。

影响：

- 后续代理任务会把产品事实同步作为完成条件，降低实现已经变化而产品定义、路线图或
  总览仍停留在旧设计的概率。
- 历史项目日志继续保留当时事实；当前设计统一由产品定义、规格、总览、路线图、需求池
  和能力地图承载。

验证：

- 人工核对 `AGENTS.md` 清单覆盖 AgentMicro 全部七类产品事实文档。
- `git diff --check` 通过。

限制：

- 指引能约束后续编码代理的工作流，但仍需每次交付实际执行跨文档一致性检查。

### `implementation`：改为六任务双排圆角矩形图标

变化：

- 菜单和菜单栏共同跟踪的最近状态变化任务数从 8 个改为 6 个。
- 菜单栏图标改成 2×3 布局：上面 3 个、下面 3 个无边框圆角矩形。
- 菜单栏与任务行改用同一个状态颜色函数和满透明度静态填充；任务行左侧也取消外边框，
  改为同色圆角矩形。Unknown 和空槽使用低强调度中性色。
- 工作状态动效不再生成白色高亮并绕圈；六个圆角矩形保留各自任务颜色，以每块 9 帧、
  每帧 90ms 的节奏依次降低再恢复透明度，形成逐个呼吸。
- 系统启用“减少动态效果”时继续保持静止。

影响：

- 菜单栏图标与展开菜单使用同一组六个任务、同一排序和同一颜色来源，不再因 0.82
  透明度及白色描边造成上下颜色不一致。
- 2×3 图形比原 3×3 外围八槽更紧凑，任务身份顺序改为从左到右、从上到下。

验证：

- `AGENTMICRO_BUILD_ONLY=1 swift test --disable-automatic-resolution --filter AgentMicro`：
  45 个 tests、5 个 suites 全部通过。
- 新增六任务上限、2×3 槽位顺序和逐块呼吸透明度测试。
- `AgentMicroAppDelegate.swift`、`AgentMicroStatusIcon.swift` 和
  `AgentMicroTaskMenuItemView.swift` 通过 SwiftLint strict，0 violations。
- 完成 debug 应用打包、ad-hoc 签名验证并安装到 `/Applications/AgentMicro.app`；
  安装版与本地产物 SHA-256 一致，且只运行一个安装版进程。
- 同步校正 `PRODUCT`、`V1_SPEC`、`README`、`ROADMAP` 和 `BACKLOG`；跨文档搜索未再
  发现非历史文档中的旧八任务、虚正方形或旧六态产品承诺。

限制：

- Computer Use 无法取得仅有菜单栏状态项的 AgentMicro AX 窗口；捕获的其他应用窗口
  也没有包含 macOS 菜单栏，因此没有把坐标猜测或不可见截图当作实机视觉验收。
- 完整 `make check` 仍被上游快照缺少 `.github/workflows/ci.yml` 阻塞；失败发生在
  CI 路径门禁，AgentMicro 全部聚焦测试及实际图标实现的 strict lint 已独立通过。

### `fix`：补齐 Computer Use 批准态并改为环形呼吸

变化：

- 状态归约器继续用未完成的 `request_user_input` 识别明确问答；同时解析
  `mcp__node_repl` 调用中的 `sky.*` 和目标应用。
- Codex 宿主没有把跨应用授权弹窗单独写入 rollout。为覆盖“允许 ChatGPT 使用某应用”
  这类实际批准请求，同一任务第一次访问某个 Computer Use 目标且调用尚未返回时，
  保守显示 Needs approval or answer；后续访问仍显示 Thinking，避免普通自动化步骤
  反复闪橙。
- `sandbox_permissions = require_escalated` 仍不直接触发橙色，因为 guardian 可能自动
  处理该审批。
- 菜单栏六块的任务映射和呼吸顺序改为上排左到右、下排右到左，形成连续环形。

影响：

- 截图中的跨应用高风险授权等待会及时使用 Codex Micro 的橙色，而普通 Node 脚本与
  同一应用的后续 Computer Use 步骤不会被误判为持续待批准。
- 六块动画在右上角后转到右下角，再沿下排回到左侧，不再两排同向扫描。

验证：

- 新增真实 `mcp__node_repl` / `sky.get_app_state` 事件形状测试，覆盖首次访问橙色、
  同一应用后续访问蓝色、普通 JavaScript 蓝色以及 `require_escalated` 蓝色。
- 更新槽位顺序测试，固定上排左到右、下排右到左的环形路径。
- `AGENTMICRO_BUILD_ONLY=1 swift test --disable-automatic-resolution --filter AgentMicro`：
  47 个 tests、5 个 suites 全部通过。
- 本次生产 Swift 文件通过 SwiftLint strict，0 violations。
- 完成 debug 应用打包、ad-hoc 签名验证并安装到 `/Applications/AgentMicro.app`；
  安装版与本地产物 SHA-256 一致，且只运行一个安装版进程。

限制：

- rollout 没有宿主授权弹窗的独立开始事件，因此首次 Computer Use 目标采用保守提示；
  若 Codex 后续提供明确授权事件，应改为直接消费该事件。
- 完整 `make check` 仍被上游快照缺少 `.github/workflows/ci.yml` 阻塞；此前的 locale、
  parser hash、package product、strip、signing、Info.plist、dSYM 和 Sparkle 路径门禁均通过。

### `refine`：工作任务置顶并调整菜单层级

变化：

- 菜单和菜单栏共享的六任务排序改为两级：`thinking` 任务优先，工作中与非工作中两组
  内部继续按 `stateChangedAt` 倒序；普通输出仍不会改变组内顺序。
- 菜单顶部标题改用自定义静态视图，以 13pt semibold 和正常 `labelColor` 显示，不再
  继承禁用菜单项的低对比度灰色。
- 任务标题从 14pt 缩小到 13pt，副标题继续使用 11pt。
- 展开菜单从 340pt 收窄到 CodexBar `menuCardBaseWidth` 对应的 310pt，顶部标题与任务行
  共用同一宽度，长文本继续尾部截断。
- 菜单栏环形呼吸由每帧 90ms 加快到 70ms，六块完整轮动约由 4.86 秒缩短到 3.78 秒；
  任务行左侧方块的 0.85 秒呼吸节奏不变。

影响：

- 即使刚完成的未读任务状态变化更晚，仍在运行且时长持续增长的任务也会保持在列表
  上方；六任务截取和菜单栏槽位同步采用同一排序结果。
- 顶部产品名更清晰，展开菜单更接近 CodexBar 的紧凑宽度，任务列表的信息密度略有
  提高，菜单栏运行反馈更敏捷。

验证：

- 菜单模型测试覆盖“较旧的工作任务仍排在较新的已完成任务之前”，并保留同组按状态
  变化时间排序的断言。
- AppKit 模型测试固定 310pt 菜单宽度、顶部标题颜色、13pt 标题字号和 70ms 菜单栏
  动画帧间隔。
- `AGENTMICRO_BUILD_ONLY=1 swift test --disable-automatic-resolution --filter AgentMicro`：
  48 个 tests、5 个 suites 全部通过。
- 本次四个生产 Swift 文件通过 SwiftLint strict，0 violations；`git diff --check` 通过。
- 完成 debug 应用打包、ad-hoc 签名验证并安装到 `/Applications/AgentMicro.app`；
  安装版与本地产物 SHA-256 一致，且只运行一个安装版进程。

限制：

- 这里的“正在运行”仍以归约后的 `thinking` 为准；Needs approval or answer 的运行
  时长按产品规则冻结，因此不会被归入工作任务置顶组。
- 完整 `make check` 仍被上游快照缺少 `.github/workflows/ci.yml` 阻塞；此前的 locale、
  parser hash、package product、strip、signing、Info.plist、dSYM 和 Sparkle 路径门禁均通过。

### `refine`：任务运行时长改为秒级

变化：

- 单 turn 时长格式从整分钟改为秒级：`5s`、`2m 5s`、`2h 5m 7s`。
- 正在工作的任务继续以当前时间计算；停止、完成、待批准或报错任务继续冻结在最后
  事件，但冻结值也保留秒数。
- 菜单打开且存在 Thinking 任务时启动 1 秒本地计时器，只更新现有任务行副标题；
  菜单关闭或没有工作任务时立即停止，不额外触发会话扫描。

影响：

- 展开菜单中的运行时长与 Codex 的秒级表达一致，用户可以直接看到数字逐秒增长；
  状态同步仍维持原来的文件监听和约 2 秒活跃扫描，不因显示计时增加 I/O。

验证：

- 时长模型测试覆盖秒、分秒、时分秒，以及运行值增长和停止值冻结。
- AppKit 任务行测试覆盖不重建整张菜单的副标题原位更新，并固定 1 秒更新间隔。
- `AGENTMICRO_BUILD_ONLY=1 swift test --disable-automatic-resolution --filter AgentMicro`：
  49 个 tests、5 个 suites 全部通过。
- 本次三个生产 Swift 文件通过 SwiftLint strict，0 violations。
- 完成 debug 应用打包、ad-hoc 签名验证并安装到 `/Applications/AgentMicro.app`；
  安装版与本地产物 SHA-256 一致，且只运行一个安装版进程。

限制：

- 秒级计时基于 AgentMicro 已归约出的 `runStartedAt`；若历史 rollout 本身缺少 turn
  开始事件，仍使用既有的状态或会话时间回退。
- 完整 `make check` 仍被上游快照缺少 `.github/workflows/ci.yml` 阻塞；此前的 locale、
  parser hash、package product、strip、signing、Info.plist、dSYM 和 Sparkle 路径门禁均通过。

### `refine`：调整名称默认值、任务数量与行尾信息

变化：

- 任务名称选项顺序改为“任务标题 + 项目名”“任务标题”“仅项目名”，组合模式成为
  新安装默认值；既有用户已保存的选择继续保留。
- 修复“任务标题”和“任务标题 + 项目名”视觉重复：前者只显示标题，后者才在标题下方
  显示项目名；“仅项目名”继续只把项目放在标题位置。
- 设置页新增 Tasks shown 步进设置，范围 1–20、默认 6，并持久化到 UserDefaults；
  越界值在设置层归一到 1 或 20。
- 展开菜单按用户设定数量截取任务；2×3 菜单栏图标保持六槽，只跟踪同一排序最前的
  6 个任务。
- 移除任务行右侧未读绿点；Unread chat 继续由左侧绿色状态块表达。右侧改为固定显示
  单 turn 秒级时长，项目名只在组合名称模式下显示于左下方。
- 秒级计时器改为原位更新右侧时长标签，不重建任务行。

影响：

- 默认列表同时具备任务可辨识性和项目归属；三个名称选项现在有明确不同的视觉结果。
- 用户可按工作量在紧凑的 1 个任务和最多 20 个任务之间调整菜单长度，同时菜单栏图标
  的六块识别模型保持稳定。
- 行尾只保留时间信息，未读状态不再重复显示两个绿色提示。

验证：

- 设置测试覆盖新默认项、选项顺序、数量默认值、1–20 边界与跨实例持久化。
- 菜单模型测试覆盖 8 个任务展示、图标仍为 6 槽，以及任务标题与组合模式的项目副标题
  差异。
- AppKit 任务行测试覆盖右侧秒级时长原位更新。
- `AGENTMICRO_BUILD_ONLY=1 swift test --disable-automatic-resolution --filter AgentMicro`：
  51 个 tests、5 个 suites 全部通过。
- 本次六个生产 Swift 文件通过 SwiftLint strict，0 violations。
- `git diff --check` 通过；完成 debug 应用打包、ad-hoc 签名验证并安装到
  `/Applications/AgentMicro.app`，安装版与本地产物 SHA-256 一致，且只运行一个
  安装版进程。

限制：

- 新默认值只适用于没有保存过 `agentMicro.taskNameMode` 的用户；升级不会覆盖既有名称
  偏好。
- 完整 `make check` 仍被上游快照缺少 `.github/workflows/ci.yml` 阻塞；此前的 locale、
  parser hash、package product、strip、signing、Info.plist、dSYM 和 Sparkle 路径门禁均通过。

### `implementation`：补齐语言开关与软件更新运行时

变化：

- 菜单、设置、状态提示和无障碍文案改用 AgentMicro 独立本地化资源，完整覆盖 English
  与简体中文；新增“跟随系统 / English / 简体中文”语言开关，默认跟随系统。
- 应用语言覆盖只写入 `agentMicro.appLanguage`，选择跟随系统时删除该值，不修改全局
  `AppleLanguages`；语言变化会立即重建菜单和设置内容。
- 设置页新增软件更新区、自动检查开关、版本信息和手动“检查更新…”入口；配置正式
  更新源时，菜单页脚也显示检查更新入口。
- AgentMicro 目标接入现有 Sparkle 2.9.3 依赖，打包脚本嵌入
  `Sparkle.framework`、SwiftPM 本地化资源包和运行时 rpath。
- 打包脚本新增成对的 `AGENTMICRO_FEED_URL`、`AGENTMICRO_PUBLIC_ED_KEY` 配置；两者
  缺失时开发包明确显示更新源未配置，只有一项时打包直接失败。
- 菜单继续采用 CodexBar 的 310pt 基础宽度、原生菜单字体、内容间距、分隔线和互斥
  高亮规则，不引入 Provider 卡片或额外信息层级。

影响：

- 中文系统首次启动直接显示中文，用户也可为 AgentMicro 单独固定英文或简体中文。
- 软件更新的应用内能力和打包链路已经存在，且不会误用 CodexBar appcast；正式发布
  只需补齐 AgentMicro 独立 feed、公钥、Developer ID 签名与公证。
- 任务观察和状态同步不依赖更新网络，更新不可用或断网不会阻塞菜单功能。

验证：

- `AGENTMICRO_BUILD_ONLY=1 swift test --disable-automatic-resolution --filter AgentMicro`：
  55 个 tests、6 个 suites 全部通过。
- 本地化测试覆盖 English、简体中文和带任务数量的格式化字符串；设置测试覆盖系统语言
  默认值、语言覆盖、自动更新默认值与跨实例持久化。
- `./Scripts/package_agentmicro.sh debug` 成功；资源包包含 `en.lproj`、`zh-hans.lproj`，
  `Sparkle.framework` 已嵌入，`codesign --verify --deep --strict` 通过。

限制：

- 当前仓库没有 AgentMicro 独立远程仓库/feed URL 和 Ed25519 公钥，因此本地开发包
  会正确显示“尚未配置软件更新源”，不能完成真实在线更新。
- 本次只覆盖 English 与简体中文；增加其他语言需要同时补齐完整资源和测试。

### `refine`：同步 CodexBar 全部语言并支持数字输入任务数

变化：

- 语言选择从 English、简体中文扩展为与 CodexBar 当前目录完全一致的 23 种界面语言，
  继续保留“跟随系统”作为默认项。
- 新增繁體中文、Español、Català、Português (Brasil)、Deutsch、Svenska、Français、
  Italiano、Nederlands、日本語、한국어、Tiếng Việt、Türkçe、Українська、Русский、
  Bahasa Indonesia、Polski、العربية、فارسی、ไทย和 Galego 的完整 AgentMicro 文案。
- 阿拉伯语和波斯语使用 RTL 设置布局；任务行会将状态块移到右侧、时长移到左侧，并让
  标题和项目名右对齐。
- “显示任务数”在原有步进按钮旁新增数字输入框；用户可直接键入 1–20，设置层继续
  负责边界归一和持久化。
- 打包 Info.plist 的 `CFBundleLocalizations` 同步列出全部 23 种语言。

影响：

- AgentMicro 的语言覆盖与 CodexBar 不再分叉，系统语言命中任一已支持目录时可直接
  使用对应界面，不会因为选择器存在而正文回退英文。
- 键盘用户可以直接输入任务数，不必从 6 反复点击到目标值。

验证：

- 23 个 `Localizable.strings` 均通过 `plutil -lint`。
- 新增资源完整性测试，逐个比较 23 个目录与 English 的键集合，并格式化包含两个数字
  占位符的状态文案；同时覆盖阿拉伯语、波斯语 RTL 判断。
- `AGENTMICRO_BUILD_ONLY=1 swift test --disable-automatic-resolution --filter AgentMicro`：
  57 个 tests、6 个 suites 全部通过。

限制：

- 翻译与 CodexBar 支持语言范围保持同步，但 AgentMicro 的任务领域文案为独立资源；
  后续新增或修改英文键时必须同时更新全部 23 个目录，资源完整性测试会阻止遗漏。

## 2026-07-29

### `release`：建立 AgentMicro 独立发布与在线更新流水线

变化：

- 恢复与当前门控脚本完全匹配的 `.github/workflows/ci.yml`，包含 PR 草稿门控、macOS
  双分片 Swift 测试、Linux lint、musl 构建和聚合检查。
- 恢复上游 `.swiftformat` 与 `.swiftlint.yml`，让仓库检查重新使用项目约定的排除范围
  和规则，避免缺省配置误判生成文件与外部代码。
- 增加 `agentmicro-version.env`，使 AgentMicro 版本不再借用 CodexBar 的
  `version.env`。
- 扩展 `package_agentmicro.sh`：支持 arm64/x86_64 universal 合并、Sparkle 嵌套组件
  有序签名、ad-hoc/Developer ID 两种明确模式，并要求正式签名包同时携带独立 feed
  与公钥。
- 增加 Developer ID 签名、Apple 公证、staple、发布 ZIP、独立
  `agentmicro-appcast.xml` 生成和可选 GitHub Release 发布脚本。
- 增加安全配置模板和发布指南；AgentMicro 明确使用专属 Keychain account/私钥，
  不复用 CodexBar 的 appcast 或旧 AGCY 密钥。
- 将发布流水线静态契约纳入 `make check`。

影响：

- 发布信息补齐后，无需再改运行时代码即可构建正式可更新包。
- 开发包继续 ad-hoc 签名并显示更新不可用，不会降级绕过签名要求。
- CI 缺失不再阻断完整仓库检查。

验证：

- `Scripts/test_swift_test_sharding.sh`
- `Scripts/test_ci_path_gate.sh`
- `Scripts/test_agentmicro_release.sh`
- `make check`
- `make test`：730 个 selections、61 个 groups 全部一次通过，0 失败、0 重试、0 超时。

限制：

- 公开源码仓库和 `origin` 已配置；本机仍没有有效 Developer ID 身份，尚未生成或保存
  AgentMicro 专属 Ed25519 密钥，也未提供 App Store Connect 公证凭据。
- 因缺少上述外部发布身份，本次只验证开发包、脚本契约和 CI，不能执行真实公证、上传
  或跨版本 Sparkle 更新。

### `fix`：以最终回答结束蓝色运行态

变化：

- rollout 状态归约器现在把 `event_msg.agent_message` 和
  `response_item.message` 中的 `phase: final_answer` 都视为 turn 的明确结束信号，
  不再必须等待稍后写入的 `task_complete`。
- `phase: commentary` 仍保持 turn 活跃，工具调用之间的中间回复不会误把任务变白。
- 最终回答结束 turn 时同时关闭尚未配对的工具调用，避免尾部工具结果缺失使任务继续
  显示为执行中。
- rollout 文件变化除立即增量对账外，也会启动 150ms、350ms、800ms 的有界尾部对账，
  防止文件监听防抖或分步写入只消费到完成边界之前。

影响：

- Codex 已显示最终回答时，AgentMicro 会在最终回答事件被监听到后立即离开蓝色运行态；
  `task_complete` 仍作为兼容终止信号。
- 现场任务的 `final_answer` 与 `task_complete` 相隔约 16ms；修复消除了这段事件顺序
  对状态正确性的依赖。

验证：

- `AGENTMICRO_BUILD_ONLY=1 swift test --disable-automatic-resolution --filter CodexTaskStateEngineTests`
- `AGENTMICRO_BUILD_ONLY=1 swift test --disable-automatic-resolution --filter AgentMicro`：
  60 个 tests、6 个 suites 全部通过。
- `make check`：1608 个 Swift 文件零违规。
- `make test`：730 个 selections、61 个 groups 全部一次通过，0 失败、0 重试、0 超时。
- 真实 rollout 单次诊断：已完成任务不再出现在 `thinking` 列表。

限制：

- AgentMicro 仍只能确认从自身菜单进入任务的查看动作；用户直接在 Codex App 内切换
  任务时，当前没有官方只读事件可可靠同步“已查看”。因此本次修复保证蓝色运行态及时
  结束，但直接在 Codex 内查看后的绿色未读态仍可能需要从 AgentMicro 打开一次才消除。

### `refine`：显示 Codex 快速模式并收敛为五种状态色

变化：

- 状态归约器解析 `thread_settings_applied.thread_settings.service_tier`：
  `priority` 标记为快速模式，`default` 取消标记；不按模型名或响应耗时猜测。
- 菜单任务时长后增加 `bolt.fill` 闪电，仅快速模式显示，并同步进任务行无障碍描述。
- 23 种 AgentMicro 界面语言均补充“快速模式”文案。
- 内部 `unknown` 继续用于发现和归约边界，但任务方块对外复用 Idle 白色，不再显示为
  灰色第六态。六格菜单栏 Logo 的空槽仍为淡灰占位，它不代表任务状态。
- 单次诊断记录增加 `usesFastModel`，便于用真实 rollout 验证。

影响：

- 菜单可以直接区分快速和标准 service tier；标准模式时布局保持只有时长。
- 用户可见任务状态严格只有白、绿、蓝、橙、红五种 Codex Micro 颜色。

验证：

- `AGENTMICRO_BUILD_ONLY=1 swift test --disable-automatic-resolution --filter AgentMicro`：
  61 个 tests、6 个 suites 全部通过。
- `make check`：1608 个 Swift 文件零违规。
- `make test`：730 个 selections、61 个 groups 全部一次通过，0 失败、0 重试、0 超时。
- 真实 rollout 单次诊断识别出 4 个 `service_tier: priority` 历史任务，当前标准任务保持
  `usesFastModel: false`。

限制：

- 闪电表示 Codex 写入的 `priority` service tier，不表示模型名称、reasoning effort
  或瞬时生成速度。

### `docs`：建立独立开源项目入口与上游署名

变化：

- 将仍然描述 CodexBar 产品的根 `README.md` 改为 AgentMicro 英文项目首页，并增加
  对应的 `README.zh-CN.md`。
- README 公开说明五种任务状态、功能范围、隐私边界、源码构建、开发验证、当前状态
  推断限制和独立更新策略。
- 明确说明仓库保留的其他 Provider 代码和测试来自 CodexBar 底座，但没有接入
  AgentMicro 菜单；V1 对外仍严格为 Codex-only。
- 明确声明 AgentMicro 衍生自 Peter Steinberger 的 MIT 项目 CodexBar，保留原版权
  声明，并增加 `NOTICE.md` 说明复用范围及独立项目关系。
- 增加 `CONTRIBUTING.md` 和 `SECURITY.md`，约束贡献者不得提交真实 Prompt、源代码、
  凭据或未脱敏 rollout，并提供私密漏洞报告入口。
- 将公开发布配置模板固定到 `fizzy718/AgentMicro` 和独立 Bundle ID，不写入任何私钥。
- 调整上游站点一致性守卫：只有根 README 仍为 CodexBar 时才要求宣传 Provider 数；
  AgentMicro 根 README 不再被迫携带与产品范围冲突的 CodexBar 营销内容。

影响：

- 仓库首页、许可证、来源和贡献边界与 AgentMicro 的实际产品一致，不再把衍生项目
  伪装成 CodexBar，也不会抹去上游作者与许可证。
- 项目具备公开 GitHub 仓库所需的基本安装、贡献、安全和维护入口。
- 已创建公开仓库 [`fizzy718/AgentMicro`](https://github.com/fizzy718/AgentMicro)，
  以 `main` 作为默认分支，并保留 `steipete/CodexBar` 作为上游来源。

验证：

- `git diff --check`
- 仓库敏感信息文件名扫描；命中项仅为发布配置占位符和上游测试使用的模拟凭据。
- `make check`
- `make test`

限制：

- 首次签名 Release 仍需要 Developer ID、Apple 公证凭据和 AgentMicro Ed25519 私钥；
  公开源码仓库本身不包含这些秘密。

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
