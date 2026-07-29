# AgentMicro 产品文档

这里是 AgentMicro 的产品事实源。项目讨论、需求变化和实现决策不能只保留在聊天、Issue 或代码差异里；结论需要回写到这里。

## 文档导航

- [产品定义](PRODUCT.zh-CN.md)：愿景、用户问题、产品原则与长期边界。
- [V1 规格](V1_SPEC.zh-CN.md)：首个可交付版本的范围、状态语义和验收标准。
- [产品路线图](ROADMAP.zh-CN.md)：阶段目标、进入下一阶段的条件和能力来源。
- [现有项目能力地图](CAPABILITY_MAP.zh-CN.md)：CodexBar、abtop、cc-switch、token-monitor 的能力与复用边界。
- [项目改动日志](PROJECT_LOG.zh-CN.md)：产品、架构和实现变化的连续记录。
- [未来需求池](BACKLOG.zh-CN.md)：尚未进入当前版本的需求、研究项和已知限制。
- [发布与在线更新](RELEASING.zh-CN.md)：AgentMicro 独立签名、公证、appcast 和发布流程。

## 当前结论

AgentMicro V1 定义为：

> macOS 菜单栏里的 Codex 实时任务脉搏。

V1 是本地、只读、Codex-only 的任务观察器。它回答四个问题：

1. 当前有几个 Codex 任务？
2. 每个任务还在工作，还是已经停下来？
3. 哪些任务已经完成、仍待查看？
4. 如何快速回到对应任务？

V1 不是 Token 用量监控器、Provider 切换器或任务控制器。

## 当前实现进度

截至 2026-07-29，M3 真实场景验证已经完成，并已采用 Codex Micro 状态与菜单设计：

- 独立的 `AgentMicro` SwiftPM 可执行入口。
- 原生 macOS 菜单栏图标和即时展开菜单。
- 复用 `LocalAgentSessionScanner` 发现本机 Codex Desktop、CLI 和可识别的 IDE 会话。
- 增量读取 Codex rollout，处理半行、文件截断、轮转和异常 JSONL。
- 将事件归约为 Codex Micro 的 Idle、Unread chat、Thinking、Needs approval or answer、
  Error 五态；证据不足时内部保留 Unknown，但对外使用 Idle 白色，不增加第六种状态色。
- 配对普通、custom 和长时间运行工具调用；当前动作只用于状态诊断，不进入菜单。
- 仅展示 Codex；正在工作的任务置顶，各组内按状态最后变化时间排序。菜单默认显示
  6 个任务，可在设置中选择 1–20 个。
- 菜单栏图标由上下两排、每排 3 个无边框圆角矩形组成；六块与菜单排序最前的六个任务
  使用同一状态色。任务工作时，各块保留自身颜色，以每帧 70ms 按上排左到右、下排
  右到左的环形顺序依次呼吸，不再用白色高亮。
- 菜单顶部标题使用正常高对比度标签色；任务标题采用 13pt 菜单字体。
- 展开菜单使用与 CodexBar 基础卡片一致的 310pt 宽度。
- 菜单任务行左侧使用同色无边框圆角矩形；项目名按名称模式显示在标题下方，右侧固定
  显示当前单个 turn 的秒级时长，菜单展开期间工作任务每秒更新。rollout 的
  `service_tier` 为 `priority` 时，时长后显示闪电，`default` 不显示。未读只由左侧
  绿色状态块表达，不再显示右侧绿点。
- 默认名称模式为“任务标题 + 项目名”；“任务标题”模式不再重复显示项目名，
  “仅项目名”继续作为更保守的隐私选项。
- 点击 Desktop 任务时使用 `codex://threads/<session-id>` 直接切换到对应会话，
  窗口匹配与应用激活作为降级。
- 监听会话目录和已发现 rollout，约 200ms 防抖刷新；Codex Desktop 运行、任务工作中
  或任务有独立进程时每 2 秒兜底刷新，其余时间每 5 秒刷新。
