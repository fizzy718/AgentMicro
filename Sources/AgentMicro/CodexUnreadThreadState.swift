import CodexBarCore
import Foundation

struct CodexUnreadThreadSnapshot: Equatable, Sendable {
    let unreadThreadIDs: Set<String>
    let modifiedAt: Date
}

final class CodexUnreadThreadStateReader {
    private struct Fingerprint: Equatable {
        let modifiedAt: Date
        let fileSize: UInt64
        let fileNumber: UInt64?
    }

    private struct PersistedState: Decodable {
        let unreadThreadIDsByHost: [String: [String]]?

        enum CodingKeys: String, CodingKey {
            case unreadThreadIDsByHost = "unread-thread-ids-by-host-v1"
        }
    }

    private struct GlobalState: Decodable {
        let persistedState: PersistedState?

        enum CodingKeys: String, CodingKey {
            case persistedState = "electron-persisted-atom-state"
        }
    }

    private let fileURL: URL
    private let fileManager: FileManager
    private var cachedFingerprint: Fingerprint?
    private var cachedSnapshot: CodexUnreadThreadSnapshot?

    init(
        fileURL: URL? = nil,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        fileManager: FileManager = .default)
    {
        self.fileManager = fileManager
        self.fileURL = fileURL ?? CodexSessionWatchPaths.globalStateFileURL(
            environment: environment)
    }

    func snapshot() -> CodexUnreadThreadSnapshot? {
        guard let attributes = try? self.fileManager.attributesOfItem(atPath: self.fileURL.path),
              let modifiedAt = attributes[.modificationDate] as? Date,
              let fileSize = (attributes[.size] as? NSNumber)?.uint64Value
        else {
            self.cachedFingerprint = nil
            self.cachedSnapshot = nil
            return nil
        }

        let fingerprint = Fingerprint(
            modifiedAt: modifiedAt,
            fileSize: fileSize,
            fileNumber: (attributes[.systemFileNumber] as? NSNumber)?.uint64Value)
        if fingerprint == self.cachedFingerprint {
            return self.cachedSnapshot
        }

        guard let data = try? Data(contentsOf: self.fileURL),
              let state = try? JSONDecoder().decode(GlobalState.self, from: data),
              let unreadThreadIDsByHost = state.persistedState?.unreadThreadIDsByHost
        else {
            return nil
        }

        let snapshot = CodexUnreadThreadSnapshot(
            unreadThreadIDs: Set(unreadThreadIDsByHost.values.joined()),
            modifiedAt: modifiedAt)
        self.cachedFingerprint = fingerprint
        self.cachedSnapshot = snapshot
        return snapshot
    }
}

enum AgentMicroReadStateResolver {
    static let codexStatePropagationGraceInterval: TimeInterval = 5

    static func readSessionKeys(
        for tasks: [CodexTaskObservation],
        locallyReadSessionKeys: Set<String>,
        codexUnreadSnapshot: CodexUnreadThreadSnapshot?,
        now: Date = Date()) -> Set<String>
    {
        guard let codexUnreadSnapshot else { return locallyReadSessionKeys }
        var readSessionKeys = locallyReadSessionKeys

        for task in tasks where task.session.source == .desktopApp && task.state == .unread {
            if codexUnreadSnapshot.unreadThreadIDs.contains(task.session.id) {
                readSessionKeys.remove(task.sessionKey)
                continue
            }

            let activity = task.lastEventAt ??
                task.session.lastActivityAt ??
                task.session.startedAt
            let snapshotIncludesActivity = activity.map {
                codexUnreadSnapshot.modifiedAt >= $0
            } ?? true
            let propagationGraceElapsed = activity.map {
                now.timeIntervalSince($0) >= Self.codexStatePropagationGraceInterval
            } ?? true
            if snapshotIncludesActivity || propagationGraceElapsed {
                readSessionKeys.insert(task.sessionKey)
            }
        }

        return readSessionKeys
    }
}
