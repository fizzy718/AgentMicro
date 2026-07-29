# AgentMicro 产品文档

这里是 AgentMicro 的产品事实源。项目讨论、需求变化和实现决策不能只保留在聊天、Issue 或代码差异里；结论需要回写到这里。

## 文档导航

- [产品定义](PRODUCT.zh-CN.md)：愿景、用户问题、产品原则与长期边界。
- [V1 规格](V1_SPEC.zh-CN.md)：首个可交付版本的范围、状态语义和验收标准。
- [产品路线图](ROADMAP.zh-CN.md)：阶段目标、进入下一阶段的条件和能力来源。
- [现有项目能力地图](CAPABILITY_MAP.zh-CN.md)：CodexBar、abtop、cc-switch、token-monitor 的能力与复用边界。
- [项目改动日志](PROJECT_LOG.zh-CN.md)：产品、架构和实现变化的连续记录。
- [未来需求池](BACKLOG.zh-CN.md)：尚未进入当前版本的需求、研究项和已知限制。

## 当前结论

AgentMicro V1 定义为：

> macOS 菜单栏里的 Codex 实时任务脉搏。

V1 是本地、只读、Codex-only 的任务观察器。它回答四个问题：

1. 当前有几个 Codex 任务？
2. 每个任务还在工作，还是已经停下来？
3. 当前正在执行什么？
4. 如何快速回到对应任务？

V1 不是 Token 用量监控器、Provider 切换器或任务控制器。

## 当前实现进度

截至 2026-07-28，M2 菜单产品化已经完成：

- 独立的 `AgentMicro` SwiftPM 可执行入口。
- 原生 macOS 菜单栏图标和即时展开菜单。
- 复用 `LocalAgentSessionScanner` 发现本机 Codex Desktop、CLI 和可识别的 IDE 会话。
- 增量读取 Codex rollout，处理半行、文件截断、轮转和异常 JSONL。
- 将事件归约为 Thinking、Executing、Waiting、Rate limited、Unknown、Done 六种状态。
- 配对普通、custom 和长时间运行工具调用，并显示脱敏后的最小当前动作。
- 仅展示 Codex，会话按 V1 状态优先级和最近活动时间排序。
- 默认使用项目名，避免直接暴露可能敏感的任务标题。
- 点击任务时复用 `SessionWindowFocuser` 尝试回到对应窗口。
- 有进程时每 2 秒、无进程时每 15 秒刷新；打开菜单时立即异步刷新。
- 设置页支持开机启动、三种任务名称模式和最近完成任务开关。
- 隐私默认值为“仅项目名”，最近完成任务默认显示并固定保留 5 分钟。
- 提供本地签名的 `AgentMicro.app` 打包、启动和停止命令。

下一步是 M3：在真实 Codex Desktop/CLI 多任务场景中验证状态时效、任务归属和点击返回，并修正性能或误报。没有可靠 owner 的近期 Desktop rollout 目前保持 `Unknown`，不会通过 app-server PID 猜测归属。

## 开发验证

为避免 AgentMicro 的开发循环解析上游 CodexBar 使用的 Sparkle 二进制制品，使用独立构建模式：

```bash
AGENTMICRO_BUILD_ONLY=1 swift run --disable-automatic-resolution AgentMicro
AGENTMICRO_BUILD_ONLY=1 swift test --disable-automatic-resolution --filter AgentMicro
```

`--disable-automatic-resolution` 用于保持上游 `Package.resolved` 不变。

打包并启动可点击的菜单栏应用：

```bash
make agentmicro-package
make agentmicro-start
make agentmicro-stop
```

本地开发包使用 ad-hoc 签名，输出为项目根目录的 `AgentMicro.app`。面向外部用户分发所需的 Developer ID 签名、公证和更新机制属于后续发布工程。

## 维护约定

每次工作结束前，按实际变化更新相应文档：

- 产品定位、用户行为或版本范围变化：更新 `PRODUCT`、`V1_SPEC` 或 `ROADMAP`。
- 已完成的产品、架构或代码变化：在 `PROJECT_LOG` 增加一条带日期的记录。
- 新想法、暂缓项和外部限制：进入 `BACKLOG`，不要悄悄扩大当前版本。
- 新研究结论或第三方能力变化：更新 `CAPABILITY_MAP`，并标明结论是可直接复用、仅供参考还是暂不可用。

文档应描述当前事实。已经失效的计划要删除、改写或明确标记为历史结论。
