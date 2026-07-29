# AgentMicro 现有项目能力地图

## 结论

当前挂载代码包含四个可用项目，它们分别覆盖 AgentMicro 的不同层次：

| 项目 | 技术栈 | 最强能力 | AgentMicro 中的角色 |
|---|---|---|---|
| AgentMicro/CodexBar | Swift 6、AppKit、SwiftUI | 原生菜单栏和 macOS 集成 | V1 应用底座 |
| abtop | Rust、ratatui | 实时任务状态和进程关联 | V1 状态逻辑来源 |
| cc-switch | Tauri、Rust、React | 会话恢复、Provider 和代理管理 | 后续会话与管理能力来源 |
| token-monitor | Electron、Node.js | 用量、额度、历史和多设备 | 后续数据与同步能力来源 |

可视化工作目录当前为空，不提供可复用能力。

## AgentMicro/CodexBar

已落地：

- macOS 菜单栏应用生命周期。
- 设置、快捷键、开机启动、Sparkle 更新。
- 动态状态栏图标、菜单描述模型、通知和 WidgetKit。
- Codex/Claude 本地会话扫描。
- Codex Desktop、CLI、IDE 来源识别。
- 进程、CWD、rollout、`session_index.jsonl` 和 Codex state DB 关联。
- 本地窗口唤起。
- SSH/Tailscale 远端会话。
- 大量 Provider 用量和额度能力。

当前不足：

- `AgentSession.State` 只有 `active` 和 `idle`。
- 本地会话默认 30 秒刷新。
- 完整 CodexBar 产品范围远大于 AgentMicro V1。

复用结论：

- 直接复用菜单栏壳、扫描基础设施和窗口唤起。
- 已复用 310pt 基础菜单宽度、原生字体/内边距/高亮层级、应用级语言覆盖模式和
  Sparkle 更新架构；AgentMicro 已将自己的完整资源同步到 CodexBar 的 23 种界面语言，
  并为阿拉伯语和波斯语补充 RTL 布局。AgentMicro 复用 Sparkle 嵌套签名路径，但使用
  独立版本文件、universal 发布包、appcast、Ed25519 密钥和 GitHub Release，不能使用
  CodexBar 的 appcast 或旧公钥。
- V1 不保留完整 Provider UI。
- 状态模型需要重新定义。
- AgentMicro 额外只读消费 Codex Desktop 本地全局状态中的未读线程 ID 集合；这不是
  CodexBar Provider 能力，也不被用于修改 Codex 状态。
- CodexBar 没有浏览器用户接管状态；AgentMicro 额外归约 assistant 的明确用户操作
  请求并锁存橙色，等待下一条用户消息解除。

## abtop

已落地：

- Claude Code、Codex CLI、Codex Desktop、OpenCode 任务发现。
- `Thinking`、`Executing`、`Waiting`、`Unknown`、`RateLimited`、`Done` 状态。
- Codex rollout 增量语义、工具调用与输出配对。
- 当前动作、模型、reasoning effort、Token、上下文窗口。
- Git 状态、子进程、端口、MCP Server 和主机资源。
- cmux、tmux、iTerm2 任务跳转。
- 稳定 JSON Snapshot 和 Rust Library 接口。

限制：

- 状态来自本地启发式，不是 Codex Desktop 权威 API。
- `Waiting` 不能可靠表示审批等待。
- 不维护用户是否已在 Codex Desktop 查看完成结果的已读/未读模型。
- 直接引入 Rust sidecar 会增加 V1 打包和签名复杂度。

复用结论：

- V1 移植 Codex 状态归约算法和 fixtures 思路。
- 暂不把 abtop 二进制作为运行时依赖。

## cc-switch

已落地：

- 多 Provider 配置与系统托盘切换。
- 本地代理、格式转换、故障转移、熔断和健康检查。
- MCP、Prompts、Skills 管理。
- Codex、Claude、OpenCode、OpenClaw、Gemini、Hermes、Grok Build 会话扫描。
- 会话搜索、分组、详情、批量删除和恢复命令。
- Codex 显式标题、state DB、session index 和归档会话解析。
- 多种 macOS 终端启动器。

限制：

- 会话管理偏历史浏览和恢复，不提供可靠的实时状态机。
- Tauri/React 运行时不适合作为原生菜单栏 V1 依赖。
- Provider 和代理产品范围远大于 V1。

复用结论：

- 吸收标题解析、历史会话和终端恢复能力。
- Resume 进入 V1.2，Provider/代理能力不进入 V1。

## token-monitor

已落地：

- 28+ AI 工具 Token 用量来源。
- Codex、Claude、OpenCode Session 明细。
- Prompt/回复轮次、工具、Token、成本和缓存命中分析。
- 多 Provider 额度、余额和 Codex 账号切换。
- 趋势、热力图、导出和本地历史归档。
- Electron 小部件、托盘和悬浮小窗。
- Node Hub、内嵌 Hub、Cloudflare Worker 和 SSE 多设备同步。

限制：

- `active/waiting/missing` 描述数据源是否存在，不代表任务实时状态。
- Electron 不应成为原生 V1 的运行时依赖。
- 用量与多设备会显著扩大首版范围。

复用结论：

- V2.5 使用额度和历史模型。
- V3 参考 Agent/Hub/SSE 协议。
- V1 不引入。

## 状态同步参考项目

本轮还核对了 freemicro 与 opendeck，它们只作为设计证据，不进入运行时依赖：

- **freemicro**：没有“用户已查看线程”的信号，用默认 180 秒完成态 TTL 自动熄灭。
  该做法会把超时近似包装成已读，AgentMicro 不采用。
- **opendeck**：只跟踪自身通过 `codex exec --json` 创建的托管会话，完成时直接进入
  `done`；它明确不观察现有 Codex Desktop 会话，因此没有 Desktop 已读同步方案。
- **abtop**：关注 Working、Waiting、Done 等运行生命周期，不维护 Unread/Read。

AgentMicro 采用 Codex Desktop 自己持久化的本地未读线程 ID 集合作为 Desktop 完成任务
的权威来源，并在字段缺失、解析失败或完成事件刚落盘时安全回退。该字段不是公开 API，
因此解析器必须保持窄范围、可失败且不得把缺失文件解释为空未读集合。

## 推荐组合

```text
Codex process + rollout
        ↓
CodexBar discovery
        ↓
abtop-derived state reducer
        ↓
AgentMicro task store
        ↓
CodexBar native menu + focus
```

后续按路线图再接入：

```text
cc-switch history/resume
token-monitor usage/sync
Codex managed-task API
```

## 许可证

四个项目均采用 MIT 路线。复用源代码时必须保留相应许可证、版权声明和必要的上游归属，不把第三方实现伪装为 AgentMicro 原创。
