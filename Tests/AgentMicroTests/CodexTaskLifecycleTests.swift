import Foundation
import Testing
@testable import AgentMicro

struct CodexTaskLifecycleTests {
    @Test
    func `file-only executing and completed turns do not need a synthetic PID`() async throws {
        let engine = CodexTaskStateEngine()
        let executingURL = try CodexTaskStateTestSupport.fixtureURL(named: "executing")
        let completedURL = try CodexTaskStateTestSupport.fixtureURL(named: "waiting")
        let executing = try #require(await engine.observe(
            sessions: [CodexTaskStateTestSupport.session(
                transcriptURL: executingURL,
                pid: nil,
                activity: CodexTaskStateTestSupport.fixtureNow)],
            now: CodexTaskStateTestSupport.fixtureNow).first)
        let completed = try #require(await engine.observe(
            sessions: [CodexTaskStateTestSupport.session(
                id: "completed",
                transcriptURL: completedURL,
                pid: nil,
                activity: CodexTaskStateTestSupport.fixtureNow)],
            now: CodexTaskStateTestSupport.fixtureNow).first)

        #expect(executing.state == .thinking)
        #expect(executing.currentAction == "exec_command · swift test --filter AgentMicro")
        #expect(completed.state == .unread)
    }
}
