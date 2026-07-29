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

        let rows = AgentMicroMenuModel.rows(from: sessions, now: now)

        #expect(rows.map(\.title) == ["active-project", "idle-project"])
        #expect(rows[0].subtitle == "Active · Codex App · 20s")
        #expect(rows[1].subtitle == "Idle · Codex CLI · 10s")
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
    func `title falls back through session name and compact session identifier`() {
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

        #expect(AgentMicroMenuModel.title(for: named) == "Fix task scanner")
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
