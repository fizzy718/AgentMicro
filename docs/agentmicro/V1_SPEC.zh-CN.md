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

V1 直接使用 Codex Micro 官网展示的五种状态与颜色，不再把 Thinking 和 Running
拆成两个颜色状态。无法可靠确认状态时内部保留 `unknown` 回退，但 UI 按 Idle 白色
显示；它不属于 Codex Micro 五态，也不会引入灰色或第六种状态色。

| 状态 | 颜色 | 判断依据 | 用户文案 |
|---|---|---|---|
| `idle` | `#FFFFFF` | 活跃任务当前没有未结束的模型或工具事件 | Idle |
| `unread` | `#9BF396` | rollout 明确完成；Desktop 线程仍在 Codex 本地未读集合中，或 CLI 尚无 AgentMicro 本地已读记录 | Unread chat |
| `thinking` | `#9CD5FE` | 用户请求尚未结束，或存在未结束的工具调用/子进程 | Thinking |
| `requiresInput` | `#FFD0B8` | 本地事件明确要求用户批准或回答 | Needs approval or answer |
| `error` | `#FF7373` | 本地事件明确报告错误；额度窗口达到 100% 也属于错误 | Error |

内部 `unknown` 表示已找到最近会话、但暂时不能可靠确认进程或事件归属；它对外复用
Idle 的 `#FFFFFF`。菜单栏 Logo 中没有任务占用的槽位仍使用淡灰占位，淡灰不是任务状态。

`requiresInput` 在 rollout 中存在尚未返回结果的 `request_user_input` 时出现；assistant
向用户提出带问号的直接问题，或明确要求输入、填写、登录、确认、授权、验证、点击、
选择、接管或提交时，同样锁存为 `requiresInput`，直到下一条用户消息开始新 turn。
即使当前 turn 已写入
`task_complete`，用户接管锁也继续保持，避免浏览器输入等中间步骤被错误显示为蓝色或
绿色。否定式提示（例如“请先不要操作”）不触发橙色。

Codex 宿主不会把 Computer Use 的跨应用授权弹窗单独写进 rollout，因此同一任务第一次
访问某个 Computer Use 目标应用、调用仍未返回时，也保守显示为 `requiresInput`；同一
目标后续调用仍按 `thinking` 显示，避免普通自动化步骤持续闪橙。`sandbox_permissions =
require_escalated` 可能由 Codex 自动审批 guardian 处理，不能据此推断用户需要批准。
普通静默或进程存活也不会被解释为“需要用户处理”。绿色表示完成结果尚未查看。

### 状态归约规则

- 进程存在不是 `thinking` 的充分条件；没有模型或工具事件时使用 `idle`。
- rollout 文件最近更新不是 `thinking` 的充分条件。
- 未配对的用户请求可以形成 `thinking`。
- 从用户请求开始到 assistant `phase: final_answer`、`task_complete` 或 `turn_aborted`
  之间始终保持 `thinking`；单个工具返回或 `phase: commentary` 的中间 assistant 消息
  不能让仍在运行的任务短暂闪回白色。
- 未配对的工具调用也形成 `thinking`；当前动作只参与本地诊断，不进入任务菜单。
- assistant 明确把操作权交给用户后形成 `requiresInput`，由下一条用户消息解除。
- 工具输出到达后必须结束对应工作状态。
- 长时间运行工具要结合子进程存活情况，避免仅凭文件静默误判为 `idle`。
- 找不到可靠 owner 的最近 Desktop rollout 使用 `unknown`，不能伪造 PID 归属。
- Codex Desktop 的 app-server 可能同时持有多个 rollout，不能按 app-server PID 合并成一个任务。
- `task_started` / `user_message` 与 assistant `phase: final_answer`、`task_complete` /
  `turn_aborted` 构成 file-only Desktop 任务的明确 turn 生命周期；最终回答事件和
  response item 任一先落盘都必须立即结束运行态。
