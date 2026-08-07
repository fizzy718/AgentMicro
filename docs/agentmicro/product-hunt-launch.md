# Product Hunt Launch Kit

This is the ready-to-paste launch copy and production brief for AgentMicro. It
deliberately uses only features that ship in the app today.

## Listing

**Name**

AgentMicro

**Tagline**

Live Codex task status in your macOS menu bar

**Short description**

Track parallel Codex tasks, projects, and results without reopening Codex.

**Product URL**

`https://agentmicro.cc`

Use the release link as the first link in the description or Maker Comment:
`https://github.com/fizzy718/AgentMicro/releases/latest`.

**Suggested topics**

macOS, Developer Tools, Productivity, Open Source

Choose the closest topics offered in the submission form. Do not add AI-agent
topics if they would suggest that AgentMicro itself runs or controls agents: it
observes Codex tasks only.

## Gallery and demo video

Use a clean, dedicated local demo profile with fictitious project and task
names. Never record customer repositories, prompts, source code, terminal
output, account names, or notifications.

| Asset | What it proves | Capture notes | Product Hunt caption |
| --- | --- | --- | --- |
| 1. Hero image | The entire product in one glance | Re-capture `agentmicro-menu.png` on a quiet desktop. Show at least two blue working tasks and a green unread result. | Your parallel Codex queue, always one click away. |
| 2. Status states | The five-color status language | Show blue thinking, green unread, orange needs input, red error, and white idle in the same menu. | Know which task is working, ready, blocked, or failed. |
| 3. Context | Project, duration, and fast mode | Show three neutral task names, distinct projects, durations, and one lightning badge. | The context you need before you switch back. |
| 4. Return flow | The deep link into Codex Desktop | A two-frame capture: select a row, then show that exact Codex conversation open. | Jump back to the exact Desktop task in one click. |
| 5. Privacy and control | The local-first boundary | Show the Task Display setting on project-only mode, plus the Enhanced Status Detection opt-in explanation. | Your prompts and task history stay on your Mac. |

The gallery should start with the menu image. Keep every frame close to 16:9,
use the same desktop wallpaper, and use concise English captions. The currently
checked-in screenshot is a good compositional reference, but re-capture it with
the final release build and sanitized names before launch.

### 37-second demo script

| Time | Screen action | On-screen text / voiceover |
| --- | --- | --- |
| 0–4 s | Codex has several task windows or threads running. | Running parallel Codex tasks? |
| 4–9 s | Click the AgentMicro menu-bar icon. | See the whole queue without reopening Codex. |
| 9–15 s | Hold on a menu with blue, green, orange, red, and white states. | Thinking. Result ready. Needs input. Error. Idle. |
| 15–21 s | Highlight project labels, live durations, and a fast-mode bolt. | Each task keeps its project, current-turn duration, and fast-mode signal. |
| 21–28 s | Select a task row and land in the matching Codex Desktop conversation. | One click returns to the right task. |
| 28–33 s | Open Task Display settings, selecting project-only mode. | Local-first. Read-only. No prompts or code uploaded. |
| 33–37 s | Return to the menu icon and logo. | AgentMicro — live Codex task status in your macOS menu bar. |

Use cursor highlights and 0.25–0.35 second cross-fades only. No stock footage,
no fake task states, and no spoken claim that the app controls or approves
Codex tasks.

## Maker Comment

> Hi Product Hunt! I built AgentMicro because I kept losing the thread when I had several Codex tasks running in parallel. The answers I needed were simple: Which task is still working? Which one finished while I was elsewhere? Which one needs my input?
>
> Codex already owns the work, so I did not want another dashboard, hosted task system, or automation layer. AgentMicro is a small, local-first macOS menu-bar companion that observes local Codex Desktop and CLI session metadata, puts active work first, and lets you return to the matching Desktop task with one click.
>
> The menu uses five deliberate states: blue for thinking, green for an unread result, orange for input needed, red for an error, and white for idle. It also shows the project, current-turn duration, and fast-mode badge. Base mode needs no Accessibility permission; optional enhanced detection is opt-in and never clicks, types, or approves anything for you.
>
> AgentMicro is free, open source, and independent. It does not upload prompts, responses, source code, command output, or task history. I would love to hear which signals help you supervise concurrent agent work without adding noise. Thanks for taking a look!

## Launch-day replies

**One-line invitation**

> I launched AgentMicro today: a local macOS menu-bar view for concurrent Codex task status. If you use Codex with several tasks at once, I would value your feedback in the Product Hunt comments.

**When someone asks how it works**

> It reads known local Codex process and session metadata, then reduces that evidence into five visible states. It is an observer, not an agent controller: it does not send messages, approve actions, or upload task content.

**When someone asks about privacy**

> The app is local-first and read-only. It does not upload prompts, code, responses, command output, or session files. Enhanced Status Detection is optional, only reads visible local accessibility labels, and never clicks or types.

**When someone asks whether it works with Codex CLI**

> Yes. AgentMicro observes local Codex Desktop and CLI tasks. The one-click return action is for Codex Desktop conversations.

Invite people to visit and comment on the launch. Do not ask for upvotes directly.

## Final pre-flight checklist

- [ ] Publish a signed, notarized release with a working DMG on GitHub Releases.
- [ ] Replace the five gallery images with final-build, sanitized captures.
- [ ] Record and trim the 37-second demo above; play it once with sound off to verify that the visual story is self-contained.
- [x] Deploy the landing page at `https://agentmicro.cc`; use it as the Product Hunt product URL.
- [ ] Verify every outbound link from the landing page and Product Hunt draft.
- [ ] Post the Maker Comment immediately after the listing goes live.
- [ ] Prepare a launch-day owner for comments during the first several hours.

Product Hunt recommends makers submit their own products. Its current launch
guide also says promotion can invite people to visit and comment, but cannot
ask for upvotes directly. See the [Product Hunt Launch Guide](https://www.producthunt.com/launch).
