@testable import AgentMicro
import Foundation
import Testing

struct AgentMicroRefreshPolicyTests {
    @Test
    func `agentMicro scanner excludes subagent rollouts`() {
        #expect(!AgentMicroSessionPolicy.scannerConfiguration.includeCodexSubagents)
        #expect(AgentMicroSessionPolicy.scannerConfiguration.requireUnambiguousCodexProcessOwnership)
    }

    @Test
    func `desktop app keeps polling responsive without assigning its PID to a task`() {
        #expect(AgentMicroRefreshPolicy.interval(
            tasks: [],
            isDesktopAppRunning: true
        ) == .seconds(2))
    }

    @Test
    func `working and process-backed tasks use active polling`() {
        let working = CodexTaskStateTestSupport.observation(state: .thinking, pid: nil)
        let processBacked = CodexTaskStateTestSupport.observation(state: .waiting, pid: 42)

        #expect(AgentMicroRefreshPolicy.interval(
            tasks: [working],
            isDesktopAppRunning: false
        ) == .seconds(2))
        #expect(AgentMicroRefreshPolicy.interval(
            tasks: [processBacked],
            isDesktopAppRunning: false
        ) == .seconds(2))
    }

    @Test
    func `idle file-only tasks use the low-power interval`() {
        let done = CodexTaskStateTestSupport.observation(state: .done, pid: nil)

        #expect(AgentMicroRefreshPolicy.interval(
            tasks: [done],
            isDesktopAppRunning: false
        ) == .seconds(15))
    }
}
