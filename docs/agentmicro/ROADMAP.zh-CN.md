# AgentMicro 产品路线图

路线图描述能力进入产品的顺序，不代表固定发布日期。只有上一阶段的可靠性和隐私要求满足后，下一阶段才进入实现。

## V1：Codex Task Pulse

目标：在 macOS 菜单栏可靠观察本机 Codex 任务。

范围：

- Codex Desktop 与 CLI 任务发现。
- Thinking、Executing、Waiting、Rate limited、Unknown、Done。
- 当前动作、任务标题、项目和来源。
- 点击返回任务。
- 本地只读、无网络、无账户凭证。

主要能力来源：

- CodexBar：原生菜单栏、任务扫描、窗口唤起。
- abtop：实时状态归约和工具调用配对。
- cc-switch：Codex 标题解析容错。

退出条件：

- 满足 `V1_SPEC` 的全部验收标准。
- 经过真实 Desktop/CLI 多任务场景验证。
- 状态误报不会让用户以为产品拥有不存在的控制能力。

### V1 实施节奏

| 里程碑 | 状态 | 交付内容 | 退出条件 |
|---|---|---|---|
| M0：可运行骨架 | 已完成 | 独立菜单栏入口、Codex 会话发现、active/idle 列表、点击返回、5/15 秒轮询 | 独立编译与模型测试通过，进程可持续启动 |
| M1：Task State Engine | 已完成 | rollout 增量读取、事件配对、六态归约、当前动作、2/15 秒轮询 | 固定 fixtures 覆盖六态、时间戳乱序、半行、截断、异常 JSONL、普通/custom/长任务调用结束 |
| M2：菜单产品化 | 下一步 | V1 菜单结构、隐私设置、最近完成任务、开机启动、正式 `.app` 打包 | 菜单验收项、视觉交互烟测与隐私默认值通过 |
| M3：真实场景验证 | 待开始 | Desktop/CLI 多任务验证、性能和误报修正 | 达成 V1 全部退出条件 |

M1 已替换 M0 的 `active/idle` 展示。没有可靠 owner 的近期 Desktop rollout 保持 `unknown`，不通过 app-server PID 猜测任务归属；该关联能力必须在 M3 用真实 Desktop 多任务场景验证。

## V1.1：Attention Signals

目标：在不增加任务控制的前提下，更清楚地告诉用户哪些任务值得查看。

候选能力：

- 明确的 rate-limit 提醒。
- 能够被可靠识别的错误事件。
- 任务完成通知。
- 可选声音和勿扰时段。
- 菜单栏聚合状态。

进入条件：

- 已能可靠区分普通 `waiting`、明确限流和明确错误。
- 通知具有去重、冷却和恢复逻辑。

## V1.2：History & Resume

目标：从“看见当前任务”扩展为“找回并继续最近任务”。

候选能力：

- 最近会话列表。
- 本地标题和项目搜索。
- 会话元数据详情。
- 复制 `codex resume <session-id>`。
- 在 Terminal、iTerm2、Ghostty、Kitty、WezTerm、Warp 等终端恢复。
- 收藏和归档标记。

主要能力来源：

- cc-switch Session Manager。
- CodexBar/cc-switch 的 Codex state DB 和 session index 解析。

隐私要求：

- 默认不建立全文索引。
- 搜索范围和缓存策略必须可解释。
- 删除会话不与 Resume 同版本默认上线。

## V2：Managed Tasks

目标：允许 AgentMicro 创建并管理属于自己的 Codex 任务。

候选能力：

- 创建托管任务。
- 结构化生命周期事件。
- 审批、继续、停止。
- 任务输入与结果摘要。
- 从菜单栏发起新任务。

技术边界：

- Observed task 和 Managed task 必须是不同类型。
- 不能宣称能够接管 Codex Desktop 已经运行的任务。
- 只使用被验证且稳定的 Codex 接口。

主要能力来源：

- Codex app-server 或后续官方任务接口。

## V2.5：Usage & Limits

目标：把任务状态和资源状态放在同一个轻量入口中。

候选能力：

- 当前 Codex 5 小时与长周期额度。
- 当前任务 Token 和上下文窗口。
- 每日/每周用量摘要。
- 明确的 rate-limit 原因。

主要能力来源：

- token-monitor 的额度与历史模型。
- abtop 的会话 Token、上下文和 rate-limit 解析。
- CodexBar 的 Provider 展示组件。

限制：

- V1 菜单不能因此退化成复杂用量仪表盘。
- 账户凭证能力必须独立、可关闭。

## V3：Multi-device & Companion

目标：从单机菜单栏扩展为跨设备 Agent 状态入口。

候选能力：

- 多 Mac 状态同步。
- Headless agent。
- 自托管 Hub。
- iPhone/Apple Watch 状态。
- 硬件按键和灯光联动。
- 远程任务跳转。

主要能力来源：

- token-monitor 的 Agent/Hub/SSE/Worker 协议。
- CodexBar 的 SSH/Tailscale 远端会话。
- Codex Micro 硬件交互模型。

## 路线图护栏

- 新需求默认进入 `BACKLOG`，不是自动进入当前版本。
- 不能为了复用现有项目而扩大 AgentMicro 的产品范围。
- 任务状态可靠性优先于状态数量。
- 控制能力必须晚于观察能力。
- 网络、账户和凭证能力必须保持可选。
