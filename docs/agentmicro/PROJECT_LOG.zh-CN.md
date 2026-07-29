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
