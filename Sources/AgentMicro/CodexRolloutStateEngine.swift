import CodexBarCore
import Foundation

actor CodexTaskStateEngine {
    private struct Cursor {
        var fileIdentifier: UInt64?
        var byteOffset: UInt64 = 0
        var bufferedData = Data()
        var isDiscardingOversizedLine = false
        var reducer = CodexRolloutReducer()
    }

    private static let readChunkSize = 64 * 1024
    private static let maximumLineSize = 10 * 1024 * 1024

    private var cursors: [String: Cursor] = [:]

    func observe(sessions: [AgentSession], now: Date = Date()) -> [CodexTaskObservation] {
        let retainedSessions = sessions.filter { session in
            guard session.provider == .codex else { return false }
            if session.pid != nil {
                return true
            }
            guard let activity = session.lastActivityAt ?? session.startedAt else { return false }
            return now.timeIntervalSince(activity) <= CodexTaskStateResolver.defaultCompletedRetention
        }
        let retainedPaths = Set(retainedSessions.compactMap(\.transcriptPath))
        self.cursors = self.cursors.filter { retainedPaths.contains($0.key) }

        return retainedSessions.compactMap { session in
            let snapshot = session.transcriptPath.flatMap { self.snapshot(forPath: $0) }
            return CodexTaskStateResolver.observation(
                session: session,
                snapshot: snapshot,
                now: now
            )
        }
    }

    private func snapshot(forPath path: String) -> CodexRolloutSnapshot? {
        let attributes = try? FileManager.default.attributesOfItem(atPath: path)
        guard let fileSize = (attributes?[.size] as? NSNumber)?.uint64Value else {
            return self.cursors[path]?.reducer.snapshot
        }
        let fileIdentifier = (attributes?[.systemFileNumber] as? NSNumber)?.uint64Value
        var cursor = self.cursors[path] ?? Cursor()

        if cursor.fileIdentifier != fileIdentifier || fileSize < cursor.byteOffset {
            cursor = Cursor(fileIdentifier: fileIdentifier)
        } else if cursor.fileIdentifier == nil {
            cursor.fileIdentifier = fileIdentifier
        }

        guard fileSize > cursor.byteOffset else {
            self.cursors[path] = cursor
            return cursor.reducer.snapshot
        }

        do {
            let handle = try FileHandle(forReadingFrom: URL(fileURLWithPath: path))
            defer { try? handle.close() }
            try handle.seek(toOffset: cursor.byteOffset)

            while let chunk = try handle.read(upToCount: Self.readChunkSize), !chunk.isEmpty {
                cursor.byteOffset += UInt64(chunk.count)
                self.consume(chunk: chunk, cursor: &cursor)
            }
        } catch {
            self.cursors[path] = cursor
            return cursor.reducer.snapshot
        }

        self.cursors[path] = cursor
        return cursor.reducer.snapshot
    }

    private func consume(chunk: Data, cursor: inout Cursor) {
        var remaining = chunk
        if cursor.isDiscardingOversizedLine {
            guard let newline = remaining.firstIndex(of: 0x0A) else { return }
            remaining = Data(remaining[remaining.index(after: newline)...])
            cursor.isDiscardingOversizedLine = false
        }

        cursor.bufferedData.append(remaining)
        while let newline = cursor.bufferedData.firstIndex(of: 0x0A) {
            let line = Data(cursor.bufferedData[..<newline])
            cursor.bufferedData.removeSubrange(...newline)
            if line.count <= Self.maximumLineSize {
                cursor.reducer.consume(line: line)
            }
        }

        if cursor.bufferedData.count > Self.maximumLineSize {
            cursor.bufferedData.removeAll(keepingCapacity: false)
            cursor.isDiscardingOversizedLine = true
        }
    }
}

struct CodexRolloutReducer {
    private struct PendingCall {
        let action: String
    }

