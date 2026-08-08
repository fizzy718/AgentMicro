import CodexBarCore
import Foundation

enum AgentMicroSessionPolicy {
    static var scannerConfiguration: SessionScanConfig {
        SessionScanConfig(
            fileOnlyWindow: 24 * 60 * 60,
            includeCodexSubagents: false,
            includeCodexGuardianParents: true,
            requireUnambiguousCodexProcessOwnership: true,
            providerScope: .codexOnly)
    }
}

struct AgentMicroDiagnosticRecord: Codable, Equatable, Sendable {
    let id: String
    let projectName: String?
    let source: String
    let state: String
    let usesFastModel: Bool
    let currentAction: String?
    let pid: Int32?
    let lastEventAt: Date?
    let transcriptFile: String?
}

struct AgentMicroDiagnosticSnapshot: Codable, Equatable, Sendable {
    let elapsedMilliseconds: Double
    let tasks: [AgentMicroDiagnosticRecord]
}

enum AgentMicroDiagnostics {
    static func records(now: Date = Date()) async -> [AgentMicroDiagnosticRecord] {
        let scanner = LocalAgentSessionScanner(config: AgentMicroSessionPolicy.scannerConfiguration)
        let sessions = await scanner.scan(now: now)
        let engine = CodexTaskStateEngine()
        let tasks = await engine.observe(
            sessions: sessions.filter { $0.provider == .codex },
            now: now)
        return tasks.map { task in
            AgentMicroDiagnosticRecord(
                id: task.session.id,
                projectName: task.session.projectName,
                source: task.session.source.rawValue,
                state: task.state.rawValue,
                usesFastModel: task.usesFastModel,
                currentAction: task.currentAction,
                pid: task.session.pid,
                lastEventAt: task.lastEventAt,
                transcriptFile: task.session.transcriptPath.map {
                    URL(fileURLWithPath: $0).lastPathComponent
                })
        }
    }

    static func writeSnapshot() async throws {
        let startedAt = Date()
        let tasks = await self.records()
        let snapshot = AgentMicroDiagnosticSnapshot(
            elapsedMilliseconds: Date().timeIntervalSince(startedAt) * 1000,
            tasks: tasks)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(snapshot)
        FileHandle.standardOutput.write(data)
        FileHandle.standardOutput.write(Data("\n".utf8))
    }

    @MainActor
    static func focus(sessionID: String) async -> SessionFocusResult {
        let scanner = LocalAgentSessionScanner(config: AgentMicroSessionPolicy.scannerConfiguration)
        let sessions = await scanner.scan()
        guard let session = sessions.first(where: { $0.id == sessionID }) else {
            return .failed
        }
        return SessionWindowFocuser.focus(session, promptForAccessibility: false)
    }
}