- subagent rollout 不作为 V1 顶层任务展示；guardian rollout 只作为父任务仍有活动的
  发现线索。扫描器用 guardian 的父任务 ID 从 Codex 只读索引取回原始父 rollout，
  菜单仍只展示父任务。
- 同一工作目录存在多个 Codex CLI 进程时，不按时间顺序猜测 PID 与 rollout；保留独立 rollout 任务并将精确返回能力降级。

## 标题解析顺序

1. Codex 显式线程标题。
2. `session_index.jsonl` 的线程名称。
3. 首个有效用户请求的安全预览。
4. 项目目录名称。
5. 缩短后的 Session ID。

必须忽略 IDE 环境注入、`AGENTS.md` 内容、系统上下文和 subagent 元数据等非用户标题。

默认菜单使用任务标题，并在下一行显示项目名。用户可改为“任务标题”以隐藏项目行，
或改为“仅项目名”以避免显示可能包含敏感文本的任务标题。

## 当前动作

当前动作可以参与本地状态判断和诊断，但不进入任务菜单。不得显示：

- 命令完整输出。
- 文件内容。
- 工具返回内容。
- 完整 Prompt。
- 环境变量和凭证。

## 菜单结构

```text
AgentMicro                               1 active

■  修复同步状态                   12m 3s
   token-monitor

■  AgentMicro                         4m 8s

────────────────────────
Refresh
Settings…
Check for Updates…
Quit AgentMicro
```

菜单显示数量可设为 1–20，默认 6。仍处于 `thinking`、运行时长持续增长的任务优先；
工作中与非工作中两组内部再严格按 `stateChangedAt` 倒序。菜单栏的 6 个槽位只对应
该排序最前的 6 个任务。普通 token、日志或工具输出若没有改变状态，不会改变同一组
内的顺序。
每行左侧只显示一个无边框圆角矩形，并直接使用任务状态色；任务处于 `thinking`
时圆角矩形以 0.85 秒周期呼吸，系统启用“减少动态效果”时保持静止。右侧不再显示
未读绿点；未读只由左侧状态圆角矩形使用 Unread chat 的官方绿色表达。
Desktop 已完成任务以 Codex 自己维护的本地未读线程集合为准：用户从 AgentMicro
或直接从 Codex App 打开对应会话后，方块恢复 Idle 白色；Codex 仍标记未读时保持绿色。
该集合缺失、格式变化或刚完成事件尚在落盘时，AgentMicro 不把“线程 ID 暂时缺席”
直接解释为已读，而是回退到本地已读记录并保留最多 5 秒的写入宽限。CLI 没有相同的
Desktop 已读来源，继续使用 AgentMicro 本地已读活动；同一会话再次完成新的 turn 时
可以重新变绿。
若用户在任务仍为 Thinking 时点击进入，而 `task_complete` 随后才写入 rollout，
AgentMicro 只对这一个已查看的 turn 保留 5 秒短暂标记；该 turn 在窗口内完成时直接
记为已查看。标记不能跨到下一 turn，也不能吞掉 5 秒之后的新完成事件。