    private var pendingCalls: [String: PendingCall] = [:]
    private var pendingCallOrder: [String] = []
    private var callNames: [String: String] = [:]
    private var pollingTargets: [String: String] = [:]
    private var runningCallsByHandle: [String: String] = [:]
    private var thinkingSince: Date?
    private var rateLimited = false
    private var lastEventAt: Date?
    private var parsedEventCount = 0
    private var isTurnActive: Bool?

    var snapshot: CodexRolloutSnapshot {
        let currentAction = self.pendingCallOrder.reversed().compactMap { self.pendingCalls[$0]?.action }.first
        return CodexRolloutSnapshot(
            hasParsedEvents: self.parsedEventCount > 0,
            isThinking: self.thinkingSince != nil,
            isRateLimited: self.rateLimited,
            hasPendingToolCall: !self.pendingCalls.isEmpty,
            currentAction: currentAction,
            lastEventAt: self.lastEventAt,
            isTurnActive: self.isTurnActive
        )
    }

    mutating func consume(line: String) {
        guard let data = line.data(using: .utf8) else { return }
        self.consume(line: data)
    }

    mutating func consume(line: Data) {
        guard let object = try? JSONSerialization.jsonObject(with: line) as? [String: Any],
              let outerType = object["type"] as? String
        else { return }

        self.parsedEventCount += 1
        let eventDate = Self.eventDate(object["timestamp"])
        if let eventDate, eventDate > self.lastEventAt ?? .distantPast {
            self.lastEventAt = eventDate
        }

        switch outerType {
        case "event_msg":
            self.consumeEvent(payload: object["payload"] as? [String: Any] ?? [:], eventDate: eventDate)
        case "response_item":
            self.consumeResponseItem(payload: object["payload"] as? [String: Any] ?? [:])
        default:
            break
        }
    }

    private mutating func consumeEvent(payload: [String: Any], eventDate: Date?) {
        guard let eventType = payload["type"] as? String else { return }
        switch eventType {
        case "task_started":
            self.isTurnActive = true
            self.thinkingSince = eventDate ?? self.lastEventAt ?? Date()
        case "user_message":
            self.isTurnActive = true
            self.thinkingSince = eventDate ?? self.lastEventAt ?? Date()
        case "agent_message":
            self.thinkingSince = nil
        case "task_complete":
            self.isTurnActive = false
            self.thinkingSince = nil
            self.closeAllCalls()
        case "turn_aborted":
            self.isTurnActive = false
            self.thinkingSince = nil
            self.closeAllCalls()
        case "token_count":
            self.updateRateLimit(from: payload["rate_limits"])
        default:
            if eventType.hasSuffix("_end"), let callID = Self.string(payload["call_id"]) {
                self.closeCall(callID)
            }
        }
    }

    private mutating func consumeResponseItem(payload: [String: Any]) {
        guard let itemType = payload["type"] as? String else { return }
        switch itemType {
        case "function_call", "custom_tool_call":
            self.openCall(payload: payload)
        case "function_call_output", "custom_tool_call_output":
            self.consumeToolOutput(payload: payload)
        default:
            break
        }
    }

    private mutating func openCall(payload: [String: Any]) {
        guard let name = payload["name"] as? String,
              let callID = Self.string(payload["call_id"]) ?? Self.string(payload["id"])
        else { return }

        let rawInput = payload["arguments"] ?? payload["input"]
        let action = CodexToolActionFormatter.action(toolName: name, rawInput: rawInput)
        self.callNames[callID] = name
        self.pendingCalls[callID] = PendingCall(action: action)
        self.pendingCallOrder.removeAll { $0 == callID }
        self.pendingCallOrder.append(callID)
        self.thinkingSince = nil

        if Self.isPollingTool(name),
           let target = CodexToolActionFormatter.targetHandle(rawInput: rawInput) {
            self.pollingTargets[callID] = target
        }
    }

