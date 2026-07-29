@testable import AgentMicro
import CodexBarCore
import Foundation
import Testing

struct CodexTaskStateEngineTests {
    @Test(arguments: [
        ("thinking", CodexTaskState.thinking, nil),
        ("executing", CodexTaskState.executing, "exec_command · swift test --filter AgentMicro"),
        ("waiting", CodexTaskState.waiting, nil),
        ("rate-limited", CodexTaskState.rateLimited, nil)
    ])
    func `fixtures reduce to the expected live state`(
        fixtureName: String,
        expectedState: CodexTaskState,
        expectedAction: String?
    ) async throws {
        let url = try CodexTaskStateTestSupport.fixtureURL(named: fixtureName)
        let engine = CodexTaskStateEngine()
        let task = try #require(await engine.observe(
            sessions: [CodexTaskStateTestSupport.session(
                transcriptURL: url,
                pid: 42,
                activity: CodexTaskStateTestSupport.fixtureNow
            )],
            now: CodexTaskStateTestSupport.fixtureNow
        ).first)

        #expect(task.state == expectedState)
        #expect(task.currentAction == expectedAction)
    }

    @Test
    func `file order drives state while timestamps retain the newest activity`() async throws {
        let url = try CodexTaskStateTestSupport.fixtureURL(named: "out-of-order")
        let engine = CodexTaskStateEngine()
        let task = try #require(await engine.observe(
            sessions: [CodexTaskStateTestSupport.session(
                transcriptURL: url,
                pid: 42,
                activity: CodexTaskStateTestSupport.fixtureNow
            )],
            now: CodexTaskStateTestSupport.fixtureNow
        ).first)

        #expect(task.state == .waiting)
        #expect(task.lastEventAt == Date(timeIntervalSince1970: 1_785_240_005))
    }

    @Test
    func `file-only sessions use rollout lifecycle then expire`() async throws {
        let url = try CodexTaskStateTestSupport.fixtureURL(named: "thinking")
        let engine = CodexTaskStateEngine()

        let unknownNow = CodexTaskStateTestSupport.fixtureNow
        let thinking = try #require(await engine.observe(
            sessions: [CodexTaskStateTestSupport.session(transcriptURL: url, pid: nil, activity: unknownNow)],
            now: unknownNow
        ).first)
        #expect(thinking.state == .thinking)

        let completedURL = try CodexTaskStateTestSupport.fixtureURL(named: "waiting")
        let doneNow = CodexTaskStateTestSupport.fixtureNow.addingTimeInterval(60)
        let done = try #require(await engine.observe(
            sessions: [CodexTaskStateTestSupport.session(
                id: "completed",
                transcriptURL: completedURL,
                pid: nil,
                activity: doneNow.addingTimeInterval(-60)
            )],
            now: doneNow
        ).first)
        #expect(done.state == .done)

        let expiredNow = CodexTaskStateTestSupport.fixtureNow.addingTimeInterval(301)
        let expired = await engine.observe(
            sessions: [CodexTaskStateTestSupport.session(
                transcriptURL: url,
                pid: nil,
                activity: expiredNow.addingTimeInterval(-301)
            )],
            now: expiredNow
        )
        #expect(expired.isEmpty)
    }

    @Test
    func `partial appended line is held until newline then closes the tool call`() async throws {
        let url = try CodexTaskStateTestSupport.temporaryCopy(ofFixture: "executing")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let engine = CodexTaskStateEngine()
        let session = CodexTaskStateTestSupport.session(
            transcriptURL: url,
            pid: 42,
            activity: CodexTaskStateTestSupport.fixtureNow
        )

        let initial = try #require(await engine.observe(
            sessions: [session],
            now: CodexTaskStateTestSupport.fixtureNow
        ).first)
        #expect(initial.state == .executing)

        let completion = CodexTaskStateTestSupport.toolOutput(
            callID: "call-exec",
            output: "Process exited with code 0",
            timestamp: "2026-07-28T12:00:04Z"
        ) + "\n"
        let splitIndex = completion.index(completion.startIndex, offsetBy: completion.count / 2)
        try CodexTaskStateTestSupport.append(String(completion[..<splitIndex]), to: url)

        let partial = try #require(await engine.observe(
            sessions: [session],
            now: CodexTaskStateTestSupport.fixtureNow
        ).first)
        #expect(partial.state == .executing)

        try CodexTaskStateTestSupport.append(String(completion[splitIndex...]), to: url)
        let completed = try #require(await engine.observe(
            sessions: [session],
            now: CodexTaskStateTestSupport.fixtureNow
        ).first)
        #expect(completed.state == .waiting)
        #expect(completed.currentAction == nil)
    }

    @Test
    func `truncation resets the cursor and reducer`() async throws {
        let url = try CodexTaskStateTestSupport.temporaryCopy(ofFixture: "executing")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let engine = CodexTaskStateEngine()
        let session = CodexTaskStateTestSupport.session(
            transcriptURL: url,
            pid: 42,
            activity: CodexTaskStateTestSupport.fixtureNow
        )

        let initial = try #require(await engine.observe(
            sessions: [session],
            now: CodexTaskStateTestSupport.fixtureNow
        ).first)
        #expect(initial.state == .executing)

        let thinkingData = try Data(contentsOf: CodexTaskStateTestSupport.fixtureURL(named: "thinking"))
        try thinkingData.write(to: url)

        let reset = try #require(await engine.observe(
            sessions: [session],
            now: CodexTaskStateTestSupport.fixtureNow
        ).first)
        #expect(reset.state == .thinking)
        #expect(reset.currentAction == nil)
    }

    @Test
    func `malformed lines do not prevent later tool output from closing execution`() async throws {
        let url = try CodexTaskStateTestSupport.temporaryCopy(ofFixture: "executing")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let engine = CodexTaskStateEngine()
        let session = CodexTaskStateTestSupport.session(
            transcriptURL: url,
            pid: 42,
            activity: CodexTaskStateTestSupport.fixtureNow
        )

        _ = await engine.observe(sessions: [session], now: CodexTaskStateTestSupport.fixtureNow)
        try CodexTaskStateTestSupport.append("not-json\n", to: url)
        try CodexTaskStateTestSupport.append(
            CodexTaskStateTestSupport.event(
                type: "exec_command_end",
                timestamp: "2026-07-28T12:00:04Z",
                extraPayload: ["call_id": "call-exec"]
            ) + "\n",
            to: url
        )

        let task = try #require(await engine.observe(
            sessions: [session],
            now: CodexTaskStateTestSupport.fixtureNow
        ).first)
        #expect(task.state == .waiting)
    }

    @Test
    func `long-running exec remains open until its polling call reports completion`() {
        var reducer = CodexTaskStateTestSupport.runningExecReducer()

        #expect(reducer.snapshot.hasPendingToolCall)
        #expect(reducer.snapshot.currentAction == "exec_command · swift test")

        reducer.consume(
            line: CodexTaskStateTestSupport.toolCall(
                callID: "poll-2",
                name: "write_stdin",
                inputKey: "arguments",
                input: #"{"session_id":12345,"chars":""}"#,
                timestamp: "2026-07-28T12:00:05Z"
            )
        )
        reducer.consume(
            line: CodexTaskStateTestSupport.toolOutput(
                callID: "poll-2",
                output: "Process exited with code 0",
                timestamp: "2026-07-28T12:00:06Z"
            )
        )

        #expect(!reducer.snapshot.hasPendingToolCall)
    }

    @Test
    func `custom tool calls pair with custom outputs`() {
        var reducer = CodexRolloutReducer()
        reducer.consume(
            line: CodexTaskStateTestSupport.toolCall(
                callID: "custom-1",
                name: "apply_patch",
                itemType: "custom_tool_call",
                inputKey: "input",
                input: "*** Update File: /tmp/AgentMicro.swift\n",
                timestamp: "2026-07-28T12:00:01Z"
            )
        )

        #expect(reducer.snapshot.hasPendingToolCall)
        #expect(reducer.snapshot.currentAction == "apply_patch · AgentMicro.swift")

        reducer.consume(
            line: CodexTaskStateTestSupport.toolOutput(
                callID: "custom-1",
                output: [["type": "text", "text": "Success"]],
                itemType: "custom_tool_call_output",
                timestamp: "2026-07-28T12:00:02Z"
            )
        )

        #expect(!reducer.snapshot.hasPendingToolCall)
    }

    @Test
    func `new token count clears a previous saturated rate limit`() {
        var reducer = CodexRolloutReducer()
        reducer.consume(
            line: CodexTaskStateTestSupport.tokenCount(
                usedPercent: 100,
                timestamp: "2026-07-28T12:00:01Z"
            )
        )
        #expect(reducer.snapshot.isRateLimited)

        reducer.consume(
            line: CodexTaskStateTestSupport.tokenCount(
                usedPercent: 12,
                timestamp: "2026-07-28T12:00:02Z"
            )
        )
        #expect(!reducer.snapshot.isRateLimited)
    }

    @Test
    func `tool action removes common credentials`() {
        let action = CodexToolActionFormatter.action(
            toolName: "exec_command",
            rawInput: #"{"cmd":"curl -H Authorization:Bearer sk-proj-private token=secret-value"}"#
        )

        #expect(action.contains("[REDACTED]"))
        #expect(!action.contains("sk-proj-private"))
        #expect(!action.contains("secret-value"))
    }
}
