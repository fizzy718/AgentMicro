@testable import AgentMicro
import CodexBarCore
import Foundation
import Testing

enum CodexTaskStateTestSupport {
    static let fixtureNow = Date(timeIntervalSince1970: 1_785_240_010)

    static func toolCall(
        callID: String,
        name: String,
        itemType: String = "function_call",
        inputKey: String,
        input: String,
        timestamp: String
    ) -> String {
        self.json([
            "type": "response_item",
            "timestamp": timestamp,
            "payload": [
                "type": itemType,
                "name": name,
                inputKey: input,
                "call_id": callID
            ]
        ])
    }

    static func toolOutput(
        callID: String,
        output: Any,
        itemType: String = "function_call_output",
        timestamp: String
    ) -> String {
        self.json([
            "type": "response_item",
            "timestamp": timestamp,
            "payload": [
                "type": itemType,
                "call_id": callID,
                "output": output
            ]
        ])
    }

    static func tokenCount(usedPercent: Double, timestamp: String) -> String {
        self.event(
            type: "token_count",
            timestamp: timestamp,
            extraPayload: [
                "rate_limits": [
                    "limit_id": "codex",
                    "primary": ["used_percent": usedPercent]
                ]
            ]
        )
    }

    static func runningExecReducer() -> CodexRolloutReducer {
        var reducer = CodexRolloutReducer()
        reducer.consume(
            line: self.toolCall(
                callID: "exec-1",
                name: "exec_command",
                inputKey: "arguments",
                input: #"{"cmd":"swift test"}"#,
                timestamp: "2026-07-28T12:00:01Z"
            )
        )
        reducer.consume(
            line: self.toolOutput(
                callID: "exec-1",
                output: "Process running with session ID 12345",
                timestamp: "2026-07-28T12:00:02Z"
            )
        )
        reducer.consume(
            line: self.toolCall(
                callID: "poll-1",
                name: "write_stdin",
                inputKey: "arguments",
                input: #"{"session_id":12345,"chars":""}"#,
                timestamp: "2026-07-28T12:00:03Z"
            )
        )
        reducer.consume(
            line: self.toolOutput(
                callID: "poll-1",
                output: "Process running with session ID 12345",
                timestamp: "2026-07-28T12:00:04Z"
            )
        )
        return reducer
    }

    static func event(
        type: String,
        timestamp: String,
        extraPayload: [String: Any] = [:]
    ) -> String {
        var payload = extraPayload
        payload["type"] = type
        return self.json([
            "type": "event_msg",
            "timestamp": timestamp,
            "payload": payload
        ])
    }

    static func fixtureURL(named name: String) throws -> URL {
        try #require(Bundle.module.url(
            forResource: name,
            withExtension: "jsonl",
            subdirectory: "Fixtures"
        ))
    }

    static func temporaryCopy(ofFixture name: String) throws -> URL {
        let source = try self.fixtureURL(named: name)
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("AgentMicroTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let destination = directory.appendingPathComponent("rollout.jsonl")
        try FileManager.default.copyItem(at: source, to: destination)
        return destination
    }

    static func append(_ value: String, to url: URL) throws {
        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }
        try handle.seekToEnd()
        try handle.write(contentsOf: Data(value.utf8))
    }

    static func session(
        id: String? = nil,
        transcriptURL: URL,
        pid: Int32?,
        activity: Date
    ) -> AgentSession {
        AgentSession(
            id: id ?? transcriptURL.deletingPathExtension().lastPathComponent,
            provider: .codex,
            source: .cli,
            state: pid == nil ? .idle : .active,
            pid: pid,
            cwd: "/tmp/AgentMicro",
            projectName: "AgentMicro",
            startedAt: activity.addingTimeInterval(-60),
            lastActivityAt: activity,
            transcriptPath: transcriptURL.path,
            host: "local"
        )
    }

    static func observation(state: CodexTaskState, pid: Int32?) -> CodexTaskObservation {
        let activity = self.fixtureNow
        let session = AgentSession(
            id: "policy-\(state.rawValue)-\(pid ?? 0)",
            provider: .codex,
            source: .cli,
            state: pid == nil ? .idle : .active,
            pid: pid,
            cwd: "/tmp/AgentMicro",
            projectName: "AgentMicro",
            startedAt: activity.addingTimeInterval(-60),
            lastActivityAt: activity,
            transcriptPath: nil,
            host: "local"
        )
        return CodexTaskObservation(
            session: session,
            state: state,
            currentAction: nil,
            lastEventAt: activity
        )
    }

    private static func json(_ object: [String: Any]) -> String {
        guard JSONSerialization.isValidJSONObject(object),
              let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]),
              let value = String(bytes: data, encoding: .utf8)
        else { return "{}" }
        return value
    }
}
