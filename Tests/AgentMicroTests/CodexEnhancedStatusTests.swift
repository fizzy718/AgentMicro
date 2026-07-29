import Foundation
import Testing
@testable import AgentMicro

struct CodexEnhancedStatusTests {
    @Test
    func `focused title resolves one exact task and rejects ambiguous projects`() {
        let target = CodexTaskStateTestSupport.observation(
            state: .unread,
            id: "target",
            projectName: "AgentMicro",
            sessionName: "Fix task status")
        let other = CodexTaskStateTestSupport.observation(
            state: .idle,
            id: "other",
            projectName: "AgentMicro",
            sessionName: "Write release notes")

        #expect(CodexEnhancedStatusResolver.selectedSessionKey(
            tasks: [target, other],
            windowTitle: "Fix task status",
            selectedLabels: []) == target.sessionKey)
        #expect(CodexEnhancedStatusResolver.selectedSessionKey(
            tasks: [target, other],
            windowTitle: "AgentMicro",
            selectedLabels: []) == nil)
    }

    @Test
    func `selected accessibility label can identify the exact task`() {
        let target = CodexTaskStateTestSupport.observation(
            state: .unread,
            id: "target",
            sessionName: "Fix task status")
        let other = CodexTaskStateTestSupport.observation(
            state: .idle,
            id: "other",
            sessionName: "Write release notes")

        #expect(CodexEnhancedStatusResolver.selectedSessionKey(
            tasks: [target, other],
            windowTitle: "Codex",
            selectedLabels: ["Fix task status, AgentMicro"]) == target.sessionKey)
    }

    @Test
    func `opposing approval controls become orange and error alerts become red`() {
        #expect(CodexEnhancedStatusResolver.stateOverride(
            buttonLabels: ["允许此对话", "拒绝"],
            alertLabels: []) == .requiresInput)
        #expect(CodexEnhancedStatusResolver.stateOverride(
            buttonLabels: ["Allow once", "Deny"],
            alertLabels: []) == .requiresInput)
        #expect(CodexEnhancedStatusResolver.stateOverride(
            buttonLabels: ["Send"],
            alertLabels: ["Something went wrong. Try again."]) == .error)
        #expect(CodexEnhancedStatusResolver.stateOverride(
            buttonLabels: ["Allow once"],
            alertLabels: []) == nil)
    }

    @Test
    func `enhanced evidence remains actionable until newer rollout activity`() {
        let activity = Date(timeIntervalSince1970: 100)
        let waiting = CodexTaskStateTestSupport.observation(
            state: .thinking,
            activity: activity,
            id: "waiting")
        var tracker = CodexEnhancedStatusTracker()
        let snapshot = CodexEnhancedStatusSnapshot(
            selectedSessionKey: waiting.sessionKey,
            stateOverride: .requiresInput)

        let detected = tracker.apply(snapshot: snapshot, to: [waiting])
        #expect(detected.first?.state == .requiresInput)

        let retained = tracker.apply(snapshot: nil, to: [waiting])
        #expect(retained.first?.state == .requiresInput)

        let resumed = CodexTaskStateTestSupport.observation(
            state: .thinking,
            activity: activity.addingTimeInterval(1),
            id: "waiting")
        let cleared = tracker.apply(snapshot: nil, to: [resumed])
        #expect(cleared.first?.state == .thinking)
    }
}
