import Foundation

final class FutureModificationDateClamp: @unchecked Sendable {
    private let lock = NSLock()
    private var clampDate: Date?

    init(clampDate: Date? = nil) {
        self.clampDate = clampDate
    }

    func clamp(url _: URL, modifiedAt: Date, now: Date) -> Date {
        guard modifiedAt > now else { return modifiedAt }
        return self.lock.withLock {
            if let clampDate = self.clampDate {
                return min(clampDate, now)
            }
            self.clampDate = now
            return now
        }
    }
}

public struct LocalAgentSessionScanner: Sendable {
    typealias ProcessOutputProvider = @Sendable ([String: String]) async -> String
    typealias CWDProvider = @Sendable ([Int32], [String: String]) async -> [Int32: String]
    static let unknownArchiveStateRetention: TimeInterval = 2 * 60 * 60

    private struct Rollout: Sendable {
        let url: URL
        let modifiedAt: Date
        let metadata: CodexRolloutMetadata
    }

    private struct ScanContext: Sendable {
        let homeDirectory: URL
        let codexHomeDirectory: URL
        let host: String
        let now: Date
        let codexAppServerPresent: Bool
        let includeFileOnlySessions: Bool
        let threadMetadata: [String: CodexThreadMetadata]
    }

    public let config: SessionScanConfig
    private let futureModificationDateClamp = FutureModificationDateClamp()
    private let processOutputProvider: ProcessOutputProvider?
    private let cwdProvider: CWDProvider?
    private let didVisitDirectoryEntry: (@Sendable () -> Void)?

    public init(config: SessionScanConfig = SessionScanConfig()) {
        self.config = config
        self.processOutputProvider = nil
        self.cwdProvider = nil
        self.didVisitDirectoryEntry = nil
    }

    init(
        config: SessionScanConfig = SessionScanConfig(),
        processOutputProvider: @escaping ProcessOutputProvider,
        cwdProvider: @escaping CWDProvider,
        didVisitDirectoryEntry: (@Sendable () -> Void)? = nil)
    {
        self.config = config
        self.processOutputProvider = processOutputProvider
        self.cwdProvider = cwdProvider
        self.didVisitDirectoryEntry = didVisitDirectoryEntry
    }

