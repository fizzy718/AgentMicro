import CodexBarCore
import Foundation
import Testing
@testable import AgentMicro

struct AgentMicroRefreshPolicyTests {
    @Test
    func `agentMicro scanner excludes subagent rollouts`() {
        #expect(!AgentMicroSessionPolicy.scannerConfiguration.includeCodexSubagents)
        #expect(AgentMicroSessionPolicy.scannerConfiguration.includeCodexGuardianParents)
        #expect(AgentMicroSessionPolicy.scannerConfiguration.fileOnlyWindow == 24 * 60 * 60)
        #expect(AgentMicroSessionPolicy.scannerConfiguration.requireUnambiguousCodexProcessOwnership)
        #expect(AgentMicroSessionPolicy.scannerConfiguration.providerScope == .codexOnly)
    }

    @Test
    func `desktop app uses file events with a bounded safety poll`() {
        #expect(AgentMicroRefreshPolicy.interval(
            tasks: [],
            isDesktopAppRunning: true) == .seconds(15))
    }

    @Test
    func `working and process-backed tasks use active polling`() {
        let working = CodexTaskStateTestSupport.observation(state: .thinking, pid: nil)
        let processBacked = CodexTaskStateTestSupport.observation(state: .idle, pid: 42)

        #expect(AgentMicroRefreshPolicy.interval(
            tasks: [working],
            isDesktopAppRunning: false) == .seconds(15))
        #expect(AgentMicroRefreshPolicy.interval(
            tasks: [processBacked],
            isDesktopAppRunning: false) == .seconds(15))
    }

    @Test
    func `idle file-only tasks use the low-power interval`() {
        let done = CodexTaskStateTestSupport.observation(state: .unread, pid: nil)

        #expect(AgentMicroRefreshPolicy.interval(
            tasks: [done],
            isDesktopAppRunning: false) == .seconds(30))
    }

    @Test
    func `overlapping safety polls are dropped while events request one follow up`() {
        #expect(!AgentMicroRefreshPolicy.shouldQueueFollowUp(
            whileRefreshIsRunning: true,
            trigger: .polling))
        #expect(AgentMicroRefreshPolicy.shouldQueueFollowUp(
            whileRefreshIsRunning: true,
            trigger: .event))
        #expect(!AgentMicroRefreshPolicy.shouldQueueFollowUp(
            whileRefreshIsRunning: false,
            trigger: .event))
        #expect(AgentMicroRefreshPolicy.discoveryEventDelay == .seconds(2))
    }

    @Test
    func `menu reconciliation retries quickly while completion events settle`() {
        #expect(AgentMicroRefreshPolicy.reconciliationDelays == [
            .milliseconds(150),
            .milliseconds(350),
            .milliseconds(800),
        ])
    }

    @Test
    func `viewing an active turn marks its immediately following completion read`() {
        let startedAt = Date(timeIntervalSince1970: 10000)
        let viewedAt = startedAt.addingTimeInterval(5)
        let active = CodexTaskStateTestSupport.observation(
            state: .thinking,
            activity: viewedAt,
            runStartedAt: startedAt,
            id: "viewed-turn")
        let completed = CodexTaskStateTestSupport.observation(
            state: .unread,
            activity: viewedAt.addingTimeInterval(1),
            runStartedAt: startedAt,
            id: "viewed-turn")
        var tracker = AgentMicroViewedTurnTracker()

        tracker.noteViewing(active, now: viewedAt)

        #expect(tracker.completedTasksToMarkRead(
            in: [completed],
            now: viewedAt.addingTimeInterval(1)) == [completed])
        #expect(tracker.completedTasksToMarkRead(
            in: [completed],
            now: viewedAt.addingTimeInterval(1)).isEmpty)
    }

    @Test
    func `view marker never hides a later turn or a completion outside its grace window`() {
        let startedAt = Date(timeIntervalSince1970: 10000)
        let viewedAt = startedAt.addingTimeInterval(5)
        let active = CodexTaskStateTestSupport.observation(
            state: .thinking,
            activity: viewedAt,
            runStartedAt: startedAt,
            id: "viewed-turn")
        let laterTurn = CodexTaskStateTestSupport.observation(
            state: .unread,
            activity: viewedAt.addingTimeInterval(1),
            runStartedAt: startedAt.addingTimeInterval(0.5),
            id: "viewed-turn")
        let lateCompletion = CodexTaskStateTestSupport.observation(
            state: .unread,
            activity: viewedAt.addingTimeInterval(6),
            runStartedAt: startedAt,
            id: "viewed-turn")
        var laterTurnTracker = AgentMicroViewedTurnTracker()
        var expiredTracker = AgentMicroViewedTurnTracker()

        laterTurnTracker.noteViewing(active, now: viewedAt)
        expiredTracker.noteViewing(active, now: viewedAt)

        #expect(laterTurnTracker.completedTasksToMarkRead(
            in: [laterTurn],
            now: viewedAt.addingTimeInterval(1)).isEmpty)
        #expect(expiredTracker.completedTasksToMarkRead(
            in: [lateCompletion],
            now: viewedAt.addingTimeInterval(6)).isEmpty)
    }

    @Test
    func `session monitor watches the active rollout and current date directories`() throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory
            .appendingPathComponent("AgentMicroWatchTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? fileManager.removeItem(at: root) }

        let now = Date(timeIntervalSince1970: 1_785_240_010)
        let dayDirectory = root
            .appendingPathComponent("sessions/2026/07/28", isDirectory: true)
        try fileManager.createDirectory(at: dayDirectory, withIntermediateDirectories: true)
        let rollout = dayDirectory.appendingPathComponent("rollout-current.jsonl")
        try Data().write(to: rollout)
        let globalState = root.appendingPathComponent(".codex-global-state.json")
        try Data("{}".utf8).write(to: globalState)
        let database = root.appendingPathComponent("state_5.sqlite")
        try Data().write(to: database)
        let databaseWAL = URL(fileURLWithPath: database.path + "-wal")
        try Data().write(to: databaseWAL)

        let environment = [
            "CODEX_HOME": root.path,
            "HOME": root.deletingLastPathComponent().path,
        ]
        let paths = CodexSessionWatchPaths.existingPaths(
            transcriptPaths: [rollout.path],
            now: now,
            environment: environment,
            fileManager: fileManager)

        #expect(paths.contains(root.appendingPathComponent("sessions").path))
        #expect(paths.contains(dayDirectory.path))
        #expect(paths.contains(rollout.path))
        #expect(paths.contains(globalState.path))
        let selectedDatabase = CodexThreadMetadataReader(
            codexHomeDirectory: root,
            environment: ["CODEX_HOME": root.path]).databaseURL.path
        #expect(paths.contains(selectedDatabase))
        #expect(paths.contains(selectedDatabase + "-wal"))
        #expect(!CodexSessionWatchPaths.requiresDiscovery(
            for: rollout.path,
            transcriptPaths: [rollout.path],
            environment: environment))
        #expect(!CodexSessionWatchPaths.requiresDiscovery(
            for: globalState.path,
            transcriptPaths: [rollout.path],
            environment: environment))
        #expect(CodexSessionWatchPaths.requiresDiscovery(
            for: selectedDatabase + "-wal",
            transcriptPaths: [rollout.path],
            environment: environment))
        #expect(CodexSessionWatchPaths.requiresDiscovery(
            for: dayDirectory.path,
            transcriptPaths: [rollout.path],
            environment: environment))
    }
}
