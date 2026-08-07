# AgentMicro Demo Capture Guide

This workflow produces the 8–15 second silent GIF used at the top of the
GitHub README and in directory submissions. Record from the final signed build,
not a development build.

## Prepare a safe demo scene

1. Use a dedicated macOS account or a clean Codex profile.
2. Use only fictitious project and task names, such as `Northstar`, `Atlas`,
   `Check release notes`, and `Review menu states`.
3. Create at least two harmless Codex tasks, then wait until the menu shows a
   blue working task and a green unread result. If an input-needed state is
   available, include it; do not manufacture errors or approvals merely for the
   recording.
4. In AgentMicro, use a display mode that exposes only safe labels. Turn off
   notifications and hide unrelated menu-bar items.

## Record on macOS

1. Open the signed AgentMicro release build and position Codex behind the menu
   bar. Keep the desktop clear.
2. Press `Shift` + `Command` + `5`, choose **Record Selected Portion**, and
   select a 16:9 region around the menu bar and the top of Codex.
3. In **Options**, set the microphone to **None**, save to Desktop, and leave
   pointer-click highlighting off unless it helps explain the menu click.
4. Record this short sequence:
   - Open the AgentMicro menu and pause for two seconds on the task states.
   - Move over a row so the project, duration, and fast-mode badge are legible.
   - Click one safe Desktop task and show that exact conversation opening.
   - End back on AgentMicro for one second.
5. Stop the recording from the menu bar. In QuickTime Player, use **Edit →
   Trim** to remove the first and last second, then export at 1080p.

## Publish the GIF

Convert the trimmed MP4 to a 960 px-wide GIF with a short loop. Inspect every
frame at full size for task titles, project paths, notification text, account
names, and source code before committing it as `docs/agentmicro-demo.gif`.
Keep the MP4 out of the repository unless it is deliberately offered as a
separate release asset.

Do not replace this workflow with an animated static screenshot. The GIF should
show actual AgentMicro behavior, while retaining the product's local-first and
read-only boundary.