右侧固定显示当前单个 turn 的运行时长；rollout 最近一次
`thread_settings_applied.thread_settings.service_tier` 为 `priority` 时，在时长后显示
系统 `bolt.fill` 闪电，表示 Codex 快速模式；`default` 或字段缺失时不显示。该标记只
反映任务实际 service tier，不按模型名或响应速度猜测。副标题只在“任务标题 + 项目名”
模式下显示项目名。“任务标题”模式不显示项目副标题，“仅项目名”模式将项目放在标题位置。
菜单不显示状态文案、当前动作、Codex App/CLI 来源，也不显示“几秒前”。
Thinking 期间时长随当前时间增长；任务一旦
停止、完成、等待输入或报错，时长冻结在最后事件，不再增长。时长统一精确到秒：
不足一分钟显示 `5s`，不足一小时显示 `2m 5s`，超过一小时显示 `2h 5m 7s`。
菜单展开且存在 Thinking 任务时，右侧时长每 1 秒在本地更新一次，不等待 2 秒状态扫描；
菜单关闭后停止该计时器。项目名与标题相同时不重复，项目名由标题本身承载。
菜单 hover 必须始终互斥；鼠标移动经过多行时，只允许当前一行显示选中背景。
菜单顶部 AgentMicro 标题使用正常标签色而非禁用态灰色，字体为 13pt semibold；
任务标题使用 13pt 菜单字体，副标题保持 11pt。展开菜单固定使用 CodexBar 基础卡片
同款 310pt 宽度，过长的任务名和项目名在可用宽度内尾部截断。
菜单的基础宽度、内容内边距、字体层级、分隔线和高亮颜色沿用 CodexBar 的原生菜单设计；
AgentMicro 只保留任务状态所需的信息密度，不复制 CodexBar 的 Provider 卡片。
正式签名并配置更新源的版本在设置项之后显示“检查更新…”，开发包或未配置更新源时
不显示失效菜单项。

## 菜单栏图标

- 图标由 2×3 网格的 6 个无边框圆角矩形组成，上面 3 个、下面 3 个。
- 6 个槽位对应菜单中“工作任务优先、组内按状态变化时间排序”的前 6 个任务；即使
  用户把展开菜单数量设为 7–20，图标仍只跟踪前 6 个。空间顺序
  沿环形路径排列：上排从左到右，随后下排从右到左。各自直接使用与菜单任务行完全
  相同的 Codex Micro 状态色和颜色源。
- 没有任务或状态为 `unknown` 的槽位使用低强调度中性色填充，不增加外边框。
- 任一任务处于 `thinking` 时，6 个槽位保留自身状态色，并按上排左到右、下排右到左
  的环形顺序每 70ms 推进一帧、依次进行透明度呼吸；整圈约 3.78 秒，不改变成白色。
- 没有工作中任务时图标静止；系统启用“减少动态效果”时不启动动画。
- 图标不再附加活动任务数字，任务数量和项目归属在菜单中查看。

## 返回任务

- CLI：尽力定位并激活对应终端窗口。
- Desktop：优先打开 Codex 官方 `codex://threads/<session-id>` 深链，直接切换到对应
  任务；深链不可用时再匹配窗口，最后降级为激活 Codex App。
- IDE：能够确认来源时激活对应编辑器。
- 精确窗口定位需要 Accessibility 权限时，应说明原因并提供只激活应用的降级路径。

## 刷新策略

- 菜单始终先使用缓存状态立即打开。
- 已发现任务保存本次扫描得到的 session 快照；打开菜单、点击任务或 rollout 文件变化时，
  优先直接增量读取这些已知 rollout 的尾部，不等待进程、SQLite 和目录的完整任务发现。
- 打开菜单、点击任务或收到 rollout 文件变化后，除立即对账外，再按
  150ms、350ms、800ms 的间隔执行三次有界尾部对账，覆盖最终 assistant 消息与
  `task_complete` 分两步落盘，以及文件监听防抖合并尾部写入的短暂窗口。
- 完整任务发现仍在后台异步执行，用于找到新任务、guardian 父任务和变化的进程归属；
  它不能阻塞已知任务的状态更新。
- 监听当天/前一天会话目录及已发现 rollout 文件；guardian 指向较早的活跃父 rollout
  时也直接监听父文件。创建新任务或追加事件后约 200ms 防抖触发刷新。
