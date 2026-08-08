import Foundation
#if canImport(SQLite3)
import SQLite3
#elseif canImport(CSQLite3)
import CSQLite3
#endif
import Testing
@testable import CodexBarCore

struct CodexSessionRolloutTests {
    @Test
    func `rollout metadata cache survives appends and reparses truncation`() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("CodexRolloutMetadataCacheTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("rollout-cache.jsonl")
        let first =
            "{\"type\":\"session_meta\",\"payload\":{\"id\":\"a-very-long-session-identifier\",\"cwd\":\"/repo\"}}\n"
        try first.write(to: url, atomically: true, encoding: .utf8)
        let cache = CodexRolloutMetadataCache(maximumEntryCount: 4)

        #expect(cache.metadata(for: url)?.sessionID == "a-very-long-session-identifier")
        let handle = try FileHandle(forWritingTo: url)
        try handle.seekToEnd()
        try handle.write(contentsOf: Data("{\"type\":\"event_msg\"}\n".utf8))
        try handle.close()
        #expect(cache.metadata(for: url)?.sessionID == "a-very-long-session-identifier")

        let replacement = "{\"type\":\"session_meta\",\"payload\":{\"id\":\"new\",\"cwd\":\"/repo\"}}\n"
        try replacement.write(to: url, atomically: false, encoding: .utf8)
        #expect(cache.metadata(for: url)?.sessionID == "new")
    }

    @Test
    func `codex only scanner excludes Claude before session correlation`() async {
        let scanner = LocalAgentSessionScanner(
            config: SessionScanConfig(providerScope: .codexOnly),
            processOutputProvider: { _ in
                """
                201 1 Tue Jul 28 09:03:00 2026 /usr/local/bin/codex exec
                202 1 Tue Jul 28 09:03:00 2026 /usr/local/bin/claude
                """
            },
            cwdProvider: { _, _ in [201: "/codex", 202: "/claude"] })

        let sessions = await scanner.scan(
            environment: ["HOME": "/tmp", "PATH": "/usr/bin:/bin"],
            includeFileOnlySessions: false)

        #expect(sessions.map(\.provider) == [.codex])
        #expect(sessions.map(\.pid) == [201])
    }