    @concurrent
    public func scan(
        now: Date = Date(),
        environment: [String: String] = ProcessInfo.processInfo.environment,
        includeFileOnlySessions: Bool = true) async -> [AgentSession]
    {
        let processOutput = if let processOutputProvider = self.processOutputProvider {
            await processOutputProvider(environment)
        } else {
            await self.processOutput(environment: environment)
        }
        let allProcesses = AgentPSOutputParser.parse(processOutput)
        let processes = Array(AgentSessionCorrelation.newestProcessesFirst(
            AgentPSOutputParser.agentProcesses(from: allProcesses))
            .prefix(max(0, self.config.maxProcessCount)))
        guard Self.shouldScanSessionMetadata(
            hasAgentProcesses: !processes.isEmpty,
            includeFileOnlySessions: includeFileOnlySessions)
        else { return [] }
        let codexAppServerPresent = AgentPSOutputParser.hasCodexAppServer(in: allProcesses)
        var cwdByPID = if let cwdProvider = self.cwdProvider {
            await cwdProvider(processes.map(\ .pid), environment)
        } else {
            await self.cwdByPID(processes.map(\ .pid), environment: environment)
        }
        for process in processes where AgentPSOutputParser.provider(for: process) == .codex {
            guard let configuredCWD = AgentPSOutputParser.codexWorkingDirectoryArgument(process.command) else {
                continue
            }
            if configuredCWD.hasPrefix("/") {
                cwdByPID[process.pid] = URL(fileURLWithPath: configuredCWD).standardizedFileURL.path
            } else if let processCWD = cwdByPID[process.pid] {
                cwdByPID[process.pid] = URL(fileURLWithPath: processCWD, isDirectory: true)
                    .appendingPathComponent(configuredCWD)
                    .standardizedFileURL.path
            }
        }
        let codexCWDs = processes.compactMap { process -> String? in
            guard AgentPSOutputParser.provider(for: process) == .codex else { return nil }
            return cwdByPID[process.pid]
        }
        let homeDirectory = URL(fileURLWithPath: environment["HOME"] ?? NSHomeDirectory(), isDirectory: true)
        let codexHomeDirectory = URL(
            fileURLWithPath: environment["CODEX_HOME"] ?? homeDirectory.appendingPathComponent(".codex").path,
            isDirectory: true)
        let host = ProcessInfo.processInfo.hostName
        var directoryBudget = DirectoryMetadataScanBudget(
            maxEntryCount: self.config.maxDirectoryEntryCount,
            maxDepth: self.config.maxDirectoryDepth,
            timeLimit: includeFileOnlySessions
                ? self.config.directoryScanBudget
                : min(self.config.directoryScanBudget, self.config.adaptiveDirectoryScanBudget),
            didVisitEntry: self.didVisitDirectoryEntry)
        let rollouts: [Rollout] = if includeFileOnlySessions || !codexCWDs.isEmpty {
            self.codexRollouts(
                now: now,
                codexHomeDirectory: codexHomeDirectory,
                matchingCWDs: includeFileOnlySessions ? nil : codexCWDs,
                directoryBudget: &directoryBudget)
        } else {
            []
        }
        let threadMetadata = Self.codexThreadMetadata(
            rollouts: rollouts,
            codexHomeDirectory: codexHomeDirectory,
            environment: environment)
        let archivedSessionsDirectory = codexHomeDirectory
            .appendingPathComponent("archived_sessions", isDirectory: true)
            .standardizedFileURL
        let visibleRollouts = rollouts.filter { rollout in
            let metadata = threadMetadata[rollout.metadata.sessionID]
            switch metadata?.archiveState ?? .unknown {
            case .active:
                break
            case .archived:
                return false
            case .unknown:
                guard now.timeIntervalSince(rollout.modifiedAt) <= Self.unknownArchiveStateRetention else {
                    return false
                }
            }
            guard rollout.metadata.isGuardian,
                  let path = metadata?.rolloutPath,
                  !path.isEmpty
            else { return true }
            return !Self.isDescendant(
                URL(fileURLWithPath: path).standardizedFileURL,
                of: archivedSessionsDirectory)
        }
        return self.sessions(
            processes: processes,
            cwdByPID: cwdByPID,
            rollouts: visibleRollouts,
            context: ScanContext(
                homeDirectory: homeDirectory,
                codexHomeDirectory: codexHomeDirectory,
                host: host,
                now: now,
                codexAppServerPresent: codexAppServerPresent,
                includeFileOnlySessions: includeFileOnlySessions,
                threadMetadata: threadMetadata),
            directoryBudget: &directoryBudget)
    }

    public static func shouldScanSessionMetadata(
        hasAgentProcesses: Bool,
        includeFileOnlySessions: Bool) -> Bool
    {
        hasAgentProcesses || includeFileOnlySessions
    }

    private static func codexThreadMetadata(
        rollouts: [Rollout],
        codexHomeDirectory: URL,
        environment: [String: String])
        -> [String: CodexThreadMetadata]
    {
        let sessionIDs = Set(rollouts.map(\.metadata.sessionID))
        let indexedNames = CodexThreadMetadataReader.indexedThreadNames(
            codexHomeDirectory: codexHomeDirectory,
            sessionIDs: sessionIDs)
        var groups: [String: (reader: CodexThreadMetadataReader, sessionIDs: Set<String>)] = [:]
        for rollout in rollouts {
            let resolvedWorkingDirectory = rollout.metadata.cwd.map {
                URL(fileURLWithPath: $0, isDirectory: true).standardizedFileURL
            }
            let reader = CodexThreadMetadataReader(
                codexHomeDirectory: codexHomeDirectory,
                environment: environment,
                resolvedWorkingDirectory: resolvedWorkingDirectory)
            let key = reader.databaseURL.path
            if var group = groups[key] {
                group.sessionIDs.insert(rollout.metadata.sessionID)
                groups[key] = group
            } else {
                groups[key] = (reader, [rollout.metadata.sessionID])
            }
        }

        var metadata: [String: CodexThreadMetadata] = [:]
        for group in groups.values {
            metadata.merge(group.reader.metadata(for: group.sessionIDs, indexedNames: indexedNames)) { _, latest in
                latest
            }
        }
        return metadata
    }

