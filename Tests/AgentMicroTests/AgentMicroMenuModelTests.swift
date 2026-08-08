import AppKit
import CodexBarCore
import Foundation
import Testing
@testable import AgentMicro

struct AgentMicroMenuModelTests {
    @Test
    func `menu keeps only Codex sessions and puts working sessions first`() {
        let now = Date(timeIntervalSince1970: 10000)
        let sessions = [
            Self.session(
                id: "idle",
                provider: .codex,
                source: .cli,
                state: .idle,
                projectName: "idle-project",
                activity: now),
            Self.session(
                id: "claude",
                provider: .claude,
                source: .cli,
                state: .active,
                projectName: "claude-project",
                activity: now),
            Self.session(
                id: "active",
                provider: .codex,
                source: .desktopApp,
                state: .active,
                projectName: "active-project",
                activity: now.addingTimeInterval(-120)),
        ]

        let tasks = [
            Self.observation(session: sessions[0], state: .unread),
            Self.observation(session: sessions[1], state: .thinking),
            Self.observation(session: sessions[2], state: .thinking),
        ]
        let rows = AgentMicroMenuModel.rows(from: tasks, now: now)

        #expect(rows.map(\.title) == ["active-project", "idle-project"])
        #expect(rows.map(\.subtitle) == ["", ""])
        #expect(rows.map(\.duration) == ["3m 0s", "1m 0s"])
        #expect(rows.map(\.state) == [.thinking, .unread])
        #expect(rows.map(\.slotIndex) == [0, 1])
    }

    @Test
    func `default title prefers the project name to protect thread-title privacy`() {
        let session = Self.session(
            id: "019f-private-thread",
            provider: .codex,
            source: .desktopApp,
            state: .active,
            projectName: "AgentMicro",
            sessionName: "Sensitive customer migration",
            activity: nil)

        #expect(AgentMicroMenuModel.title(for: session) == "AgentMicro")
    }

    @Test
    func `title modes preserve privacy defaults and fall back safely`() {
        let named = Self.session(
            id: "019f-named",
            provider: .codex,
            source: .ide,
            state: .idle,
            projectName: nil,
            sessionName: "Fix task scanner",
            activity: nil)
        let unidentified = Self.session(
            id: "019f1234-aaaa-bbbb",
            provider: .codex,
            source: .unknown,
            state: .idle,
            projectName: nil,
            activity: nil)

        #expect(AgentMicroMenuModel.title(for: named) == "019f")
        #expect(AgentMicroMenuModel.title(for: named, mode: .taskTitle) == "Fix task scanner")
        #expect(AgentMicroMenuModel.title(for: unidentified) == "019f1234")
    }

    @Test
    func `task title and combined modes render different project subtitles`() {
        let now = Date(timeIntervalSince1970: 10000)
        let session = Self.session(
            id: "named",
            projectName: "AgentMicro",
            sessionName: "Improve settings",
            activity: now)
        let task = Self.observation(session: session, state: .thinking)
        let titleOnly = AgentMicroMenuModel.rows(
            from: [task],
            preferences: AgentMicroPreferences(taskNameMode: .taskTitle),
            now: now)
        let combined = AgentMicroMenuModel.rows(
            from: [task],
            preferences: AgentMicroPreferences(taskNameMode: .taskTitleAndProject),
            now: now)

        #expect(titleOnly.first?.title == "Improve settings")
        #expect(titleOnly.first?.subtitle.isEmpty == true)
        #expect(combined.first?.title == "Improve settings")
        #expect(combined.first?.subtitle == "AgentMicro")
    }

    @Test
    func `duration label uses exact elapsed seconds without activity age`() {
        let now = Date(timeIntervalSince1970: 10000)
        let minute = Self.observation(
            session: Self.session(startedAt: now.addingTimeInterval(-5), activity: now),
            state: .thinking)
        let minutes = Self.observation(
            session: Self.session(startedAt: now.addingTimeInterval(-125), activity: now),
            state: .thinking)
        let hours = Self.observation(
            session: Self.session(startedAt: now.addingTimeInterval(-7507), activity: now),
            state: .thinking)

        #expect(AgentMicroMenuModel.durationLabel(for: minute, now: now) == "5s")
        #expect(AgentMicroMenuModel.durationLabel(for: minutes, now: now) == "2m 5s")
        #expect(AgentMicroMenuModel.durationLabel(for: hours, now: now) == "2h 5m 7s")
        #expect(AgentMicroMenuModel.durationUpdateInterval == 1)
    }

