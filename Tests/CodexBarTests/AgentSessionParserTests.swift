import CodexBarCore
import Foundation
import Testing

struct AgentSessionParserTests {
    @Test
    func `ps parser deduplicates desktop wrapper and excludes app server and helpers`() throws {
        let output = try Self.fixtureString("agent-sessions-ps", extension: "txt")
        let records = AgentPSOutputParser.parse(output)
        let agents = AgentPSOutputParser.agentProcesses(from: records)

        #expect(records.count == 9)
        #expect(agents.map(\ .pid) == [102, 201])
        #expect(AgentPSOutputParser.provider(for: agents[0]) == .claude)
        #expect(AgentPSOutputParser.source(for: agents[0]) == .desktopApp)
        #expect(AgentPSOutputParser.provider(for: agents[1]) == .codex)
        #expect(agents[1].command.hasSuffix("strange argv here"))
        #expect(AgentPSOutputParser.hasCodexAppServer(in: records))
    }

    @Test
    func `ps parser excludes Codex sandbox helpers while keeping real CLI tasks`() {
        let records = [
            AgentProcessRecord(
                pid: 201,
                ppid: 1,
                startedAt: nil,
                command: "/Applications/ChatGPT.app/Contents/Resources/codex sandbox -c permissions=node_repl"),
            AgentProcessRecord(
                pid: 202,
                ppid: 1,
                startedAt: nil,
                command: "/Applications/ChatGPT.app/Contents/Resources/codex exec --full-auto"),
        ]

        #expect(AgentPSOutputParser.agentProcesses(from: records).map(\.pid) == [202])
    }

    @Test
    func `ps parser reads explicit Codex CLI working directories`() {
        #expect(AgentPSOutputParser.codexWorkingDirectoryArgument(
            "/Applications/ChatGPT.app/Contents/Resources/codex exec -C /private/tmp/m3"
        ) == "/private/tmp/m3")
        #expect(AgentPSOutputParser.codexWorkingDirectoryArgument(
            "codex exec --cd=relative-project"
        ) == "relative-project")
        #expect(AgentPSOutputParser.codexWorkingDirectoryArgument("codex exec") == nil)
    }

    @Test
    func `lsof parser maps batched cwd records`() throws {
        let output = try Self.fixtureString("agent-sessions-lsof", extension: "txt")
        let paths = LSOFCWDOutputParser.parse(output)

        #expect(paths[102] == "/Users/test/Projects/alpha")
        #expect(paths[201] == "/Users/test/Projects/project with spaces")
    }

    @Test
    func `same cwd processes remain uncorrelated when ownership is ambiguous`() {
        let olderStart = Date(timeIntervalSince1970: 100)
        let newerStart = Date(timeIntervalSince1970: 200)
        let older = AgentProcessRecord(pid: 10, ppid: 1, startedAt: olderStart, command: "claude")
        let newer = AgentProcessRecord(pid: 20, ppid: 1, startedAt: newerStart, command: "claude")
        let olderTranscript = ClaudeSessionProjectMapper.Transcript(
            url: URL(fileURLWithPath: "/tmp/older.jsonl"),
            modifiedAt: Date(timeIntervalSince1970: 150))
        let newerTranscript = ClaudeSessionProjectMapper.Transcript(
            url: URL(fileURLWithPath: "/tmp/newer.jsonl"),
            modifiedAt: Date(timeIntervalSince1970: 250))

        let assignments = AgentSessionCorrelation.assignClaudeTranscripts(
            processes: [older, newer],
            cwdByPID: [10: "/project", 20: "/project"],
            transcriptsByCWD: ["/project": [newerTranscript, olderTranscript]])

        #expect(assignments.isEmpty)
    }

    @Test
    func `newest process sorts first for rollout correlation`() {
        let older = AgentProcessRecord(
            pid: 10,
            ppid: 1,
            startedAt: Date(timeIntervalSince1970: 100),
            command: "codex exec")
        let newer = AgentProcessRecord(
            pid: 20,
            ppid: 1,
            startedAt: Date(timeIntervalSince1970: 200),
            command: "codex exec")

        #expect(AgentSessionCorrelation.newestProcessesFirst([older, newer]).map(\ .pid) == [20, 10])
    }

    static func fixtureURL(_ name: String, extension fileExtension: String) throws -> URL {
        try #require(Bundle.module.url(forResource: name, withExtension: fileExtension, subdirectory: "Fixtures"))
    }

    static func fixtureString(_ name: String, extension fileExtension: String) throws -> String {
        try String(contentsOf: self.fixtureURL(name, extension: fileExtension), encoding: .utf8)
    }
}
