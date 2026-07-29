import Foundation
import Testing
@testable import AgentMicro

struct CodexUnreadThreadStateTests {
    @Test
    func `reader loads and combines Codex unread thread ids from every host`() throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("CodexGlobalState-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: fileURL) }
        try Data(
            """
            {
              "electron-persisted-atom-state": {
                "unread-thread-ids-by-host-v1": {
                  "local": ["thread-local"],
                  "remote": ["thread-remote"]
                }
              }
            }
            """.utf8)
            .write(to: fileURL)

        let snapshot = try #require(CodexUnreadThreadStateReader(fileURL: fileURL).snapshot())

        #expect(snapshot.unreadThreadIDs == ["thread-local", "thread-remote"])
    }

    @Test
    func `reader fails closed when Codex unread state is unavailable`() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("CodexGlobalState-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let missingKeyURL = directory.appendingPathComponent("missing-key.json")
        let malformedURL = directory.appendingPathComponent("malformed.json")
        try Data(#"{"electron-persisted-atom-state":{}}"#.utf8).write(to: missingKeyURL)
        try Data("not-json".utf8).write(to: malformedURL)

        #expect(CodexUnreadThreadStateReader(fileURL: missingKeyURL).snapshot() == nil)
        #expect(CodexUnreadThreadStateReader(fileURL: malformedURL).snapshot() == nil)
    }

    @Test
    func `desktop task follows Codex authoritative unread state`() {
        let activity = Date(timeIntervalSince1970: 100)
        let unread = CodexTaskStateTestSupport.observation(
            state: .unread,
            activity: activity,
            id: "still-unread",
            source: .desktopApp)
        let viewed = CodexTaskStateTestSupport.observation(
            state: .unread,
            activity: activity,
            id: "already-viewed",
            source: .desktopApp)
        let snapshot = CodexUnreadThreadSnapshot(
            unreadThreadIDs: ["still-unread"],
            modifiedAt: activity.addingTimeInterval(1))

        let result = AgentMicroReadStateResolver.readSessionKeys(
            for: [unread, viewed],
            locallyReadSessionKeys: [unread.sessionKey],
            codexUnreadSnapshot: snapshot,
            now: activity.addingTimeInterval(1))

        #expect(!result.contains(unread.sessionKey))
        #expect(result.contains(viewed.sessionKey))
    }

    @Test
    func `stale Codex snapshot waits for completion propagation`() {
        let activity = Date(timeIntervalSince1970: 100)
        let task = CodexTaskStateTestSupport.observation(
            state: .unread,
            activity: activity,
            id: "recent-completion",
            source: .desktopApp)
        let snapshot = CodexUnreadThreadSnapshot(
            unreadThreadIDs: [],
            modifiedAt: activity.addingTimeInterval(-1))

        let immediate = AgentMicroReadStateResolver.readSessionKeys(
            for: [task],
            locallyReadSessionKeys: [],
            codexUnreadSnapshot: snapshot,
            now: activity.addingTimeInterval(1))
        let settled = AgentMicroReadStateResolver.readSessionKeys(
            for: [task],
            locallyReadSessionKeys: [],
            codexUnreadSnapshot: snapshot,
            now: activity.addingTimeInterval(
                AgentMicroReadStateResolver.codexStatePropagationGraceInterval))

        #expect(immediate.isEmpty)
        #expect(settled == [task.sessionKey])
    }

    @Test
    func `CLI task keeps AgentMicro local read state`() {
        let activity = Date(timeIntervalSince1970: 100)
        let task = CodexTaskStateTestSupport.observation(
            state: .unread,
            activity: activity,
            id: "cli-thread",
            source: .cli)
        let snapshot = CodexUnreadThreadSnapshot(
            unreadThreadIDs: [],
            modifiedAt: activity.addingTimeInterval(1))

        #expect(AgentMicroReadStateResolver.readSessionKeys(
            for: [task],
            locallyReadSessionKeys: [],
            codexUnreadSnapshot: snapshot,
            now: activity.addingTimeInterval(1)).isEmpty)
        #expect(AgentMicroReadStateResolver.readSessionKeys(
            for: [task],
            locallyReadSessionKeys: [task.sessionKey],
            codexUnreadSnapshot: snapshot,
            now: activity.addingTimeInterval(1)) == [task.sessionKey])
    }
}