- 菜单打开、任务点击和已知 rollout 变化时优先增量对账文件尾部，并进行有界快速补扫，
  不等待完整进程、SQLite 和目录发现。
- 设置页支持跟随系统或 23 种界面语言、开机启动、三种任务名称模式、可直接键入并可
  步进调节的 1–20 个任务显示数量、最近完成任务和自动检查更新开关。
- 菜单和设置语言目录与 CodexBar 对齐：English、简体中文、繁體中文、Español、
  Català、Português (Brasil)、Deutsch、Svenska、Français、Italiano、Nederlands、
  日本語、한국어、Tiếng Việt、Türkçe、Українська、Русский、Bahasa Indonesia、
  Polski、العربية、فارسی、ไทย和 Galego。默认跟随 macOS 系统语言，应用覆盖不会修改
  全局 `AppleLanguages`。
- 复用 CodexBar 的 Sparkle 运行时，但已经具备 AgentMicro 独立的 universal 构建、
  Developer ID 签名、公证、Ed25519 appcast 和 GitHub Release 发布脚本；本地未配置
  feed 的开发包仍明确显示更新不可用。
- 默认显示“任务标题 + 项目名”和 6 个任务；最近完成任务默认显示并固定保留 24 小时。
- 提供本地签名的 `AgentMicro.app` 打包、启动和停止命令。
- 使用 rollout 生命周期识别没有独立 PID 的 Desktop 任务，不再把活跃主任务长期显示为 `Unknown`。
- 默认排除普通 subagent；guardian 只用于找回仍在活动的真实父 rollout，不单独显示。
  同一目录并发多个 CLI 时停止猜测 PID 所有权，避免任务串线。
- 支持识别 Codex Desktop 和 ChatGPT 应用内置 CLI，以及 `codex exec -C/--cd` 指定的工作目录。

M3 已用真实 Codex Desktop 主任务与只读 Codex CLI 任务同时运行验证：两个任务独立出现、CLI 当前工具动作和结束状态正确、单次观察约 0.39 秒，配合 2 秒轮询满足 3 秒目标。下一步不自动扩大 V1 范围；优先处理发布工程，或从路线图选择 V1.1。

## 开发验证

AgentMicro 的开发循环仍使用独立构建模式，只构建任务观察器及其所需的 Sparkle 更新依赖：

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

本地开发包使用 ad-hoc 签名，输出为项目根目录的 `AgentMicro.app`。打包脚本会嵌入
本地化资源和 Sparkle.framework；只有同时提供 `AGENTMICRO_FEED_URL` 与
`AGENTMICRO_PUBLIC_ED_KEY` 才会写入更新配置。正式发布入口为
`./Scripts/release_agentmicro.sh`，具体配置和验收步骤见
[发布与在线更新](RELEASING.zh-CN.md)。源码仓库已经公开在
[`fizzy718/AgentMicro`](https://github.com/fizzy718/AgentMicro)，但正式证书和专属
密钥尚未配置，因此当前开发包不会伪装成可在线更新的正式包。

只输出一次隐私安全的任务诊断快照，或验证某个任务的返回路径：

```bash
AgentMicro.app/Contents/MacOS/AgentMicro --diagnose-once
AgentMicro.app/Contents/MacOS/AgentMicro --diagnose-focus <session-id>
```

诊断只包含任务 ID、项目名、来源、状态、当前动作、PID、活动时间和 rollout 文件名，不输出 Prompt、命令结果或文件内容。

## 维护约定

每次工作结束前，按实际变化更新相应文档：

- 产品定位、用户行为或版本范围变化：更新 `PRODUCT`、`V1_SPEC` 或 `ROADMAP`。
- 已完成的产品、架构或代码变化：在 `PROJECT_LOG` 增加一条带日期的记录。
- 新想法、暂缓项和外部限制：进入 `BACKLOG`，不要悄悄扩大当前版本。
- 新研究结论或第三方能力变化：更新 `CAPABILITY_MAP`，并标明结论是可直接复用、仅供参考还是暂不可用。

文档应描述当前事实。已经失效的计划要删除、改写或明确标记为历史结论。