    private func sessions(
        processes: [AgentProcessRecord],
        cwdByPID: [Int32: String],
        rollouts: [Rollout],
        context: ScanContext,
        directoryBudget: inout DirectoryMetadataScanBudget) -> [AgentSession]
    {
        var sessions: [AgentSession] = []
        var matchedRolloutPaths = Set<String>()
        let claudeProcesses = processes.filter { AgentPSOutputParser.provider(for: $0) == .claude }
        let claudeCWDs = Set(claudeProcesses.compactMap { cwdByPID[$0.pid] })
        var claudeTranscriptsByCWD: [String: [ClaudeSessionProjectMapper.Transcript]] = [:]
        for cwd in claudeCWDs {
            claudeTranscriptsByCWD[cwd] = ClaudeSessionProjectMapper.transcripts(
                cwd: cwd,
                homeDirectory: context.homeDirectory,
                limit: self.config.maxClaudeTranscriptCountPerProject,
                now: context.now,
                budget: &directoryBudget,
                clampModificationDate: self.futureModificationDateClamp.clamp)
        }
        let claudeTranscripts = AgentSessionCorrelation.assignClaudeTranscripts(
            processes: claudeProcesses,
            cwdByPID: cwdByPID,
            transcriptsByCWD: claudeTranscriptsByCWD)
        let codexProcesses = processes.filter { AgentPSOutputParser.provider(for: $0) == .codex }
        let codexDescriptiveNamePIDs = AgentSessionCorrelation.unambiguousProcessIDs(
            processes: codexProcesses,
            cwdByPID: cwdByPID)

        for process in processes {
            guard let provider = AgentPSOutputParser.provider(for: process) else { continue }
            let cwd = cwdByPID[process.pid]
            switch provider {
            case .claude:
                let transcript = claudeTranscripts[process.pid]
                sessions.append(AgentSession(
                    id: transcript?.url.deletingPathExtension().lastPathComponent ?? "pid:\(process.pid)",
                    provider: .claude,
                    source: AgentPSOutputParser.source(for: process),
                    state: self.config.state(
                        lastActivityAt: transcript?.modifiedAt,
                        now: context.now,
                        hasLiveProcess: true),
                    pid: process.pid,
                    cwd: cwd,
                    projectName: Self.projectName(cwd),
                    startedAt: process.startedAt,
                    lastActivityAt: transcript?.modifiedAt,
                    transcriptPath: transcript?.url.path,
                    host: context.host))
            case .codex:
                guard !self.config.requireUnambiguousCodexProcessOwnership ||
                    codexDescriptiveNamePIDs.contains(process.pid)
                else { continue }
                let rollout = rollouts.first { candidate in
                    !matchedRolloutPaths.contains(candidate.url.path) &&
                        AgentSessionCorrelation.codexWorkingDirectoriesMatch(candidate.metadata.cwd, cwd)
                }
                if let rollout {
                    matchedRolloutPaths.insert(rollout.url.path)
                }
                let rolloutSource = rollout?.metadata.sessionSource
                sessions.append(AgentSession(
                    id: rollout?.metadata.sessionID ?? "pid:\(process.pid)",
                    provider: .codex,
                    source: rolloutSource == nil || rolloutSource == .unknown ? .cli : rolloutSource ?? .cli,
                    state: self.config.state(
                        lastActivityAt: rollout?.modifiedAt,
                        now: context.now,
                        hasLiveProcess: true),
                    pid: process.pid,
                    cwd: cwd ?? rollout?.metadata.cwd,
                    projectName: Self.projectName(cwd ?? rollout?.metadata.cwd),
                    sessionName: codexDescriptiveNamePIDs.contains(process.pid)
                        ? rollout?.metadata.descriptiveName(
                            threadMetadata: rollout.flatMap { context.threadMetadata[$0.metadata.sessionID] })
                        : nil,
                    startedAt: rollout?.metadata.startedAt ?? process.startedAt,
                    lastActivityAt: rollout?.modifiedAt,
                    transcriptPath: rollout?.url.path,
                    host: context.host))
            }
        }

        for rollout in rollouts
            where context.includeFileOnlySessions && !matchedRolloutPaths.contains(rollout.url.path)
        {
            let threadMetadata = context.threadMetadata[rollout.metadata.sessionID]
            guard let effectiveRollout = self.effectiveRollout(
                rollout,
                threadMetadata: threadMetadata,
                codexHomeDirectory: context.codexHomeDirectory,
                now: context.now)
            else { continue }
            guard var session = CodexRolloutFirstLineParser.makeSession(
                metadata: effectiveRollout.metadata,
                transcriptURL: effectiveRollout.url,
                modifiedAt: effectiveRollout.modifiedAt,
                host: context.host,
                config: self.config,
                now: context.now)
            else { continue }
            session.sessionName = effectiveRollout.metadata.descriptiveName(
                threadMetadata: threadMetadata)
            session.source = AgentSessionCorrelation.fileOnlyCodexSource(
                metadataSource: session.source,
                appServerPresent: context.codexAppServerPresent)
            sessions.append(session)
        }

        var seen = Set<String>()
        return sessions
            .sorted { lhs, rhs in
                if lhs.state != rhs.state {
                    return lhs.state == .active
                }
                return (lhs.lastActivityAt ?? lhs.startedAt ?? .distantPast) >
                    (rhs.lastActivityAt ?? rhs.startedAt ?? .distantPast)
            }
            .filter { seen.insert("\($0.host):\($0.id)").inserted }
    }

