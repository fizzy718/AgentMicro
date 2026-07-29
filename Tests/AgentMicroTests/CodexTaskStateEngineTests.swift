import CodexBarCore
import Foundation
import Testing
@testable import AgentMicro

struct CodexTaskStateEngineTests {
    @Test(arguments: [
        ("thinking", CodexTaskState.thinking, nil),
        ("executing", CodexTaskState.thinking, "exec_command · swift test --filter AgentMicro"),
        ("waiting", CodexTaskState.idle, nil),
        ("rate-limited", CodexTaskState.error, nil),
    ])
    func `fixtures reduce to the expected live state`(
        fixtureName: String,
        expectedState: CodexTaskState,
        expectedAction: String?) async throws
    {
        let url = try CodexTaskStateTestSupport.fixtureURL(named: fixtureName)
        let engine = CodexTaskStateEngine()
        let task = try #require(await engine.observe(
            sessions: [CodexTaskStateTestSupport.session(
                transcriptURL: url,
                pid: 42,
                activity: CodexTaskStateTestSupport.fixtureNow)],
            now: CodexTaskStateTestSupport.fixtureNow).first)

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
                activity: CodexTaskStateTestSupport.fixtureNow)],
            now: CodexTaskStateTestSupport.fixtureNow).first)

        #expect(task.state == .thinking)
        #expect(task.lastEventAt == Date(timeIntervalSince1970: 1_785_240_005))
    }

    @Test
    func `file-only sessions use rollout lifecycle then expire`() async throws {
        let url = try CodexTaskStateTestSupport.fixtureURL(named: "thinking")
        let engine = CodexTaskStateEngine()

        let unknownNow = CodexTaskStateTestSupport.fixtureNow
        let thinking = try #require(await engine.observe(
            sessions: [CodexTaskStateTestSupport.session(transcriptURL: url, pid: nil, activity: unknownNow)],
            now: unknownNow).first)
        #expect(thinking.state == .thinking)

        let completedURL = try CodexTaskStateTestSupport.fixtureURL(named: "waiting")
        let doneNow = CodexTaskStateTestSupport.fixtureNow.addingTimeInterval(60)
        let done = try #require(await engine.observe(
            sessions: [CodexTaskStateTestSupport.session(
                id: "completed",
                transcriptURL: completedURL,
                pid: nil,
                activity: doneNow.addingTimeInterval(-60))],
            now: doneNow).first)
        #expect(done.state == .unread)

        let expiredAge = CodexTaskStateResolver.defaultCompletedRetention + 1
        let expiredNow = CodexTaskStateTestSupport.fixtureNow.addingTimeInterval(expiredAge)
        let expired = await engine.observe(
            sessions: [CodexTaskStateTestSupport.session(
                transcriptURL: url,
                pid: nil,
                activity: expiredNow.addingTimeInterval(-expiredAge))],
            now: expiredNow)
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
            activity: CodexTaskStateTestSupport.fixtureNow)

        let initial = try #require(await engine.observe(
            sessions: [session],
            now: CodexTaskStateTestSupport.fixtureNow).first)
        #expect(initial.state == .thinking)

        let completion = CodexTaskStateTestSupport.toolOutput(
            callID: "call-exec",
            output: "Process exited with code 0",
            timestamp: "2026-07-28T12:00:04Z") + "\n"
        let splitIndex = completion.index(completion.startIndex, offsetBy: completion.count / 2)
        try CodexTaskStateTestSupport.append(String(completion[..<splitIndex]), to: url)

        let partial = try #require(await engine.observe(
            sessions: [session],
            now: CodexTaskStateTestSupport.fixtureNow).first)
        #expect(partial.state == .thinking)

        try CodexTaskStateTestSupport.append(String(completion[splitIndex...]), to: url)
        let completed = try #require(await engine.observe(
            sessions: [session],
            now: CodexTaskStateTestSupport.fixtureNow).first)
        #expect(completed.state == .thinking)
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
            activity: CodexTaskStateTestSupport.fixtureNow)

        let initial = try #require(await engine.observe(
            sessions: [session],
            now: CodexTaskStateTestSupport.fixtureNow).first)
        #expect(initial.state == .thinking)

        let thinkingData = try Data(contentsOf: CodexTaskStateTestSupport.fixtureURL(named: "thinking"))
        try thinkingData.write(to: url)

        let reset = try #require(await engine.observe(
            sessions: [session],
            now: CodexTaskStateTestSupport.fixtureNow).first)
        #expect(reset.state == .thinking)
        #expect(reset.currentAction == nil)
    }

    @Test
    func `large rollout initial scan tails the current turn`() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("AgentMicroTailTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("rollout.jsonl")
        var data = Data(repeating: 0x78, count: CodexTaskStateEngine.initialReadWindow + 1024)
        data.append(0x0A)
        data.append(CodexTaskStateTestSupport.event(
            type: "user_message",
            timestamp: "2026-07-28T12:00:01Z").data(using: .utf8) ?? Data())
        data.append(0x0A)
        try data.write(to: url)

        let engine = CodexTaskStateEngine()
        let task = try #require(await engine.observe(
            sessions: [CodexTaskStateTestSupport.session(
                transcriptURL: url,
                pid: nil,
                activity: CodexTaskStateTestSupport.fixtureNow)],
            now: CodexTaskStateTestSupport.fixtureNow).first)

        #expect(task.state == .thinking)
    }

    @Test
    func `malformed lines do not prevent later tool output from closing execution`() async throws {
        let url = try CodexTaskStateTestSupport.temporaryCopy(ofFixture: "executing")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let engine = CodexTaskStateEngine()
        let session = CodexTaskStateTestSupport.session(
            transcriptURL: url,
            pid: 42,
            activity: CodexTaskStateTestSupport.fixtureNow)

        _ = await engine.observe(sessions: [session], now: CodexTaskStateTestSupport.fixtureNow)
        try CodexTaskStateTestSupport.append("not-json\n", to: url)
        try CodexTaskStateTestSupport.append(
            CodexTaskStateTestSupport.event(
                type: "exec_command_end",
                timestamp: "2026-07-28T12:00:04Z",
                extraPayload: ["call_id": "call-exec"]) + "\n",
            to: url)

        let task = try #require(await engine.observe(
            sessions: [session],
            now: CodexTaskStateTestSupport.fixtureNow).first)
        #expect(task.state == .thinking)
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
                timestamp: "2026-07-28T12:00:05Z"))
        reducer.consume(
            line: CodexTaskStateTestSupport.toolOutput(
                callID: "poll-2",
                output: "Process exited with code 0",
                timestamp: "2026-07-28T12:00:06Z"))

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
                timestamp: "2026-07-28T12:00:01Z"))

        #expect(reducer.snapshot.hasPendingToolCall)
        #expect(reducer.snapshot.currentAction == "apply_patch · AgentMicro.swift")

        reducer.consume(
            line: CodexTaskStateTestSupport.toolOutput(
                callID: "custom-1",
                output: [["type": "text", "text": "Success"]],
                itemType: "custom_tool_call_output",
                timestamp: "2026-07-28T12:00:02Z"))

        #expect(!reducer.snapshot.hasPendingToolCall)
    }

    @Test
    func `an active turn stays blue between tool calls`() throws {
        var reducer = CodexRolloutReducer()
        reducer.consume(line: CodexTaskStateTestSupport.event(
            type: "user_message",
            timestamp: "2026-07-28T12:00:01Z"))
        reducer.consume(
            line: CodexTaskStateTestSupport.toolCall(
                callID: "tool-1",
                name: "exec_command",
                inputKey: "arguments",
                input: #"{"cmd":"swift test"}"#,
                timestamp: "2026-07-28T12:00:02Z"))
        reducer.consume(
            line: CodexTaskStateTestSupport.toolOutput(
                callID: "tool-1",
                output: "Process exited with code 0",
                timestamp: "2026-07-28T12:00:03Z"))

        let snapshot = reducer.snapshot
        let session = try CodexTaskStateTestSupport.session(
            transcriptURL: CodexTaskStateTestSupport.fixtureURL(named: "thinking"),
            pid: 42,
            activity: CodexTaskStateTestSupport.fixtureNow)
        let observation = CodexTaskStateResolver.observation(
            session: session,
            snapshot: snapshot,
            now: CodexTaskStateTestSupport.fixtureNow)

        #expect(snapshot.isTurnActive == true)
        #expect(!snapshot.hasPendingToolCall)
        #expect(observation?.state == .thinking)
    }

    @Test
    func `final answer event completes the turn before task complete arrives`() {
        var reducer = CodexRolloutReducer()
        reducer.consume(line: CodexTaskStateTestSupport.event(
            type: "user_message",
            timestamp: "2026-07-28T12:00:01Z"))
        reducer.consume(
            line: CodexTaskStateTestSupport.toolCall(
                callID: "tool-1",
                name: "exec_command",
                inputKey: "arguments",
                input: #"{"cmd":"swift test"}"#,
                timestamp: "2026-07-28T12:00:02Z"))

        reducer.consume(line: CodexTaskStateTestSupport.event(
            type: "agent_message",
            timestamp: "2026-07-28T12:00:03Z",
            extraPayload: ["phase": "final_answer"]))

        #expect(reducer.snapshot.isTurnActive == false)
        #expect(!reducer.snapshot.hasPendingToolCall)
        #expect(reducer.snapshot.stateChangedAt == Date(timeIntervalSince1970: 1_785_240_003))
    }

    @Test
    func `final answer response completes a turn when event message is absent`() {
        var reducer = CodexRolloutReducer()
        reducer.consume(line: CodexTaskStateTestSupport.event(
            type: "user_message",
            timestamp: "2026-07-28T12:00:01Z"))

        reducer.consume(line: CodexTaskStateTestSupport.assistantResponse(
            phase: "final_answer",
            timestamp: "2026-07-28T12:00:02Z"))

        #expect(reducer.snapshot.isTurnActive == false)
        #expect(reducer.snapshot.stateChangedAt == Date(timeIntervalSince1970: 1_785_240_002))
    }

    @Test
    func `commentary messages keep the turn active`() {
        var reducer = CodexRolloutReducer()
        reducer.consume(line: CodexTaskStateTestSupport.event(
            type: "user_message",
            timestamp: "2026-07-28T12:00:01Z"))
        reducer.consume(line: CodexTaskStateTestSupport.event(
            type: "agent_message",
            timestamp: "2026-07-28T12:00:02Z",
            extraPayload: ["phase": "commentary"]))
        reducer.consume(line: CodexTaskStateTestSupport.assistantResponse(
            phase: "commentary",
            timestamp: "2026-07-28T12:00:03Z"))

        #expect(reducer.snapshot.isTurnActive == true)
    }

    @Test
    func `priority service tier enables fast model until settings return to default`() {
        var reducer = CodexRolloutReducer()
        reducer.consume(line: CodexTaskStateTestSupport.event(
            type: "thread_settings_applied",
            timestamp: "2026-07-28T12:00:01Z",
            extraPayload: ["thread_settings": ["service_tier": "priority"]]))

        #expect(reducer.snapshot.usesFastModel)

        reducer.consume(line: CodexTaskStateTestSupport.event(
            type: "thread_settings_applied",
            timestamp: "2026-07-28T12:00:02Z",
            extraPayload: ["thread_settings": ["service_tier": "default"]]))

        #expect(!reducer.snapshot.usesFastModel)
    }

    @Test
    func `turn duration and ordering timestamps follow lifecycle transitions`() {
        var reducer = CodexRolloutReducer()
        reducer.consume(line: CodexTaskStateTestSupport.event(
            type: "user_message",
            timestamp: "2026-07-28T12:00:01Z"))
        let started = reducer.snapshot

        reducer.consume(line: CodexTaskStateTestSupport.tokenCount(
            usedPercent: 10,
            timestamp: "2026-07-28T12:00:02Z"))
        let incidental = reducer.snapshot

        reducer.consume(line: CodexTaskStateTestSupport.event(
            type: "task_complete",
            timestamp: "2026-07-28T12:00:03Z"))
        let completed = reducer.snapshot

        #expect(started.turnStartedAt == Date(timeIntervalSince1970: 1_785_240_001))
        #expect(started.stateChangedAt == started.turnStartedAt)
        #expect(incidental.stateChangedAt == started.stateChangedAt)
        #expect(completed.turnStartedAt == started.turnStartedAt)
        #expect(completed.stateChangedAt == Date(timeIntervalSince1970: 1_785_240_003))
    }

    @Test
    func `explicit questions use the input state while guardian approvals do not`() throws {
        var questionReducer = CodexRolloutReducer()
        questionReducer.consume(
            line: CodexTaskStateTestSupport.toolCall(
                callID: "question-1",
                name: "request_user_input",
                inputKey: "arguments",
                input: #"{"questions":[{"question":"Choose a layout"}]}"#,
                timestamp: "2026-07-28T12:00:01Z"))
        #expect(questionReducer.snapshot.requiresInput)

        var approvalReducer = CodexRolloutReducer()
        approvalReducer.consume(
            line: CodexTaskStateTestSupport.toolCall(
                callID: "approval-1",
                name: "exec",
                itemType: "custom_tool_call",
                inputKey: "input",
                input: #"sandbox_permissions: "require_escalated""#,
                timestamp: "2026-07-28T12:00:01Z"))

        let snapshot = approvalReducer.snapshot
        let session = try CodexTaskStateTestSupport.session(
            transcriptURL: CodexTaskStateTestSupport.fixtureURL(named: "thinking"),
            pid: 42,
            activity: CodexTaskStateTestSupport.fixtureNow)
        let observation = CodexTaskStateResolver.observation(
            session: session,
            snapshot: snapshot,
            now: CodexTaskStateTestSupport.fixtureNow)

        #expect(!snapshot.requiresInput)
        #expect(observation?.state == .thinking)
        #expect(observation?.currentAction != nil)
    }

    @Test
    func `first computer use target requires input without repeated orange flashes`() {
        var computerUseReducer = CodexRolloutReducer()
        computerUseReducer.consume(
            line: CodexTaskStateTestSupport.toolCall(
                callID: "computer-use-1",
                name: "js",
                inputKey: "arguments",
                input: #"{"code":"await sky.get_app_state({ app: \"com.google.Chrome\" })"}"#,
                namespace: "mcp__node_repl",
                timestamp: "2026-07-28T12:00:01Z"))
        #expect(computerUseReducer.snapshot.requiresInput)

        computerUseReducer.consume(
            line: CodexTaskStateTestSupport.toolOutput(
                callID: "computer-use-1",
                output: "Script completed",
                timestamp: "2026-07-28T12:00:02Z"))
        computerUseReducer.consume(
            line: CodexTaskStateTestSupport.toolCall(
                callID: "computer-use-2",
                name: "js",
                inputKey: "arguments",
                input: #"{"code":"await sky.click({ app: \"com.google.Chrome\" })"}"#,
                namespace: "mcp__node_repl",
                timestamp: "2026-07-28T12:00:03Z"))
        #expect(!computerUseReducer.snapshot.requiresInput)
    }

    @Test
    func `ordinary node repl JavaScript stays in thinking state`() {
        var ordinaryJavaScriptReducer = CodexRolloutReducer()
        ordinaryJavaScriptReducer.consume(
            line: CodexTaskStateTestSupport.toolCall(
                callID: "javascript-1",
                name: "js",
                inputKey: "arguments",
                input: #"{"code":"const value = 1"}"#,
                namespace: "mcp__node_repl",
                timestamp: "2026-07-28T12:00:01Z"))
        #expect(!ordinaryJavaScriptReducer.snapshot.requiresInput)
    }

    @Test
    func `browser handoff stays orange until the user resumes the task`() throws {
        var reducer = CodexRolloutReducer()
        reducer.consume(line: CodexTaskStateTestSupport.event(
            type: "user_message",
            timestamp: "2026-07-28T12:00:01Z"))
        reducer.consume(line: CodexTaskStateTestSupport.assistantResponse(
            phase: "commentary",
            text: "浏览器已经打开。请在那里输入资料并确认提交。",
            timestamp: "2026-07-28T12:00:02Z"))

        #expect(reducer.snapshot.requiresInput)

        reducer.consume(line: CodexTaskStateTestSupport.event(
            type: "task_complete",
            timestamp: "2026-07-28T12:00:03Z"))
        #expect(reducer.snapshot.requiresInput)
        let completedSession = try CodexTaskStateTestSupport.session(
            transcriptURL: CodexTaskStateTestSupport.fixtureURL(named: "waiting"),
            pid: nil,
            activity: CodexTaskStateTestSupport.fixtureNow)
        let completedObservation = CodexTaskStateResolver.observation(
            session: completedSession,
            snapshot: reducer.snapshot,
            now: CodexTaskStateTestSupport.fixtureNow)
        #expect(completedObservation?.state == .requiresInput)

        reducer.consume(line: CodexTaskStateTestSupport.event(
            type: "user_message",
            timestamp: "2026-07-28T12:00:04Z"))
        #expect(!reducer.snapshot.requiresInput)
        #expect(reducer.snapshot.isTurnActive == true)
    }

    @Test
    func `English user action requests also use the input state`() {
        var reducer = CodexRolloutReducer()
        reducer.consume(line: CodexTaskStateTestSupport.assistantResponse(
            phase: "commentary",
            text: "Please log in in the browser, then confirm the authorization.",
            timestamp: "2026-07-28T12:00:01Z"))

        #expect(reducer.snapshot.requiresInput)
    }

    @Test
    func `final answer questions remain orange after task completion`() {
        var reducer = CodexRolloutReducer()
        reducer.consume(line: CodexTaskStateTestSupport.event(
            type: "agent_message",
            timestamp: "2026-07-28T12:00:01Z",
            extraPayload: [
                "phase": "final_answer",
                "message": "请确认这组公开身份，并允许我上传草稿创建商店条目吗？",
            ]))
        reducer.consume(line: CodexTaskStateTestSupport.event(
            type: "task_complete",
            timestamp: "2026-07-28T12:00:02Z"))

        #expect(reducer.snapshot.requiresInput)
        #expect(reducer.snapshot.isTurnActive == false)
    }

    @Test
    func `choice questions without action verbs also require an answer`() {
        var reducer = CodexRolloutReducer()
        reducer.consume(line: CodexTaskStateTestSupport.assistantResponse(
            phase: "final_answer",
            text: "方案都可行。你希望采用哪一种？",
            timestamp: "2026-07-28T12:00:01Z"))

        #expect(reducer.snapshot.requiresInput)
    }

    @Test
    func `negative browser guidance does not request user input`() {
        var reducer = CodexRolloutReducer()
        reducer.consume(line: CodexTaskStateTestSupport.assistantResponse(
            phase: "commentary",
            text: "请先不要操作或切换 Chrome 标签页，我正在填写字段。",
            timestamp: "2026-07-28T12:00:01Z"))

        #expect(!reducer.snapshot.requiresInput)
    }

    @Test
    func `waiting guidance is not treated as a user handoff`() {
        var reducer = CodexRolloutReducer()
        reducer.consume(line: CodexTaskStateTestSupport.assistantResponse(
            phase: "commentary",
            text: "我会继续处理，请稍等。",
            timestamp: "2026-07-28T12:00:01Z"))

        #expect(!reducer.snapshot.requiresInput)
    }

    @Test
    func `new token count clears a previous saturated rate limit`() {
        var reducer = CodexRolloutReducer()
        reducer.consume(
            line: CodexTaskStateTestSupport.tokenCount(
                usedPercent: 100,
                timestamp: "2026-07-28T12:00:01Z"))
        #expect(reducer.snapshot.isRateLimited)

        reducer.consume(
            line: CodexTaskStateTestSupport.tokenCount(
                usedPercent: 12,
                timestamp: "2026-07-28T12:00:02Z"))
        #expect(!reducer.snapshot.isRateLimited)
    }

    @Test
    func `terminal failure answer becomes red while recovered error prose does not`() throws {
        var failed = CodexRolloutReducer()
        failed.consume(line: CodexTaskStateTestSupport.event(
            type: "user_message",
            timestamp: "2026-07-28T12:00:01Z"))
        failed.consume(line: CodexTaskStateTestSupport.assistantResponse(
            phase: "final_answer",
            text: "I was unable to complete the requested release.",
            timestamp: "2026-07-28T12:00:02Z"))
        #expect(failed.snapshot.hasBlockingError)

        let session = try CodexTaskStateTestSupport.session(
            transcriptURL: CodexTaskStateTestSupport.fixtureURL(named: "waiting"),
            pid: nil,
            activity: CodexTaskStateTestSupport.fixtureNow)
        #expect(CodexTaskStateResolver.observation(
            session: session,
            snapshot: failed.snapshot,
            now: CodexTaskStateTestSupport.fixtureNow)?.state == .error)

        var recovered = CodexRolloutReducer()
        recovered.consume(line: CodexTaskStateTestSupport.assistantResponse(
            phase: "final_answer",
            text: "The earlier execution failed, but it is fixed and all tests passed.",
            timestamp: "2026-07-28T12:00:03Z"))
        #expect(!recovered.snapshot.hasBlockingError)
    }

    @Test
    func `unresolved terminal tool failure becomes red only when the turn ends`() {
        var reducer = CodexRolloutReducer()
        reducer.consume(line: CodexTaskStateTestSupport.event(
            type: "user_message",
            timestamp: "2026-07-28T12:00:01Z"))
        reducer.consume(line: CodexTaskStateTestSupport.toolCall(
            callID: "failed-exec",
            name: "exec_command",
            inputKey: "arguments",
            input: #"{"cmd":"make test"}"#,
            timestamp: "2026-07-28T12:00:02Z"))
        reducer.consume(line: CodexTaskStateTestSupport.toolOutput(
            callID: "failed-exec",
            output: "Process exited with code 1",
            timestamp: "2026-07-28T12:00:03Z"))

        #expect(!reducer.snapshot.hasBlockingError)
        #expect(reducer.snapshot.isTurnActive == true)

        reducer.consume(line: CodexTaskStateTestSupport.event(
            type: "task_complete",
            timestamp: "2026-07-28T12:00:04Z"))
        #expect(reducer.snapshot.hasBlockingError)
    }

    @Test
    func `successful recovery clears an earlier tool failure`() {
        var reducer = CodexRolloutReducer()
        reducer.consume(line: CodexTaskStateTestSupport.event(
            type: "user_message",
            timestamp: "2026-07-28T12:00:01Z"))
        reducer.consume(line: CodexTaskStateTestSupport.toolCall(
            callID: "failed-exec",
            name: "exec_command",
            inputKey: "arguments",
            input: #"{"cmd":"make test"}"#,
            timestamp: "2026-07-28T12:00:02Z"))
        reducer.consume(line: CodexTaskStateTestSupport.toolOutput(
            callID: "failed-exec",
            output: "Process exited with code 1",
            timestamp: "2026-07-28T12:00:03Z"))
        reducer.consume(line: CodexTaskStateTestSupport.toolCall(
            callID: "fixed-exec",
            name: "exec_command",
            inputKey: "arguments",
            input: #"{"cmd":"make test"}"#,
            timestamp: "2026-07-28T12:00:04Z"))
        reducer.consume(line: CodexTaskStateTestSupport.toolOutput(
            callID: "fixed-exec",
            output: "Process exited with code 0",
            timestamp: "2026-07-28T12:00:05Z"))
        reducer.consume(line: CodexTaskStateTestSupport.event(
            type: "task_complete",
            timestamp: "2026-07-28T12:00:06Z"))

        #expect(!reducer.snapshot.hasBlockingError)
    }

    @Test
    func `user interruption is not red but structured failure is red`() {
        var interrupted = CodexRolloutReducer()
        interrupted.consume(line: CodexTaskStateTestSupport.event(
            type: "turn_aborted",
            timestamp: "2026-07-28T12:00:01Z",
            extraPayload: ["reason": "interrupted"]))
        #expect(!interrupted.snapshot.hasBlockingError)

        var failed = CodexRolloutReducer()
        failed.consume(line: CodexTaskStateTestSupport.event(
            type: "turn_failed",
            timestamp: "2026-07-28T12:00:02Z"))
        #expect(failed.snapshot.hasBlockingError)
    }

    @Test
    func `additional structured question tools require input`() {
        #expect(CodexToolCallClassifier.requiresInput("elicitation_request"))
        #expect(CodexToolCallClassifier.requiresInput("ask_user_question"))
        #expect(!CodexToolCallClassifier.requiresInput("exec_command"))
    }

    @Test
    func `tool action removes common credentials`() {
        let action = CodexToolActionFormatter.action(
            toolName: "exec_command",
            rawInput: #"{"cmd":"curl -H Authorization:Bearer sk-proj-private token=secret-value"}"#)

        #expect(action.contains("[REDACTED]"))
        #expect(!action.contains("sk-proj-private"))
        #expect(!action.contains("secret-value"))
    }
}