- 刷新过程中再次发生变化时必须排队补扫，不能因“已有刷新进行中”丢失最后一次事件。
- Codex Desktop 正在运行、任务处于工作状态或任务有独立进程时，目标刷新间隔约 2 秒。
- 菜单展开期间，运行时长显示使用独立的 1 秒本地计时器；这只更新文字，不触发扫描。
- 无活跃任务时仍每 5 秒兜底扫描，防止文件系统事件缺失。
- rollout 采用增量读取，保存文件 offset，并处理半行、截断和轮转。
- 首次发现体积较大的长会话时从末尾 4 MiB 的完整 JSONL 行开始归约当前 turn，
  避免为了显示状态解析整段历史；随后继续按 offset 增量读取。
- 进程、`lsof` 和目录扫描分频执行，避免每 2 秒完成一次全量扫描。

## 设置

V1 设置页只包含：

- 界面语言：
  - 跟随系统，默认值。
  - 与 CodexBar 对齐的 23 种界面语言：English、简体中文、繁體中文、Español、
    Català、Português (Brasil)、Deutsch、Svenska、Français、Italiano、Nederlands、
    日本語、한국어、Tiếng Việt、Türkçe、Українська、Русский、Bahasa Indonesia、
    Polski、العربية、فارسی、ไทย和 Galego。
- 开机启动。
- 任务名称显示方式：
  - 任务标题 + 项目名，默认并排在第一项。
  - 任务标题，只显示标题，不显示项目副标题。
  - 仅项目名。
- 菜单任务数量：1–20，默认 6；同时提供可直接键入的数字框和上下步进按钮，越界值
  由设置层归一到 1 或 20；菜单栏图标固定跟踪前 6 个。
- 是否显示最近结束的任务。
- 软件更新：
  - 正式构建可开启或关闭自动检查更新，默认开启。
  - 可手动检查更新并显示当前版本。
  - 没有独立 AgentMicro feed、公钥或正式发布签名时，明确显示不可用原因。
  - 正式包使用 AgentMicro 专属 appcast 和 Ed25519 密钥，由 Developer ID 签名并通过
    Apple 公证；开发包的 ad-hoc 签名不能启用在线更新。
  - 发布产物为同时包含 arm64 与 x86_64 的 universal ZIP，appcast 与 CodexBar 完全分离。

最近结束任务默认显示，保留时间固定为 24 小时；V1 不增加高级轮询设置。
语言覆盖只写入 AgentMicro 自己的 UserDefaults，不写入全局 `AppleLanguages`；选择
“跟随系统”时清除应用覆盖并按 macOS 首选语言解析。当前完整覆盖 English 与简体中文，
以及 CodexBar 的其余 21 种界面语言；全部目录必须与 English 保持同一键集合，缺失键
统一回退到 English。阿拉伯语和波斯语使用从右到左的设置布局，任务行镜像状态块、
标题和时长位置。

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
- 复用 CodexBar 的应用级语言覆盖模式和 Sparkle 更新架构；AgentMicro 使用自己的
  资源、feed、公钥和发布包，不能指向 CodexBar 的 appcast。
- AgentMicro 版本由 `agentmicro-version.env` 独立管理；发布脚本必须在上传前完成
  嵌套 Sparkle 签名、Developer ID 签名、公证、staple 和 appcast Ed25519 签名。
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
- 多个 Desktop 与 CLI 任务不重复、不串线；所有权不明确时必须保守降级。
- 工具输出结束后不继续显示 `executing`。
- 任务结束后显示绿色未读态；Desktop 任务无论从 AgentMicro 还是 Codex App 查看，
  都同步恢复白色，最迟在 24 小时保留窗口结束后移除。
- 菜单使用缓存即时打开，不等待扫描完成。
- CLI 任务点击后能唤起对应终端或明确降级。
- 断网时除软件更新外的所有 V1 功能正常；更新失败不能阻塞任务观察。
- 首次启动默认跟随系统语言；23 种界面语言均可独立选择并跨启动保留。
- 正式发布包配置独立 feed 和公钥后可手动检查更新；未配置时设置页明确说明原因。
- 不出现 Keychain 或 Full Disk Access 权限提示。
- 解析器使用固定 fixtures 覆盖每种状态及异常 JSONL。