    @Test
    func `running duration advances while stopped duration stays frozen`() {
        let now = Date(timeIntervalSince1970: 10000)
        let runStartedAt = now.addingTimeInterval(-600)
        let lastEventAt = now.addingTimeInterval(-300)
        let running = Self.observation(
            session: Self.session(startedAt: now.addingTimeInterval(-86400), activity: lastEventAt),
            state: .thinking,
            runStartedAt: runStartedAt)
        let stopped = Self.observation(
            session: Self.session(startedAt: now.addingTimeInterval(-86400), activity: lastEventAt),
            state: .unread,
            runStartedAt: runStartedAt)

        #expect(AgentMicroMenuModel.durationLabel(for: running, now: now) == "10m 0s")
        #expect(AgentMicroMenuModel.durationLabel(
            for: running,
            now: now.addingTimeInterval(122)) == "12m 2s")
        #expect(AgentMicroMenuModel.durationLabel(for: stopped, now: now) == "5m 0s")
        #expect(AgentMicroMenuModel.durationLabel(
            for: stopped,
            now: now.addingTimeInterval(122)) == "5m 0s")
    }

    @Test
    func `task order follows state changes within the same activity group`() {
        let now = Date(timeIntervalSince1970: 10000)
        let incidentalEvent = Self.observation(
            session: Self.session(id: "incidental", activity: now),
            state: .idle,
            stateChangedAt: now.addingTimeInterval(-100))
        let recentStateChange = Self.observation(
            session: Self.session(id: "changed", activity: now.addingTimeInterval(-50)),
            state: .unread,
            stateChangedAt: now.addingTimeInterval(-10))

        let rows = AgentMicroMenuModel.rows(
            from: [incidentalEvent, recentStateChange],
            now: now)

        #expect(rows.map(\.sessionKey) == [
            recentStateChange.sessionKey,
            incidentalEvent.sessionKey,
        ])
    }

    @Test
    func `menu follows recent order and preserves all Codex Micro states`() {
        let now = Date(timeIntervalSince1970: 10000)
        let tasks = [
            Self.observation(
                session: Self.session(id: "unread", activity: now.addingTimeInterval(-5)),
                state: .unread),
            Self.observation(
                session: Self.session(id: "idle", activity: now.addingTimeInterval(-4)),
                state: .idle),
            Self.observation(
                session: Self.session(id: "thinking", activity: now),
                state: .thinking,
                currentAction: "exec_command · swift test"),
            Self.observation(
                session: Self.session(id: "input", activity: now.addingTimeInterval(-1)),
                state: .requiresInput),
            Self.observation(
                session: Self.session(id: "error", activity: now.addingTimeInterval(-2)),
                state: .error),
            Self.observation(
                session: Self.session(id: "unknown", activity: now.addingTimeInterval(-3)),
                state: .unknown),
        ]

        let rows = AgentMicroMenuModel.rows(from: tasks, now: now)

        #expect(rows.map(\.state) == [.thinking, .requiresInput, .error, .unknown, .idle, .unread])
        #expect(rows.allSatisfy { !$0.subtitle.contains("Codex") })
        #expect(rows.allSatisfy { !$0.subtitle.contains($0.state.displayName) })
        #expect(rows.map(\.slotIndex) == [0, 1, 2, 3, 4, 5])
    }

    @Test
    func `preferences hide completed tasks and include project only when requested`() {
        let now = Date(timeIntervalSince1970: 10000)
        let titled = Self.session(
            id: "titled",
            projectName: "AgentMicro",
            sessionName: "Polish settings",
            startedAt: now.addingTimeInterval(-300),
            activity: now)
        let tasks = [
            Self.observation(session: titled, state: .idle),
            Self.observation(session: Self.session(id: "done", activity: now), state: .unread),
        ]

        let rows = AgentMicroMenuModel.rows(
            from: tasks,
            preferences: AgentMicroPreferences(
                taskNameMode: .taskTitleAndProject,
                showRecentlyCompleted: false),
            now: now)

        #expect(rows.count == 1)
        #expect(rows[0].title == "Polish settings")
        #expect(rows[0].subtitle == "AgentMicro")
        #expect(rows[0].duration == "5m 0s")
    }

    @Test
    func `completed rows use the recent completion label`() {
        let now = Date(timeIntervalSince1970: 10000)
        let task = Self.observation(
            session: Self.session(
                id: "done",
                projectName: "AgentMicro",
                startedAt: now.addingTimeInterval(-180),
                activity: now.addingTimeInterval(-60)),
            state: .unread)

        let row = AgentMicroMenuModel.rows(from: [task], now: now).first

        #expect(row?.title == "AgentMicro")
        #expect(row?.subtitle.isEmpty == true)
        #expect(row?.duration == "2m 0s")
        #expect(row?.state == .unread)

        let readRow = AgentMicroMenuModel.rows(
            from: [task],
            readSessionKeys: [task.sessionKey],
            now: now).first
        #expect(readRow?.state == .idle)
    }

    @Test
    @MainActor
    func `menu task limit is configurable above the six icon slots`() {
        let now = Date(timeIntervalSince1970: 10000)
        let tasks = (0..<10).map { index in
            Self.observation(
                session: Self.session(
                    id: "task-\(index)",
                    projectName: "project-\(index)",
                    activity: now.addingTimeInterval(TimeInterval(-index))),
                state: .idle)
        }

        let rows = AgentMicroMenuModel.rows(
            from: tasks,
            preferences: AgentMicroPreferences(taskDisplayLimit: 8),
            now: now)

        #expect(rows.count == 8)
        #expect(rows.map(\.title) == (0..<8).map { "project-\($0)" })
        #expect(rows.map(\.slotIndex) == Array(0..<8))
        #expect(AgentMicroStatusIcon.maximumTrackedTasks == 6)
        #expect(AgentMicroStatusIcon.blockSize.width > AgentMicroStatusIcon.blockSize.height)
    }

    @Test
    func `codex Micro states expose the five official website colors`() {
        #expect(CodexTaskState.idle.colorHex == 0xFFFFFF)
        #expect(CodexTaskState.unread.colorHex == 0x9BF396)
        #expect(CodexTaskState.thinking.colorHex == 0x9CD5FE)
        #expect(CodexTaskState.requiresInput.colorHex == 0xFFD0B8)
        #expect(CodexTaskState.error.colorHex == 0xFF7373)
        #expect(CodexTaskState.unknown.colorHex == 0xFFFFFF)
    }

    @Test
    @MainActor
    func `desktop task focus uses the official thread deep link`() {
        let desktop = Self.session(
            id: "019f-thread",
            provider: .codex,
            source: .desktopApp,
            activity: nil)
        let cli = Self.session(
            id: "019f-cli",
            provider: .codex,
            source: .cli,
            activity: nil)

        #expect(SessionWindowFocuser.codexThreadURL(for: desktop)?.absoluteString ==
            "codex://threads/019f-thread")
        #expect(SessionWindowFocuser.codexThreadURL(for: cli) == nil)
        #expect(SessionWindowFocuser.codexApplicationBundleIdentifier == "com.openai.codex")
    }

    @Test
    @MainActor
    func `status logo maps task order across the top then reverses across the bottom`() {
        #expect(AgentMicroStatusIcon.slotLayout == [
            AgentMicroIconSlot(column: 0, row: 0),
            AgentMicroIconSlot(column: 1, row: 0),
            AgentMicroIconSlot(column: 2, row: 0),
            AgentMicroIconSlot(column: 2, row: 1),
            AgentMicroIconSlot(column: 1, row: 1),
            AgentMicroIconSlot(column: 0, row: 1),
        ])
    }

    @Test
    @MainActor
    func `status logo breathes attention states in task order`() {
        let states: [CodexTaskState] = [.thinking, .idle, .unread, .requiresInput, .error, .unknown]
        let animatedSlotIndices = AgentMicroStatusIcon.animatedSlotIndices(for: states)
        let middleOfFirstPulse = AgentMicroStatusIcon.animationFramesPerSlot / 2
        let startOfSecondPulse = AgentMicroStatusIcon.animationFramesPerSlot
        let middleOfSecondPulse = startOfSecondPulse + middleOfFirstPulse

        #expect(animatedSlotIndices == [0, 2, 3, 4])
        #expect(AgentMicroStatusIcon.animationFrameCount(for: states) ==
            4 * AgentMicroStatusIcon.animationFramesPerSlot)
        #expect(AgentMicroStatusIcon.shouldAnimate(.thinking))
        #expect(AgentMicroStatusIcon.shouldAnimate(.unread))
        #expect(AgentMicroStatusIcon.shouldAnimate(.requiresInput))
        #expect(AgentMicroStatusIcon.shouldAnimate(.error))
        #expect(!AgentMicroStatusIcon.shouldAnimate(.idle))
        #expect(!AgentMicroStatusIcon.shouldAnimate(.unknown))
        #expect(abs(AgentMicroStatusIcon.opacity(
            forSlotAt: 0,
            animatedSlotIndices: animatedSlotIndices,
            animationPhase: middleOfFirstPulse) - 0.45) < 0.0001)
        #expect(AgentMicroStatusIcon.opacity(
            forSlotAt: 1,
            animatedSlotIndices: animatedSlotIndices,
            animationPhase: middleOfFirstPulse) == 1)
        #expect(AgentMicroStatusIcon.opacity(
            forSlotAt: 0,
            animatedSlotIndices: animatedSlotIndices,
            animationPhase: middleOfSecondPulse) == 1)
        #expect(abs(AgentMicroStatusIcon.opacity(
            forSlotAt: 2,
            animatedSlotIndices: animatedSlotIndices,
            animationPhase: middleOfSecondPulse) - 0.45) < 0.0001)
        #expect(AgentMicroStatusIcon.opacity(
            forSlotAt: 0,
            animatedSlotIndices: animatedSlotIndices,
            animationPhase: nil) == 1)
        #expect(AgentMicroStatusIcon.opacity(
            forSlotAt: 0,
            animatedSlotIndices: [],
            animationPhase: middleOfFirstPulse) == 1)
        #expect(AgentMicroStatusIcon.animationFrameInterval == 0.25)
        #expect(AgentMicroStatusIcon.animationTimerTolerance == 0.05)
        #expect(AgentMicroStatusIcon.statusItemImages(states: states, animated: false).count == 1)
        #expect(AgentMicroStatusIcon.statusItemImages(states: states, animated: true).count ==
            4 * AgentMicroStatusIcon.animationFramesPerSlot)
    }

    @Test
    @MainActor
    func `menu typography keeps the header bright and task titles compact`() {
        #expect(AgentMicroMenuLayout.width == 310)
        #expect(AgentMicroMenuLayout.horizontalPadding == 20)
        #expect(AgentMicroMenuLayout.selectionHorizontalInset == 5)
        #expect(AgentMicroMenuLayout.selectionCornerRadius == 7)
        #expect(AgentMicroMenuHeaderView.titleColor == NSColor.labelColor)
        #expect(AgentMicroMenuHeaderView.titleFont.pointSize == 13)
        #expect(AgentMicroTaskMenuItemView.titleFontSize == 13)
    }

    @Test
    @MainActor
    func `visible task row accepts live duration updates`() {
        let row = AgentMicroMenuRow(
            slotIndex: 0,
            sessionKey: "running",
            title: "Running task",
            subtitle: "Project",
            duration: "4s",
            state: .thinking,
            usesFastModel: true)
        let view = AgentMicroTaskMenuItemView(row: row, onSelect: {})

        view.updateDuration("5s")

        #expect(view.sessionKey == "running")
        #expect(view.durationForTesting == "5s")
        #expect(view.showsFastModelIndicatorForTesting)

        let standardRow = AgentMicroMenuRow(
            slotIndex: 1,
            sessionKey: "standard",
            title: "Standard task",
            subtitle: "Project",
            duration: "5s",
            state: .thinking,
            usesFastModel: false)
        let standardView = AgentMicroTaskMenuItemView(row: standardRow, onSelect: {})
        #expect(!standardView.showsFastModelIndicatorForTesting)
    }

    @Test
    @MainActor
    func `task row hover is exclusive within the menu`() {
        let menu = NSMenu()
        let firstRow = AgentMicroMenuRow(
            slotIndex: 0,
            sessionKey: "first",
            title: "First",
            subtitle: "Project",
            duration: "1m 0s",
            state: .thinking,
            usesFastModel: false)
        let secondRow = AgentMicroMenuRow(
            slotIndex: 1,
            sessionKey: "second",
            title: "Second",
            subtitle: "Project",
            duration: "1m 0s",
            state: .unread,
            usesFastModel: false)
        let firstView = AgentMicroTaskMenuItemView(row: firstRow, onSelect: {})
        let secondView = AgentMicroTaskMenuItemView(row: secondRow, onSelect: {})
        let firstItem = NSMenuItem()
        firstItem.view = firstView
        menu.addItem(firstItem)
        let secondItem = NSMenuItem()
        secondItem.view = secondView
        menu.addItem(secondItem)

        firstView.activateExclusiveHover()
        secondView.activateExclusiveHover()

        #expect(!firstView.isHoveredForTesting)
        #expect(secondView.isHoveredForTesting)
    }

    private static func observation(
        session: AgentSession,
        state: CodexTaskState,
        currentAction: String? = nil,
        runStartedAt: Date? = nil,
        stateChangedAt: Date? = nil,
        usesFastModel: Bool = false) -> CodexTaskObservation
    {
        CodexTaskObservation(
            session: session,
            state: state,
            currentAction: currentAction,
            lastEventAt: session.lastActivityAt,
            runStartedAt: runStartedAt ?? session.startedAt,
            stateChangedAt: stateChangedAt ?? session.lastActivityAt,
            usesFastModel: usesFastModel)
    }

    private static func session(
        id: String = "session",
        provider: AgentSession.Provider = .codex,
        source: AgentSession.Source = .cli,
        state: AgentSession.State = .active,
        projectName: String? = "project",
        sessionName: String? = nil,
        startedAt: Date? = nil,
        activity: Date?) -> AgentSession
    {
        AgentSession(
            id: id,
            provider: provider,
            source: source,
            state: state,
            pid: nil,
            cwd: projectName.map { "/tmp/\($0)" },
            projectName: projectName,
            sessionName: sessionName,
            startedAt: startedAt ?? activity?.addingTimeInterval(-60),
            lastActivityAt: activity,
            transcriptPath: nil,
            host: "local")
    }
}