    private func effectiveRollout(
        _ rollout: Rollout,
        threadMetadata: CodexThreadMetadata?,
        codexHomeDirectory: URL,
        now: Date) -> Rollout?
    {
        guard rollout.metadata.isGuardian else { return rollout }
        guard self.config.includeCodexGuardianParents,
              let threadMetadata,
              threadMetadata.archiveState != .archived,
              let path = threadMetadata.rolloutPath,
              !path.isEmpty
        else { return nil }

        let url = URL(fileURLWithPath: path).standardizedFileURL
        let archivedSessionsDirectory = codexHomeDirectory
            .appendingPathComponent("archived_sessions", isDirectory: true)
            .standardizedFileURL
        guard !Self.isDescendant(url, of: archivedSessionsDirectory) else { return nil }
        guard let metadata = CodexRolloutFirstLineParser.read(from: url),
              !metadata.isSubagent,
              let modifiedAt = try? url.resourceValues(
                  forKeys: [.contentModificationDateKey]).contentModificationDate
        else { return nil }
        return Rollout(
            url: url,
            modifiedAt: self.futureModificationDateClamp.clamp(
                url: url,
                modifiedAt: modifiedAt,
                now: now),
            metadata: metadata)
    }

    private static func isDescendant(_ url: URL, of directory: URL) -> Bool {
        let directoryPath = directory.path.hasSuffix("/") ? directory.path : directory.path + "/"
        return url.path == directory.path || url.path.hasPrefix(directoryPath)
    }

    private func processOutput(environment: [String: String]) async -> String {
        let binary = ["/bin/ps", "/usr/bin/ps"].first { FileManager.default.isExecutableFile(atPath: $0) }
        guard let binary,
              let result = try? await SubprocessRunner.run(
                  binary: binary,
                  arguments: ["-axo", "pid=,ppid=,lstart=,command="],
                  environment: environment,
                  timeout: 5,
                  label: "agent session process scan")
        else { return "" }
        return result.stdout
    }