    private mutating func consumeToolOutput(payload: [String: Any]) {
        guard let callID = Self.string(payload["call_id"]) ?? Self.string(payload["id"]) else { return }
        let outputText = Self.flattenedOutputText(payload["output"], characterLimit: 4096)
        let toolName = self.callNames[callID] ?? ""

        if Self.isExecutionTool(toolName), let handle = Self.runningHandle(in: outputText) {
            self.runningCallsByHandle[handle] = callID
            return
        }

        if Self.isPollingTool(toolName) {
            let target = self.pollingTargets[callID]
            self.closeCall(callID)
            guard let target,
                  !Self.outputReportsStillRunning(outputText),
                  let runningCallID = self.runningCallsByHandle.removeValue(forKey: target)
            else { return }
            self.closeCall(runningCallID)
            return
        }

        self.closeCall(callID)
    }

    private mutating func updateRateLimit(from rawValue: Any?) {
        guard let value = rawValue as? [String: Any] else { return }
        if let limitID = value["limit_id"] as? String, limitID != "codex" {
            return
        }
        let percentages = ["primary", "secondary"].compactMap { slot -> Double? in
            guard let window = value[slot] as? [String: Any] else { return nil }
            return (window["used_percent"] as? NSNumber)?.doubleValue
        }
        guard !percentages.isEmpty else { return }
        self.rateLimited = percentages.contains { $0 >= 100 }
    }

    private mutating func closeCall(_ callID: String) {
        self.pendingCalls.removeValue(forKey: callID)
        self.pendingCallOrder.removeAll { $0 == callID }
        self.callNames.removeValue(forKey: callID)
        self.pollingTargets.removeValue(forKey: callID)
        self.runningCallsByHandle = self.runningCallsByHandle.filter { $0.value != callID }
    }

    private mutating func closeAllCalls() {
        self.pendingCalls.removeAll()
        self.pendingCallOrder.removeAll()
        self.callNames.removeAll()
        self.pollingTargets.removeAll()
        self.runningCallsByHandle.removeAll()
    }

    private static func eventDate(_ rawValue: Any?) -> Date? {
        guard let value = rawValue as? String else { return nil }
        return try? Date(value, strategy: .iso8601)
    }

    private static func string(_ rawValue: Any?) -> String? {
        if let value = rawValue as? String {
            return value
        }
        if let value = rawValue as? NSNumber {
            return value.stringValue
        }
        return nil
    }

    private static func isExecutionTool(_ name: String) -> Bool {
        name == "exec" || name == "exec_command"
    }

    private static func isPollingTool(_ name: String) -> Bool {
        name == "wait" || name == "write_stdin"
    }

    private static func runningHandle(in output: String) -> String? {
        let markers = [
            "Process running with session ID ",
            "Script running with cell ID "
        ]
        for marker in markers {
            guard let range = output.range(of: marker) else { continue }
            let suffix = output[range.upperBound...]
            let value = suffix.prefix { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }
            if !value.isEmpty {
                return String(value)
            }
        }
        return nil
    }

    private static func outputReportsStillRunning(_ output: String) -> Bool {
        self.runningHandle(in: output) != nil || output.localizedCaseInsensitiveContains("still running")
    }

    private static func flattenedOutputText(_ rawValue: Any?, characterLimit: Int) -> String {
        var result = ""
        self.appendText(from: rawValue, to: &result, characterLimit: characterLimit)
        return result
    }

    private static func appendText(from rawValue: Any?, to result: inout String, characterLimit: Int) {
        guard result.count < characterLimit, let rawValue else { return }
        if let value = rawValue as? String {
            result.append(contentsOf: value.prefix(characterLimit - result.count))
            return
        }
        if let values = rawValue as? [Any] {
            for value in values {
                self.appendText(from: value, to: &result, characterLimit: characterLimit)
            }
            return
        }
        if let values = rawValue as? [String: Any] {
            for key in ["text", "output", "message", "content"] {
                self.appendText(from: values[key], to: &result, characterLimit: characterLimit)
            }
        }
    }
}
