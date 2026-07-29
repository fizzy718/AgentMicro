# AgentMicro 未来需求池

这里存放尚未进入当前版本的需求、研究项和限制。进入实现前必须先被提升到路线图中的明确阶段。

## 状态说明

- `candidate`：值得保留，但尚未排期。
- `research`：需要先验证技术可行性或状态可靠性。
- `blocked`：受外部接口或平台限制。
- `deferred`：明确不进入当前版本。

## 任务观察

| ID | 状态 | 需求 | 进入条件 |
|---|---|---|---|
| AM-001 | research | 区分等待用户输入和等待审批 | 找到稳定、可验证的本地事件 |
| AM-002 | research | 可靠识别任务失败和成功 | 不依赖自然语言关键词 |
| AM-003 | candidate | 显示子 Agent 树和父子关系 | Codex rollout 关系稳定且 UI 不拥挤 |
| AM-004 | candidate | 显示上下文窗口和压缩事件 | V1 状态稳定后进入 V2.5 |
| AM-005 | candidate | 显示 CPU、内存和子进程 | 证明对任务决策有持续价值 |
| AM-006 | candidate | 监听 Agent 启动的本地端口 | 有明确清理和安全边界 |

## 注意力与通知

| ID | 状态 | 需求 | 进入条件 |
|---|---|---|---|
| AM-101 | deferred | Waiting 通知 | 能区分普通空闲与需要处理 |
| AM-102 | candidate | 任务完成通知 | Done 状态经过真实场景验证 |
| AM-103 | candidate | Rate-limit 通知 | 有去重、恢复和冷却机制 |
| AM-104 | candidate | 错误通知 | 错误状态语义可靠 |
| AM-105 | candidate | 勿扰时段和声音 | 通知能力进入路线图 |

## 历史与恢复

| ID | 状态 | 需求 | 进入条件 |
|---|---|---|---|
| AM-201 | candidate | 最近会话列表 | V1 完成 |
| AM-202 | candidate | 按标题、项目搜索 | 明确本地索引与隐私策略 |
| AM-203 | candidate | 复制 Codex Resume 命令 | 验证当前 Codex CLI 命令兼容性 |
| AM-204 | candidate | 多终端恢复 | 抽象 Terminal Launcher |
| AM-205 | candidate | 收藏、标签和归档 | 历史会话模型稳定 |
| AM-206 | deferred | 删除会话 | 提供恢复机制、路径校验和明确确认 |
| AM-207 | candidate | 导出 Markdown/JSON | 定义敏感信息处理规则 |

## 任务管理

| ID | 状态 | 需求 | 进入条件 |
|---|---|---|---|
| AM-301 | candidate | 从菜单栏创建新任务 | Managed task 模型完成 |
| AM-302 | blocked | 接管 Codex Desktop 已运行任务 | Codex 提供稳定外部接口 |
| AM-303 | candidate | 审批、继续和停止托管任务 | 仅针对 Managed task |
| AM-304 | candidate | Fork 托管任务 | 官方接口支持且历史模型明确 |
| AM-305 | candidate | 自定义任务动作/技能 | 权限和执行边界完成设计 |

## 用量与账户

| ID | 状态 | 需求 | 进入条件 |
|---|---|---|---|
| AM-401 | candidate | Codex 5 小时与长周期额度 | 不增加默认凭证风险 |
| AM-402 | candidate | 当前任务 Token | 状态菜单信息密度验证通过 |
| AM-403 | candidate | 每日/每周用量摘要 | 进入 V2.5 |
| AM-404 | deferred | 多 Provider 用量 | Codex-only 核心价值完成 |
| AM-405 | deferred | Codex 账号切换 | 独立安全设计与确认流程 |

## 多设备与终端

| ID | 状态 | 需求 | 进入条件 |
|---|---|---|---|
| AM-501 | candidate | 多 Mac 状态同步 | 定义最小隐私安全协议 |
| AM-502 | candidate | Headless Agent 与自托管 Hub | V3 进入实施 |
| AM-503 | candidate | SSH/Tailscale 远端观察 | 本地状态模型稳定 |
| AM-504 | candidate | iPhone/Apple Watch 状态 | 同步协议稳定 |
| AM-505 | candidate | 硬件按键和状态灯联动 | 软件版形成稳定任务/动作模型 |

## 其他 Agent

| ID | 状态 | 需求 | 进入条件 |
|---|---|---|---|
| AM-601 | deferred | Claude Code | Codex V1 完成且抽象没有损害 Codex 体验 |
| AM-602 | deferred | OpenCode | 同上 |
| AM-603 | deferred | Gemini、Hermes、OpenClaw | 证明多 Agent 是核心需求 |

## 新需求模板

```markdown
| AM-XXX | candidate | 用户问题或能力描述 | 可以进入实现的客观条件 |
```

新增需求时同时记录：

- 来源：用户反馈、研究、Issue 或实现发现。
- 解决的用户问题。
- 为什么不进入当前版本。
- 依赖和风险。