    @Test
    func `first rollout line maps to file only agent session`() throws {
        let url = try AgentSessionParserTests.fixtureURL("agent-session-rollout", extension: "jsonl")
        let metadata = try #require(CodexRolloutFirstLineParser.read(from: url))
        let now = Date(timeIntervalSince1970: 10000)
        let modifiedAt = now.addingTimeInterval(-60)
        let session = try #require(CodexRolloutFirstLineParser.makeSession(
            metadata: metadata,
            transcriptURL: url,
            modifiedAt: modifiedAt,
            host: "local-mac",
            now: now))

        #expect(session.id == "019f-session-fixture")
        #expect(session.cwd == "/Users/test/Projects/alpha")
        #expect(session.projectName == "alpha")
        #expect(session.startedAt == Date(timeIntervalSince1970: 1_783_353_600))
        #expect(session.source == .cli)
        #expect(session.state == .active)
        #expect(session.pid == nil)
    }

    @Test
    func `file only rollout outside window is excluded while live process remains`() throws {
        let url = try AgentSessionParserTests.fixtureURL("agent-session-rollout", extension: "jsonl")
        let metadata = try #require(CodexRolloutFirstLineParser.read(from: url))
        let now = Date(timeIntervalSince1970: 10000)
        let modifiedAt = now.addingTimeInterval(-1801)

        #expect(CodexRolloutFirstLineParser.makeSession(
            metadata: metadata,
            transcriptURL: url,
            modifiedAt: modifiedAt,
            host: "local-mac",
            now: now) == nil)
        #expect(CodexRolloutFirstLineParser.makeSession(
            metadata: metadata,
            transcriptURL: url,
            modifiedAt: modifiedAt,
            pid: 42,
            host: "local-mac",
            now: now)?.state == .idle)
    }

    @Test
    func `app server presence classifies unknown file only rollout as desktop`() {
        #expect(AgentSessionCorrelation.fileOnlyCodexSource(
            metadataSource: .unknown,
            appServerPresent: true) == .desktopApp)
        #expect(AgentSessionCorrelation.fileOnlyCodexSource(
            metadataSource: .unknown,
            appServerPresent: false) == .unknown)
    }

    @Test
    func `explicit exec source wins over bundled Desktop originator`() {
        let metadata = CodexRolloutMetadata(
            sessionID: "cli",
            cwd: "/private/tmp/m3",
            originator: "Codex Desktop",
            source: "exec")

        #expect(metadata.sessionSource == .cli)
    }

    @Test
    func `codex cwd matching rejects missing paths`() {
        #expect(AgentSessionCorrelation.codexWorkingDirectoriesMatch("/repo/alpha", "/repo/./alpha"))
        #expect(!AgentSessionCorrelation.codexWorkingDirectoriesMatch(nil, nil))
        #expect(!AgentSessionCorrelation.codexWorkingDirectoriesMatch("/repo/alpha", nil))
    }

    @Test
    func `local scanner parses only its newest configured rollout candidates`() async throws {
        let fileManager = FileManager.default
        let temporaryRoot = fileManager.temporaryDirectory
            .appendingPathComponent("CodexSessionRolloutTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? fileManager.removeItem(at: temporaryRoot) }

        let now = Date()
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy/MM/dd"
        let codexHome = temporaryRoot.appendingPathComponent("codex-home", isDirectory: true)
        let sessionDirectory = codexHome
            .appendingPathComponent("sessions", isDirectory: true)
            .appendingPathComponent(formatter.string(from: now), isDirectory: true)
        try fileManager.createDirectory(at: sessionDirectory, withIntermediateDirectories: true)

        let fixtureURL = try AgentSessionParserTests.fixtureURL("agent-session-rollout", extension: "jsonl")
        let fixture = try String(contentsOf: fixtureURL, encoding: .utf8)
        for (index, age) in [30.0, 20.0, -3600.0].enumerated() {
            let id = "bounded-rollout-\(index)"
            let url = sessionDirectory.appendingPathComponent("rollout-bounded-\(index).jsonl")
            try fixture
                .replacingOccurrences(of: "019f-session-fixture", with: id)
                .write(to: url, atomically: true, encoding: .utf8)
            try fileManager.setAttributes(
                [.modificationDate: now.addingTimeInterval(-age)],
                ofItemAtPath: url.path)
        }

        let scanner = LocalAgentSessionScanner(config: SessionScanConfig(
            fileOnlyWindow: 60 * 60,
            maxProcessCount: 0,
            maxCodexRolloutCount: 2,
            maxClaudeTranscriptCountPerProject: 0))
        let sessions = await scanner.scan(now: now, environment: [
            "CODEX_HOME": codexHome.path,
            "HOME": temporaryRoot.path,
            "PATH": "/usr/bin:/bin:/usr/sbin:/sbin",
        ])

        #expect(Set(sessions.map(\.id)) == ["bounded-rollout-1", "bounded-rollout-2"])
        #expect(sessions.first(where: { $0.id == "bounded-rollout-2" })?.lastActivityAt == now)

        let rescanned = await scanner.scan(
            now: now.addingTimeInterval(30),
            environment: [
                "CODEX_HOME": codexHome.path,
                "HOME": temporaryRoot.path,
                "PATH": "/usr/bin:/bin:/usr/sbin:/sbin",
            ])
        #expect(rescanned.first(where: { $0.id == "bounded-rollout-2" })?.lastActivityAt == now)
    }

    @Test
    func `local scanner discovers a resumed rollout from an old creation directory`() async throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory
            .appendingPathComponent("CodexSessionRolloutTests-resumed-\(UUID().uuidString)", isDirectory: true)
        defer { try? fileManager.removeItem(at: root) }
        let now = Date(timeIntervalSince1970: 1_785_240_000)
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        let oldDirectory = codexHome
            .appendingPathComponent("sessions/2026/06/01", isDirectory: true)
        try fileManager.createDirectory(at: oldDirectory, withIntermediateDirectories: true)
        let rolloutURL = oldDirectory.appendingPathComponent("rollout-resumed.jsonl")
        try """
        {"type":"session_meta","payload":{"id":"resumed","session_id":"resumed","cwd":"/repo",\
        "originator":"Codex Desktop","source":"vscode"}}

        """.write(to: rolloutURL, atomically: true, encoding: .utf8)
        try fileManager.setAttributes([.modificationDate: now], ofItemAtPath: rolloutURL.path)
        try Self.createRecentThreadDatabase(
            at: codexHome.appendingPathComponent("state_5.sqlite"),
            rows: [
                (id: "resumed", path: rolloutURL.path, updatedAt: now, archived: false),
            ])
        let scanner = LocalAgentSessionScanner(config: SessionScanConfig(
            fileOnlyWindow: 24 * 60 * 60,
            maxProcessCount: 0,
            maxCodexRolloutCount: 8,
            maxClaudeTranscriptCountPerProject: 0))

        let sessions = await scanner.scan(now: now, environment: [
            "CODEX_HOME": codexHome.path,
            "HOME": root.path,
            "PATH": "/usr/bin:/bin:/usr/sbin:/sbin",
        ])

        #expect(sessions.map(\.id) == ["resumed"])
        #expect(sessions.first?.lastActivityAt == now)
        #expect(sessions.first?.transcriptPath == rolloutURL.standardizedFileURL.path)
    }

    @Test
    func `indexed rollout discovery rejects archived stale and escaping paths`() async throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory
            .appendingPathComponent("CodexSessionRolloutTests-index-guard-\(UUID().uuidString)", isDirectory: true)
        defer { try? fileManager.removeItem(at: root) }
        let now = Date(timeIntervalSince1970: 1_785_240_000)
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        let oldDirectory = codexHome
            .appendingPathComponent("sessions/2026/06/01", isDirectory: true)
        try fileManager.createDirectory(at: oldDirectory, withIntermediateDirectories: true)
        let archivedURL = oldDirectory.appendingPathComponent("rollout-archived.jsonl")
        let staleURL = oldDirectory.appendingPathComponent("rollout-stale.jsonl")
        let escapingURL = root.appendingPathComponent("rollout-escaping.jsonl")
        for (id, url, modifiedAt) in [
            ("archived", archivedURL, now),
            ("stale", staleURL, now.addingTimeInterval(-3601)),
            ("escaping", escapingURL, now),
        ] {
            try """
            {"type":"session_meta","payload":{"id":"\(id)","session_id":"\(id)","cwd":"/repo",\
            "originator":"Codex Desktop","source":"vscode"}}

            """.write(to: url, atomically: true, encoding: .utf8)
            try fileManager.setAttributes([.modificationDate: modifiedAt], ofItemAtPath: url.path)
        }
        try Self.createRecentThreadDatabase(
            at: codexHome.appendingPathComponent("state_5.sqlite"),
            rows: [
                (id: "archived", path: archivedURL.path, updatedAt: now, archived: true),
                (id: "stale", path: staleURL.path, updatedAt: now, archived: false),
                (id: "escaping", path: escapingURL.path, updatedAt: now, archived: false),
            ])
        let scanner = LocalAgentSessionScanner(config: SessionScanConfig(
            fileOnlyWindow: 60 * 60,
            maxProcessCount: 0,
            maxCodexRolloutCount: 8,
            maxClaudeTranscriptCountPerProject: 0))

        let sessions = await scanner.scan(now: now, environment: [
            "CODEX_HOME": codexHome.path,
            "HOME": root.path,
            "PATH": "/usr/bin:/bin:/usr/sbin:/sbin",
        ])

        #expect(sessions.isEmpty)
    }

    @Test
    func `subagent and guardian rollout metadata produce descriptive names`() throws {
        let subagentLine =
            "{\"type\":\"session_meta\",\"payload\":{\"id\":\"subagent\",\"cwd\":\"/repo\"," +
            "\"originator\":\"codex_vscode\",\"source\":{\"subagent\":{\"thread_spawn\":{\"agent_path\":" +
            "\"/root/neon_patch_review2\"}}}}}"
        let guardianLine =
            "{\"type\":\"session_meta\",\"payload\":{\"id\":\"guardian\",\"cwd\":\"/repo\"," +
            "\"originator\":\"codex_vscode\",\"source\":{\"subagent\":{\"other\":\"guardian\"}}}}"

        let subagent = try #require(CodexRolloutFirstLineParser.parse(subagentLine))
        let guardian = try #require(CodexRolloutFirstLineParser.parse(guardianLine))

        #expect(subagent.agentPath == "/root/neon_patch_review2")
        #expect(subagent.isSubagent)
        #expect(subagent.descriptiveName(threadMetadata: nil) == "Neon patch review 2")
        #expect(guardian.isGuardian)
        #expect(guardian.isSubagent)
        #expect(guardian.descriptiveName(threadMetadata: nil) == "Approval review")
    }

    @Test
    func `scanner can exclude subagent rollouts without hiding their parent`() async throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory
            .appendingPathComponent("CodexSessionRolloutTests-parent-\(UUID().uuidString)", isDirectory: true)
        defer { try? fileManager.removeItem(at: root) }
        let now = Date()
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy/MM/dd"
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        let sessionDirectory = codexHome
            .appendingPathComponent("sessions", isDirectory: true)
            .appendingPathComponent(formatter.string(from: now), isDirectory: true)
        try fileManager.createDirectory(at: sessionDirectory, withIntermediateDirectories: true)

        let parentID = "019f-parent"
        let parentURL = sessionDirectory.appendingPathComponent("rollout-parent.jsonl")
        let guardianURL = sessionDirectory.appendingPathComponent("rollout-guardian.jsonl")
        try """
        {"type":"session_meta","payload":{"id":"\(parentID)","session_id":"\(parentID)","cwd":"/repo",\
        "originator":"Codex Desktop","source":"vscode"}}
        """.write(to: parentURL, atomically: true, encoding: .utf8)
        try """
        {"type":"session_meta","payload":{"id":"019f-guardian","session_id":"\(parentID)","cwd":"/repo",\
        "originator":"Codex Desktop","source":{"subagent":{"other":"guardian"}},"parent_thread_id":"\(parentID)"}}
        """.write(to: guardianURL, atomically: true, encoding: .utf8)
        try fileManager.setAttributes(
            [.modificationDate: now.addingTimeInterval(-1)],
            ofItemAtPath: parentURL.path)
        try fileManager.setAttributes(
            [.modificationDate: now],
            ofItemAtPath: guardianURL.path)
        try Self.createGuardianThreadDatabase(
            at: codexHome.appendingPathComponent("state_5.sqlite"),
            sessionID: parentID,
            rolloutPath: parentURL.path,
            includesArchivedColumn: false)

        let scanner = LocalAgentSessionScanner(config: SessionScanConfig(
            fileOnlyWindow: 60,
            maxProcessCount: 0,
            maxCodexRolloutCount: 8,
            maxClaudeTranscriptCountPerProject: 0,
            includeCodexSubagents: false))
        let sessions = await scanner.scan(now: now, environment: [
            "CODEX_HOME": codexHome.path,
            "HOME": root.path,
            "PATH": "/usr/bin:/bin:/usr/sbin:/sbin",
        ])

        #expect(sessions.count == 1)
        #expect(sessions.first?.id == parentID)
        #expect(sessions.first?.transcriptPath.map {
            URL(fileURLWithPath: $0).resolvingSymlinksInPath().path
        } == parentURL.resolvingSymlinksInPath().path)

        let guardianParentScanner = LocalAgentSessionScanner(config: SessionScanConfig(
            fileOnlyWindow: 60,
            maxProcessCount: 0,
            maxCodexRolloutCount: 8,
            maxClaudeTranscriptCountPerProject: 0,
            includeCodexSubagents: false,
            includeCodexGuardianParents: true))
        let guardianParentSessions = await guardianParentScanner.scan(now: now, environment: [
            "CODEX_HOME": codexHome.path,
            "HOME": root.path,
            "PATH": "/usr/bin:/bin:/usr/sbin:/sbin",
        ])

        #expect(guardianParentSessions.count == 1)
        #expect(guardianParentSessions.first?.id == parentID)
        #expect(guardianParentSessions.first?.transcriptPath.map {
            URL(fileURLWithPath: $0).resolvingSymlinksInPath().path
        } == parentURL.resolvingSymlinksInPath().path)
    }

    @Test(arguments: [true, false])
    func `scanner excludes archived guardian parents from current tasks`(
        includesArchivedColumn: Bool) async throws
    {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory
            .appendingPathComponent("CodexSessionRolloutTests-archive-\(UUID().uuidString)", isDirectory: true)
        defer { try? fileManager.removeItem(at: root) }
        let now = Date()
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy/MM/dd"
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        let sessionDirectory = codexHome
            .appendingPathComponent("sessions", isDirectory: true)
            .appendingPathComponent(formatter.string(from: now), isDirectory: true)
        let archiveDirectory = codexHome.appendingPathComponent("archived_sessions", isDirectory: true)
        try fileManager.createDirectory(at: sessionDirectory, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: archiveDirectory, withIntermediateDirectories: true)

        let parentID = "019f-archived-parent"
        let parentURL = archiveDirectory.appendingPathComponent("rollout-parent.jsonl")
        let guardianURL = sessionDirectory.appendingPathComponent("rollout-guardian.jsonl")
        try """
        {"type":"session_meta","payload":{"id":"\(parentID)","session_id":"\(parentID)","cwd":"/repo",\
        "originator":"Codex Desktop","source":"vscode"}}
        """.write(to: parentURL, atomically: true, encoding: .utf8)
        try """
        {"type":"session_meta","payload":{"id":"019f-guardian","session_id":"\(parentID)","cwd":"/repo",\
        "originator":"Codex Desktop","source":{"subagent":{"other":"guardian"}},"parent_thread_id":"\(parentID)"}}
        """.write(to: guardianURL, atomically: true, encoding: .utf8)
        try fileManager.setAttributes([.modificationDate: now], ofItemAtPath: parentURL.path)
        try fileManager.setAttributes([.modificationDate: now], ofItemAtPath: guardianURL.path)
        try Self.createGuardianThreadDatabase(
            at: codexHome.appendingPathComponent("state_5.sqlite"),
            sessionID: parentID,
            rolloutPath: parentURL.path,
            includesArchivedColumn: includesArchivedColumn)

        let scanner = LocalAgentSessionScanner(config: SessionScanConfig(
            fileOnlyWindow: 60,
            maxProcessCount: 0,
            maxCodexRolloutCount: 8,
            maxClaudeTranscriptCountPerProject: 0,
            includeCodexSubagents: false,
            includeCodexGuardianParents: true))
        let sessions = await scanner.scan(now: now, environment: [
            "CODEX_HOME": codexHome.path,
            "HOME": root.path,
            "PATH": "/usr/bin:/bin:/usr/sbin:/sbin",
        ])

        #expect(sessions.isEmpty)
    }

    @Test
    func `scanner caps unknown archive state at two hours`() async throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory
            .appendingPathComponent("CodexSessionRolloutTests-unknown-\(UUID().uuidString)", isDirectory: true)
        defer { try? fileManager.removeItem(at: root) }
        let now = Date()
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy/MM/dd"
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        let sessionDirectory = codexHome
            .appendingPathComponent("sessions", isDirectory: true)
            .appendingPathComponent(formatter.string(from: now), isDirectory: true)
        try fileManager.createDirectory(at: sessionDirectory, withIntermediateDirectories: true)

        for (id, age) in [("recent-unknown", 60.0), ("stale-unknown", 2 * 60 * 60 + 1)] {
            let url = sessionDirectory.appendingPathComponent("rollout-\(id).jsonl")
            try """
            {"type":"session_meta","payload":{"id":"\(id)","session_id":"\(id)","cwd":"/repo",\
            "originator":"Codex Desktop","source":"vscode"}}
            """.write(to: url, atomically: true, encoding: .utf8)
            try fileManager.setAttributes(
                [.modificationDate: now.addingTimeInterval(-age)],
                ofItemAtPath: url.path)
        }

        let scanner = LocalAgentSessionScanner(config: SessionScanConfig(
            fileOnlyWindow: 24 * 60 * 60,
            maxProcessCount: 0,
            maxCodexRolloutCount: 8,
            maxClaudeTranscriptCountPerProject: 0))
        let sessions = await scanner.scan(now: now, environment: [
            "CODEX_HOME": codexHome.path,
            "HOME": root.path,
            "PATH": "/usr/bin:/bin:/usr/sbin:/sbin",
        ])

        #expect(sessions.map(\.id) == ["recent-unknown"])
    }

    @Test
    func `scanner correlates bundled CLI process through its explicit working directory`() async throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory
            .appendingPathComponent("CodexSessionRolloutTests-cli-\(UUID().uuidString)", isDirectory: true)
        defer { try? fileManager.removeItem(at: root) }
        let now = Date()
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy/MM/dd"
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        let sessionDirectory = codexHome
            .appendingPathComponent("sessions", isDirectory: true)
            .appendingPathComponent(formatter.string(from: now), isDirectory: true)
        try fileManager.createDirectory(at: sessionDirectory, withIntermediateDirectories: true)
        let target = root.appendingPathComponent("target", isDirectory: true)
        try fileManager.createDirectory(at: target, withIntermediateDirectories: true)
        let rolloutURL = sessionDirectory.appendingPathComponent("rollout-cli.jsonl")
        try """
        {"type":"session_meta","payload":{"id":"cli-session","session_id":"cli-session","cwd":"\(target.path)",\
        "originator":"Codex Desktop","source":"exec"}}
        """.write(to: rolloutURL, atomically: true, encoding: .utf8)
        try fileManager.setAttributes([.modificationDate: now], ofItemAtPath: rolloutURL.path)

        let scanner = LocalAgentSessionScanner(
            config: SessionScanConfig(
                fileOnlyWindow: 60,
                maxCodexRolloutCount: 8,
                maxClaudeTranscriptCountPerProject: 0,
                includeCodexSubagents: false),
            processOutputProvider: { _ in
                "201 1 Tue Jul 28 09:03:00 2026 " +
                    "/Applications/ChatGPT.app/Contents/Resources/codex exec -C \(target.path)"
            },
            cwdProvider: { _, _ in [201: "/launcher"] })
        let sessions = await scanner.scan(now: now, environment: [
            "CODEX_HOME": codexHome.path,
            "HOME": root.path,
            "PATH": "/usr/bin:/bin:/usr/sbin:/sbin",
        ])

        #expect(sessions.count == 1)
        #expect(sessions.first?.id == "cli-session")
        #expect(sessions.first?.pid == 201)
        #expect(sessions.first?.cwd == target.standardizedFileURL.path)
        #expect(sessions.first?.source == .cli)
    }

    @Test
    func `current rollout agent path produces a descriptive subagent name without sqlite`() throws {
        let line =
            "{\"type\":\"session_meta\",\"payload\":{\"id\":\"subagent\",\"cwd\":\"/repo\"," +
            "\"originator\":\"codex_vscode\",\"source\":\"subagent\"," +
            "\"agent_path\":\"/root/config_audit3\"}}"

        let metadata = try #require(CodexRolloutFirstLineParser.parse(line))

        #expect(metadata.agentPath == "/root/config_audit3")
        #expect(metadata.descriptiveName(threadMetadata: nil) == "Config audit 3")
    }

    @Test
    func `thread titles skip command preambles and stay menu sized`() {
        let metadata = CodexRolloutMetadata(
            sessionID: "main",
            cwd: "/repo",
            originator: "codex_vscode",
            source: "vscode")
        let title = """
        /brain-orient

        Continue work on the Concrete Authority website and compare every current source before changing anything.
        """

        let name = metadata.descriptiveName(threadMetadata: CodexThreadMetadata(
            title: title,
            agentPath: nil))
        #expect(name == "Continue work on the Concrete Authority website and compare eve…")
        #expect(name?.count == 64)
    }

    @Test
    func `live scanner suppresses descriptive names for ambiguous same project processes`() async throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory
            .appendingPathComponent("CodexSessionRolloutTests-ambiguous-\(UUID().uuidString)", isDirectory: true)
        defer { try? fileManager.removeItem(at: root) }

        let now = Date()
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy/MM/dd"
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        let sessionDirectory = codexHome
            .appendingPathComponent("sessions", isDirectory: true)
            .appendingPathComponent(formatter.string(from: now), isDirectory: true)
        try fileManager.createDirectory(at: sessionDirectory, withIntermediateDirectories: true)

        for (index, name) in ["recent_activity", "older_activity"].enumerated() {
            let line =
                "{\"type\":\"session_meta\",\"payload\":{\"id\":\"session-\(index)\",\"cwd\":\"/repo\"," +
                "\"originator\":\"codex_cli\",\"source\":\"exec\",\"agent_path\":\"/root/\(name)\"}}"
            let url = sessionDirectory.appendingPathComponent("rollout-ambiguous-\(index).jsonl")
            try line.write(to: url, atomically: true, encoding: .utf8)
            try fileManager.setAttributes(
                [.modificationDate: now.addingTimeInterval(TimeInterval(-index * 30))],
                ofItemAtPath: url.path)
        }

        let scanner = LocalAgentSessionScanner(
            processOutputProvider: { _ in
                """
                201 1 Mon Jul 6 09:03:00 2026 /usr/local/bin/codex exec
                202 1 Tue Jul 7 09:03:00 2026 /usr/local/bin/codex exec
                """
            },
            cwdProvider: { _, _ in [201: "/repo", 202: "/repo"] })
        let sessions = await scanner.scan(
            now: now,
            environment: [
                "CODEX_HOME": codexHome.path,
                "HOME": root.path,
                "PATH": "/usr/bin:/bin:/usr/sbin:/sbin",
            ],
            includeFileOnlySessions: false)

        #expect(sessions.count == 2)
        #expect(sessions.allSatisfy { $0.projectName == "repo" })
        #expect(sessions.allSatisfy { $0.sessionName == nil })

        let strictScanner = LocalAgentSessionScanner(
            config: SessionScanConfig(requireUnambiguousCodexProcessOwnership: true),
            processOutputProvider: { _ in
                """
                201 1 Mon Jul 6 09:03:00 2026 /usr/local/bin/codex exec
                202 1 Tue Jul 7 09:03:00 2026 /usr/local/bin/codex exec
                """
            },
            cwdProvider: { _, _ in [201: "/repo", 202: "/repo"] })
        let strictSessions = await strictScanner.scan(
            now: now,
            environment: [
                "CODEX_HOME": codexHome.path,
                "HOME": root.path,
                "PATH": "/usr/bin:/bin:/usr/sbin:/sbin",
            ],
            includeFileOnlySessions: true)

        #expect(strictSessions.count == 2)
        #expect(strictSessions.allSatisfy { $0.pid == nil })
        #expect(Set(strictSessions.map(\.id)) == ["session-0", "session-1"])
    }

    #if canImport(SQLite3) || canImport(CSQLite3)
    @Test
    func `scanner resolves relative sqlite homes for multiple session projects`() async throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory
            .appendingPathComponent("CodexSessionRolloutTests-relative-sqlite-\(UUID().uuidString)", isDirectory: true)
        defer { try? fileManager.removeItem(at: root) }
        let now = Date()
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy/MM/dd"
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        let sessionDirectory = codexHome
            .appendingPathComponent("sessions", isDirectory: true)
            .appendingPathComponent(formatter.string(from: now), isDirectory: true)
        try fileManager.createDirectory(at: sessionDirectory, withIntermediateDirectories: true)

        for index in 0..<2 {
            let project = root.appendingPathComponent("project-\(index)", isDirectory: true)
            let sqliteHome = project.appendingPathComponent("relative-state", isDirectory: true)
            try fileManager.createDirectory(at: sqliteHome, withIntermediateDirectories: true)
            let sessionID = "relative-session-\(index)"
            let line =
                "{\"type\":\"session_meta\",\"payload\":{\"id\":\"\(sessionID)\",\"cwd\":\"\(project.path)\"," +
                "\"originator\":\"codex_cli\",\"source\":\"cli\"}}"
            try line.write(
                to: sessionDirectory.appendingPathComponent("rollout-relative-\(index).jsonl"),
                atomically: true,
                encoding: .utf8)
            try Self.createThreadDatabase(
                at: sqliteHome.appendingPathComponent("state_5.sqlite"),
                sessionID: sessionID,
                title: "Project \(index) title")
        }

        let scanner = LocalAgentSessionScanner(config: SessionScanConfig(
            maxProcessCount: 0,
            maxClaudeTranscriptCountPerProject: 0))
        let sessions = await scanner.scan(now: now, environment: [
            "CODEX_HOME": codexHome.path,
            "CODEX_SQLITE_HOME": "relative-state",
            "HOME": root.path,
            "PATH": "/usr/bin:/bin:/usr/sbin:/sbin",
        ])

        #expect(Dictionary(uniqueKeysWithValues: sessions.map { ($0.id, $0.sessionName) }) == [
            "relative-session-0": "Project 0 title",
            "relative-session-1": "Project 1 title",
        ])
    }

    private static func createThreadDatabase(
        at url: URL,
        sessionID: String,
        title: String) throws
    {
        var database: OpaquePointer?
        guard sqlite3_open(url.path, &database) == SQLITE_OK, let database else {
            throw SQLiteFixtureError.open
        }
        defer { sqlite3_close(database) }
        guard sqlite3_exec(
            database,
            "CREATE TABLE threads (id TEXT PRIMARY KEY, title TEXT, agent_path TEXT);",
            nil,
            nil,
            nil) == SQLITE_OK
        else { throw SQLiteFixtureError.exec }
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(
            database,
            "INSERT INTO threads (id, title, agent_path) VALUES (?1, ?2, NULL);",
            -1,
            &statement,
            nil) == SQLITE_OK,
            let statement
        else { throw SQLiteFixtureError.exec }
        defer { sqlite3_finalize(statement) }
        let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        sqlite3_bind_text(statement, 1, sessionID, -1, transient)
        sqlite3_bind_text(statement, 2, title, -1, transient)
        guard sqlite3_step(statement) == SQLITE_DONE else { throw SQLiteFixtureError.exec }
    }

    private static func createGuardianThreadDatabase(
        at url: URL,
        sessionID: String,
        rolloutPath: String,
        includesArchivedColumn: Bool) throws
    {
        var database: OpaquePointer?
        guard sqlite3_open(url.path, &database) == SQLITE_OK, let database else {
            throw SQLiteFixtureError.open
        }
        defer { sqlite3_close(database) }
        let archivedColumn = includesArchivedColumn ? ", archived INTEGER" : ""
        guard sqlite3_exec(
            database,
            "CREATE TABLE threads (" +
                "id TEXT PRIMARY KEY, title TEXT, agent_path TEXT, rollout_path TEXT\(archivedColumn));",
            nil,
            nil,
            nil) == SQLITE_OK
        else { throw SQLiteFixtureError.exec }
        let archivedValue = includesArchivedColumn ? ", 1" : ""
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(
            database,
            "INSERT INTO threads (id, title, agent_path, rollout_path" +
                (includesArchivedColumn ? ", archived" : "") +
                ") VALUES (?1, 'Guardian parent', NULL, ?2\(archivedValue));",
            -1,
            &statement,
            nil) == SQLITE_OK,
            let statement
        else { throw SQLiteFixtureError.exec }
        defer { sqlite3_finalize(statement) }
        let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        sqlite3_bind_text(statement, 1, sessionID, -1, transient)
        sqlite3_bind_text(statement, 2, rolloutPath, -1, transient)
        guard sqlite3_step(statement) == SQLITE_DONE else { throw SQLiteFixtureError.exec }
    }

    private static func createRecentThreadDatabase(
        at url: URL,
        rows: [(id: String, path: String, updatedAt: Date, archived: Bool)]) throws
    {
        var database: OpaquePointer?
        guard sqlite3_open(url.path, &database) == SQLITE_OK, let database else {
            throw SQLiteFixtureError.open
        }
        defer { sqlite3_close(database) }
        guard sqlite3_exec(
            database,
            "CREATE TABLE threads (" +
                "id TEXT PRIMARY KEY, title TEXT, agent_path TEXT, rollout_path TEXT, " +
                "archived INTEGER, updated_at INTEGER);",
            nil,
            nil,
            nil) == SQLITE_OK
        else { throw SQLiteFixtureError.exec }
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(
            database,
            "INSERT INTO threads VALUES (?1, ?2, NULL, ?3, ?4, ?5);",
            -1,
            &statement,
            nil) == SQLITE_OK,
            let statement
        else { throw SQLiteFixtureError.exec }
        defer { sqlite3_finalize(statement) }
        let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        for row in rows {
            sqlite3_reset(statement)
            sqlite3_clear_bindings(statement)
            sqlite3_bind_text(statement, 1, row.id, -1, transient)
            sqlite3_bind_text(statement, 2, row.id, -1, transient)
            sqlite3_bind_text(statement, 3, row.path, -1, transient)
            sqlite3_bind_int(statement, 4, row.archived ? 1 : 0)
            sqlite3_bind_int64(statement, 5, Int64(row.updatedAt.timeIntervalSince1970))
            guard sqlite3_step(statement) == SQLITE_DONE else { throw SQLiteFixtureError.exec }
        }
    }

    private enum SQLiteFixtureError: Error {
        case open
        case exec
    }
    #endif
}
