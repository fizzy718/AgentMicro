# AgentMicro Mac App Store Metadata

This file is submission-ready copy for version `0.1.4 (5)`.

## Shared App Information

- Name: `AgentMicro`
- Bundle ID: use the registered production identifier; it must match the provisioning profile and packaged app.
- SKU: `agentmicro-macos`
- Primary category: Developer Tools
- Secondary category: Productivity
- Price: Free
- Copyright: `2026 Xizhen Information Technology (wuxi) Co., Ltd`
- Marketing URL: `https://agentmicro.cc`
- Support URL: `https://github.com/fizzy718/AgentMicro/discussions`
- Privacy Policy URL: `https://agentmicro.cc/privacy.html`
- App privacy: `No, we do not collect data from this app.`
- In-app purchases: None
- Advertising: None

## English (U.S.)

- Subtitle: `Live Codex Task Status`
- Promotional text: `See thinking, unread, blocked, error, and idle Codex tasks in your menu bar—without uploading task data.`
- Keywords: `codex,developer,tasks,status,menu bar,productivity,monitor,local,workflow`
- What's New: `Initial Mac App Store release. Authorize your local Codex data folder once to observe task state from the menu bar with a sandboxed, read-only workflow.`

Description:

```text
AgentMicro is a local-first macOS menu bar companion for people running several Codex tasks at once.

Six compact status lights and a focused task menu show which work is thinking, ready with an unread result, waiting for input, stopped by an error, or idle. Working tasks stay first, and each row can show its project, current-turn duration, and fast-mode indicator.

Open the matching Codex Desktop conversation directly from the menu. Optional Enhanced Status Detection can recognize the selected Codex task and visible approval or error controls after you explicitly grant Accessibility permission. It reads only; it never clicks, types, approves, or sends content.

The Mac App Store edition is sandboxed. On first launch, choose your local Codex data folder (normally ~/.codex) in the macOS folder picker. AgentMicro stores a read-only permission on your Mac and uses authorized rollout and thread metadata to derive task state.

Privacy by design:
• No account
• No analytics or tracking
• No task-data uploads
• No Keychain credential access
• Works offline

AgentMicro is an independent, community-maintained project. It is not affiliated with or endorsed by OpenAI.
```

## Simplified Chinese

- Subtitle: `菜单栏里的 Codex 任务状态`
- Promotional text: `在菜单栏查看思考中、未读、等待输入、错误和空闲的 Codex 任务，全程不上传任务数据。`
- Keywords: `Codex,开发者,任务,状态,菜单栏,效率,监控,本地,工作流`
- What's New: `首次登陆 Mac App Store。只需授权一次本地 Codex 数据文件夹，即可通过沙盒化、只读的方式在菜单栏观察任务状态。`

Description:

```text
AgentMicro 是一款本地优先的 macOS 菜单栏工具，适合同时运行多个 Codex 任务的用户。

六个紧凑状态灯和任务菜单会显示哪些任务正在思考、已有未读结果、正在等待输入、因错误停止或处于空闲。运行中的任务优先显示，每行还可以显示项目、当前轮次时长和快速模式标记。

点击任务即可打开对应的 Codex Desktop 对话。可选的“增强状态识别”仅在你主动授予辅助功能权限后，识别当前选中的 Codex 任务以及可见的批准或错误控件。它只读取，不会点击、输入、批准或发送任何内容。

Mac App Store 版本已启用沙盒。首次启动时，请在 macOS 文件夹选择器中选择本地 Codex 数据文件夹（通常为 ~/.codex）。AgentMicro 会在本机保存只读授权，并根据获准访问的 rollout 和线程元数据推导任务状态。

隐私设计：
• 无需账号
• 无分析或跟踪
• 不上传任务数据
• 不读取钥匙串凭据
• 可离线使用

AgentMicro 是独立的社区维护项目，与 OpenAI 不存在隶属关系，也未获得其官方背书。
```

## Review Notes

```text
AgentMicro is a read-only menu bar companion for the separately installed Codex Desktop/CLI product.

First-launch review flow:
1. Launch AgentMicro; its Settings window opens to General.
2. Select “Choose Codex Data Folder…”. The standard macOS open panel displays hidden files.
3. Select ~/.codex (or another CODEX_HOME containing sessions, state_5.sqlite, or .codex-global-state.json) and choose Authorize.
4. Start or resume a Codex Desktop/CLI task. AgentMicro reads only files within the authorized folder and displays the resulting state in its menu bar item.
5. Click a Desktop task row to open codex://threads/<thread-id> in Codex.

The app has no login, account, purchases, analytics, tracking, or remote task service. It does not collect data. Enhanced Status Detection is optional, disabled by default, and requests Accessibility access only when the reviewer enables it. The App Store binary contains no Sparkle framework or external update feed; updates are delivered by the Mac App Store.

Because Codex is an external companion dependency, the built-in Guide remains reviewable without Codex and explains every visible state. No private test account is required.
```

## Screenshot Requirements

- Supply one to ten PNG or JPEG screenshots with no alpha channel.
- Every Mac screenshot must use one accepted 16:10 size: 1280×800, 1440×900, 2560×1600, or 2880×1800.
- Capture the distribution-equivalent App Store build with fictitious task and project names.
- Recommended set: menu with mixed states; General page showing read-only folder access; Guide with all five states;
  Task Display settings; menu with a selected Desktop task.

## Account-Owner Checklist

- Confirm agreements, tax/banking, and DSA trader status.
- Complete the post-January-2026 age-rating questionnaire accurately; AgentMicro contains no gambling, violence,
  sexual content, messaging, advertising, or unrestricted web access.
- Publish the no-data-collected App Privacy response and privacy-policy URL.
- Verify the legal entity and contact details before submission.
- Attach the processed build, screenshots, review notes, and export-compliance answer, then submit for review.
