import CodexBarCore
import Foundation

struct AgentMicroMenuRow: Equatable, Sendable {
    let slotIndex: Int
    let sessionKey: String
    let title: String
    let subtitle: String
    let duration: String
    let state: CodexTaskState
    let usesFastModel: Bool

    var isActive: Bool {
        self.state.isWorking
    }
}

enum AgentMicroMenuModel {
    static let durationUpdateInterval: TimeInterval = 1

    static func rows(
        from tasks: [CodexTaskObservation],
        preferences: AgentMicroPreferences = AgentMicroPreferences(),
        readSessionKeys: Set<String> = [],
        now: Date = Date()) -> [AgentMicroMenuRow]
    {
        tasks
            .filter { task in
                task.session.provider == .codex &&
                    (preferences.showRecentlyCompleted || task.state != .unread)
            }
            .sorted(by: self.taskHasHigherMenuPriority)
            .prefix(preferences.taskDisplayLimit)
            .enumerated()
            .map { slotIndex, task in
                let session = task.session
                let state: CodexTaskState = if task.state == .unread,
                                               readSessionKeys.contains(task.sessionKey)
                {
                    .idle
                } else {
                    task.state
                }
                let title = self.title(for: session, mode: preferences.taskNameMode)
                let subtitle: String = if preferences.taskNameMode == .taskTitleAndProject,
                                          let projectName = self.nonEmpty(session.projectName),
                                          projectName != title
                {
                    projectName
                } else {
                    ""
                }
                return AgentMicroMenuRow(
                    slotIndex: slotIndex,
                    sessionKey: task.sessionKey,
                    title: title,
                    subtitle: subtitle,
                    duration: self.durationLabel(for: task, now: now),
                    state: state,
                    usesFastModel: task.usesFastModel)
            }
    }

    static func sessionKey(for session: AgentSession) -> String {
        "\(session.host):\(session.id)"
    }

    static func title(for session: AgentSession) -> String {
        self.title(for: session, mode: .projectOnly)
    }

    static func title(for session: AgentSession, mode: AgentMicroTaskNameMode) -> String {
        switch mode {
        case .projectOnly:
            if let projectName = nonEmpty(session.projectName) {
                return projectName
            }
        case .taskTitle, .taskTitleAndProject:
            if let sessionName = nonEmpty(session.sessionName) {
                return sessionName
            }
            if let projectName = nonEmpty(session.projectName) {
                return projectName
            }
        }
        let compactID = session.id.split(separator: "-").first.map(String.init) ?? session.id
        return compactID.isEmpty ? AgentMicroLocalization.text("task.fallbackTitle") : compactID
    }

    static func durationLabel(for task: CodexTaskObservation, now: Date) -> String {
        let startedAt = task.runStartedAt ??
            task.stateChangedAt ??
            task.session.startedAt ??
            task.session.lastActivityAt ??
            task.lastEventAt ??
            now
        let endedAt = task.state.isWorking
            ? now
            : task.lastEventAt ?? task.session.lastActivityAt ?? startedAt
        let totalSeconds = max(0, Int(endedAt.timeIntervalSince(startedAt)))
        let hours = totalSeconds / 3600
        let minutes = totalSeconds % 3600 / 60
        let seconds = totalSeconds % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m \(seconds)s"
        }
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        }
        return "\(seconds)s"
    }

    private static func taskHasHigherMenuPriority(
        _ lhs: CodexTaskObservation,
        _ rhs: CodexTaskObservation) -> Bool
    {
        if lhs.state.isWorking != rhs.state.isWorking {
            return lhs.state.isWorking
        }
        let lhsChange = lhs.stateChangedAt ??
            lhs.lastEventAt ??
            lhs.session.lastActivityAt ??
            lhs.session.startedAt ??
            .distantPast
        let rhsChange = rhs.stateChangedAt ??
            rhs.lastEventAt ??
            rhs.session.lastActivityAt ??
            rhs.session.startedAt ??
            .distantPast
        if lhsChange != rhsChange {
            return lhsChange > rhsChange
        }
        return lhs.sessionKey < rhs.sessionKey
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }
        return value
    }
}
