@testable import AgentMicro
import CodexBarCore
import Foundation
import Testing

struct AgentMicroMenuModelTests {
    @Test
    func `menu keeps only Codex sessions and sorts active sessions first`() {
        let now = Date(timeIntervalSince1970: 10000)
        let sessions = [
            Self.session(
                id: "idle",
                provider: .codex,
                source: .cli,
                state: .idle,
                projectName: "idle-project",
                activity: now.addingTimeInterval(-10),
            ),
            Self.session(
                id: "claude",
                provider: .claude,
                source: .cli,
                state: .active,
                projectName: "claude-project",
                activity: now,
            ),
            Self.session(
                id: "active",
                provider: .codex,
                source: .desktopApp,
                state: .active,
                projectName: "active-project",
                activity: now.addingTimeInterval(-20),
            )
        ]

        let tasks = [
            Self.observation(session: sessions[0], state: .done),
            Self.observation(session: sessions[1], state: .thinking),
            Self.observation(session: sessions[2], state: .executing)
        ]
        let rows = AgentMicroMenuModel.rows(from: tasks, now: now)

        #expect(rows.map(\.title) == ["active-project", "Recently completed: idle-project"])
        #expect(rows[0].subtitle == "Executing · Codex App · 20s")
        #expect(rows[1].subtitle == "Done · Codex CLI · 10s ago")
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
            activity: nil,
        )

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
            activity: nil,
        )
        let unidentified = Self.session(
            id: "019f1234-aaaa-bbbb",
            provider: .codex,
            source: .unknown,
            state: .idle,
            projectName: nil,
            activity: nil,
        )

        #expect(AgentMicroMenuModel.title(for: named) == "019f")
        #expect(AgentMicroMenuModel.title(for: named, mode: .taskTitle) == "Fix task scanner")
        #expect(AgentMicroMenuModel.title(for: unidentified) == "019f1234")
    }

    @Test
    func `age label uses seconds minutes and hours`() {
        let now = Date(timeIntervalSince1970: 10000)

        #expect(AgentMicroMenuModel.ageLabel(
            for: Self.session(activity: now.addingTimeInterval(-5)),
            now: now,
        ) == "5s")
        #expect(AgentMicroMenuModel.ageLabel(
            for: Self.session(activity: now.addingTimeInterval(-125)),
            now: now,
        ) == "2m")
        #expect(AgentMicroMenuModel.ageLabel(
            for: Self.session(activity: now.addingTimeInterval(-7500)),
            now: now,
        ) == "2h")
    }

    @Test
    func `menu follows the V1 state priority and includes the current action`() {
        let now = Date(timeIntervalSince1970: 10000)
        let tasks = [
            Self.observation(session: Self.session(id: "done", activity: now), state: .done),
            Self.observation(session: Self.session(id: "waiting", activity: now), state: .waiting),
            Self.observation(
                session: Self.session(id: "executing", activity: now),
                state: .executing,
                currentAction: "exec_command · swift test"
            ),
            Self.observation(session: Self.session(id: "limited", activity: now), state: .rateLimited),
            Self.observation(session: Self.session(id: "thinking", activity: now), state: .thinking),
            Self.observation(session: Self.session(id: "unknown", activity: now), state: .unknown)
        ]

        let rows = AgentMicroMenuModel.rows(from: tasks, now: now)

        #expect(rows.map(\.state) == [.executing, .thinking, .rateLimited, .waiting, .unknown, .done])
        #expect(rows[0].subtitle.contains("Executing · exec_command · swift test"))
        #expect(rows[0].symbol == "◉")
        #expect(rows[2].symbol == "!")
    }

    @Test
    func `preferences hide completed tasks and include project only when requested`() {
        let now = Date(timeIntervalSince1970: 10000)
        let titled = Self.session(
            id: "titled",
            projectName: "AgentMicro",
            sessionName: "Polish settings",
            activity: now
        )
        let tasks = [
            Self.observation(session: titled, state: .waiting),
            Self.observation(session: Self.session(id: "done", activity: now), state: .done)
        ]

        let rows = AgentMicroMenuModel.rows(
            from: tasks,
            preferences: AgentMicroPreferences(
                taskNameMode: .taskTitleAndProject,
                showRecentlyCompleted: false
            ),
            now: now
        )

        #expect(rows.count == 1)
        #expect(rows[0].title == "Polish settings")
        #expect(rows[0].subtitle == "Waiting · Codex CLI · AgentMicro · 0s")
    }

    @Test
    func `completed rows use the recent completion label`() {
        let now = Date(timeIntervalSince1970: 10000)
        let task = Self.observation(
            session: Self.session(id: "done", projectName: "AgentMicro", activity: now.addingTimeInterval(-60)),
            state: .done
        )

        let row = AgentMicroMenuModel.rows(from: [task], now: now).first

        #expect(row?.title == "Recently completed: AgentMicro")
        #expect(row?.subtitle == "Done · Codex CLI · 1m ago")
    }

    private static func observation(
        session: AgentSession,
        state: CodexTaskState,
        currentAction: String? = nil
    ) -> CodexTaskObservation {
        CodexTaskObservation(
            session: session,
            state: state,
            currentAction: currentAction,
            lastEventAt: session.lastActivityAt
        )
    }

    private static func session(
        id: String = "session",
        provider: AgentSession.Provider = .codex,
        source: AgentSession.Source = .cli,
        state: AgentSession.State = .active,
        projectName: String? = "project",
        sessionName: String? = nil,
        activity: Date?,
    ) -> AgentSession {
        AgentSession(
            id: id,
            provider: provider,
            source: source,
            state: state,
            pid: nil,
            cwd: projectName.map { "/tmp/\($0)" },
            projectName: projectName,
            sessionName: sessionName,
            startedAt: nil,
            lastActivityAt: activity,
            transcriptPath: nil,
            host: "local",
        )
    }
}