    private func cwdByPID(_ pids: [Int32], environment: [String: String]) async -> [Int32: String] {
        guard !pids.isEmpty else { return [:] }
        if let lsof = self.findExecutable("lsof", environment: environment) {
            let joinedPIDs = pids.map(String.init).joined(separator: ",")
            if let result = try? await SubprocessRunner.run(
                binary: lsof,
                arguments: ["-a", "-d", "cwd", "-Fn", "-p", joinedPIDs],
                environment: environment,
                timeout: 5,
                acceptsNonZeroExit: true,
                label: "agent session cwd scan")
            {
                return LSOFCWDOutputParser.parse(result.stdout)
            }
        }

        #if os(Linux)
        return Dictionary(uniqueKeysWithValues: pids.compactMap { pid in
            let path = "/proc/\(pid)/cwd"
            guard let destination = try? FileManager.default.destinationOfSymbolicLink(atPath: path) else { return nil }
            return (pid, destination)
        })
        #else
        return [:]
        #endif
    }

    private func codexRollouts(
        now: Date,
        codexHomeDirectory: URL,
        matchingCWDs: [String]?,
        directoryBudget: inout DirectoryMetadataScanBudget) -> [Rollout]
    {
        let root = codexHomeDirectory.appendingPathComponent("sessions", isDirectory: true)
        let calendar = Calendar(identifier: .gregorian)
        let days = [now, calendar.date(byAdding: .day, value: -1, to: now)].compactMap(\.self)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy/MM/dd"
        let fileManager = FileManager.default

        let candidates = days.flatMap { day -> [(url: URL, modifiedAt: Date)] in
            let directory = root.appendingPathComponent(formatter.string(from: day), isDirectory: true)
            return directoryBudget.files(in: directory, fileManager: fileManager).compactMap { file in
                guard file.lastPathComponent.hasPrefix("rollout-"), file.pathExtension == "jsonl",
                      let modifiedAt = try? file.resourceValues(
                          forKeys: [.contentModificationDateKey]).contentModificationDate
                else { return nil }
                return (file, self.futureModificationDateClamp.clamp(
                    url: file,
                    modifiedAt: modifiedAt,
                    now: now))
            }
        }.sorted { $0.modifiedAt > $1.modifiedAt }

        var remainingCWDs = matchingCWDs ?? []
        var rollouts: [Rollout] = []
        for candidate in candidates.prefix(max(0, self.config.maxCodexRolloutCount)) {
            guard directoryBudget.hasTimeRemaining() else { break }
            guard let metadata = CodexRolloutFirstLineParser.read(from: candidate.url) else { continue }
            guard self.config.includeCodexSubagents ||
                !metadata.isSubagent ||
                (self.config.includeCodexGuardianParents && metadata.isGuardian)
            else { continue }
            rollouts.append(Rollout(url: candidate.url, modifiedAt: candidate.modifiedAt, metadata: metadata))
            if let index = remainingCWDs.firstIndex(where: {
                AgentSessionCorrelation.codexWorkingDirectoriesMatch(metadata.cwd, $0)
            }) {
                remainingCWDs.remove(at: index)
                if matchingCWDs != nil, remainingCWDs.isEmpty {
                    break
                }
            }
        }
        return rollouts
    }

    private func findExecutable(_ name: String, environment: [String: String]) -> String? {
        let path = environment["PATH"] ?? "/usr/local/bin:/usr/bin:/bin:/opt/homebrew/bin"
        return path.split(separator: ":")
            .map { String($0) + "/" + name }
            .first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    private static func standardized(_ path: String?) -> String? {
        path.map { URL(fileURLWithPath: $0).standardizedFileURL.path }
    }

    private static func projectName(_ cwd: String?) -> String? {
        guard let cwd, !cwd.isEmpty else { return nil }
        return URL(fileURLWithPath: cwd).lastPathComponent
    }
}
