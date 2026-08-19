import CodexBarCore
import Foundation

struct AgentMicroMenuRow: Equatable, Sendable {
    let slotIndex: Int
    let sessionKey: String
    let title: String
    let subtitle: String
    let duration: String
    let cpuLabel: String?
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
        searchQuery: String? = nil,
        contentMatchingSessionKeys: Set<String> = [],
        cpuPercentBySessionKey: [String: Double] = [:],
        now: Date = Date()) -> [AgentMicroMenuRow]
    {
        let normalizedSearchQuery = self.nonEmpty(searchQuery)
        return tasks
            .filter { task in
                task.session.provider == .codex &&
                    (preferences.showRecentlyCompleted || task.state != .unread) &&
                    self.searchMatches(
                        task,
                        query: normalizedSearchQuery,
                        contentMatchingSessionKeys: contentMatchingSessionKeys)
            }
            .sorted { lhs, rhs in
                self.searchResultHasHigherPriority(
                    lhs,
                    than: rhs,
                    query: normalizedSearchQuery,
                    contentMatchingSessionKeys: contentMatchingSessionKeys)
            }
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
                    cpuLabel: self.cpuLabel(
                        for: task,
                        showTaskCPU: preferences.showTaskCPU,
                        cpuPercent: cpuPercentBySessionKey[task.sessionKey]),
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

    static func cpuLabel(
        for task: CodexTaskObservation,
        showTaskCPU: Bool,
        cpuPercent: Double?) -> String?
    {
        guard showTaskCPU else { return nil }
        switch task.session.source {
        case .cli:
            guard task.session.pid != nil else { return nil }
            guard let cpuPercent else { return "CPU …" }
            return String(format: "CPU %.0f%%", max(0, cpuPercent))
        case .desktopApp:
            return AgentMicroLocalization.text("task.cpu.shared")
        case .ide, .unknown:
            return nil
        }
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

    private static func searchResultHasHigherPriority(
        _ lhs: CodexTaskObservation,
        than rhs: CodexTaskObservation,
        query: String?,
        contentMatchingSessionKeys: Set<String>) -> Bool
    {
        guard let query else { return self.taskHasHigherMenuPriority(lhs, rhs) }
        let lhsRank = self.searchRank(
            for: lhs,
            query: query,
            contentMatchingSessionKeys: contentMatchingSessionKeys)
        let rhsRank = self.searchRank(
            for: rhs,
            query: query,
            contentMatchingSessionKeys: contentMatchingSessionKeys)
        if lhsRank != rhsRank {
            return lhsRank < rhsRank
        }
        return self.taskHasHigherMenuPriority(lhs, rhs)
    }

    private static func searchRank(
        for task: CodexTaskObservation,
        query: String,
        contentMatchingSessionKeys: Set<String>) -> Int
    {
        let options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]
        let title = self.nonEmpty(task.session.sessionName)
        let project = self.nonEmpty(task.session.projectName)
        if title?.compare(query, options: options) == .orderedSame { return 0 }
        if project?.compare(query, options: options) == .orderedSame { return 1 }
        if title?.range(of: query, options: options.union(.anchored)) != nil { return 2 }
        if project?.range(of: query, options: options.union(.anchored)) != nil { return 3 }
        if title?.range(of: query, options: options) != nil { return 4 }
        if project?.range(of: query, options: options) != nil { return 5 }
        return contentMatchingSessionKeys.contains(task.sessionKey) ? 6 : 7
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }
        return value
    }

    private static func searchMatches(
        _ task: CodexTaskObservation,
        query: String?,
        contentMatchingSessionKeys: Set<String>) -> Bool
    {
        guard let query else { return true }
        if contentMatchingSessionKeys.contains(task.sessionKey) {
            return true
        }
        return [task.session.projectName, task.session.sessionName]
            .compactMap(self.nonEmpty)
            .contains {
                $0.range(
                    of: query,
                    options: [.caseInsensitive, .diacriticInsensitive]) != nil
            }
    }
}
