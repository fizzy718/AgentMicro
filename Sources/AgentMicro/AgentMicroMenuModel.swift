import CodexBarCore
import Foundation

struct AgentMicroMenuRow: Equatable, Sendable {
    let sessionKey: String
    let title: String
    let subtitle: String
    let state: CodexTaskState

    var isActive: Bool {
        self.state.isWorking
    }

    var symbol: String {
        self.state.symbol
    }
}

enum AgentMicroMenuModel {
    static func rows(from tasks: [CodexTaskObservation], now: Date = Date()) -> [AgentMicroMenuRow] {
        tasks
            .filter { $0.session.provider == .codex }
            .sorted(by: self.taskComesBefore)
            .map { task in
                let session = task.session
                let title = self.title(for: session)
                var subtitleParts = [
                    task.state.displayName
                ]
                if let currentAction = self.nonEmpty(task.currentAction) {
                    subtitleParts.append(currentAction)
                }
                subtitleParts.append(
                    self.sourceLabel(session.source)
                )
                if let projectName = session.projectName, projectName != title {
                    subtitleParts.append(projectName)
                }
                let age = self.ageLabel(for: session, now: now)
                subtitleParts.append(task.state == .done ? "\(age) ago" : age)
                return AgentMicroMenuRow(
                    sessionKey: task.sessionKey,
                    title: title,
                    subtitle: subtitleParts.joined(separator: " · "),
                    state: task.state,
                )
            }
    }

    static func sessionKey(for session: AgentSession) -> String {
        "\(session.host):\(session.id)"
    }

    static func title(for session: AgentSession) -> String {
        if let projectName = self.nonEmpty(session.projectName) {
            return projectName
        }
        if let sessionName = self.nonEmpty(session.sessionName) {
            return sessionName
        }
        let compactID = session.id.split(separator: "-").first.map(String.init) ?? session.id
        return compactID.isEmpty ? "Codex task" : compactID
    }

    static func ageLabel(for session: AgentSession, now: Date) -> String {
        guard let activity = session.lastActivityAt ?? session.startedAt else { return "now" }
        let seconds = max(0, Int(now.timeIntervalSince(activity)))
        if seconds < 60 {
            return "\(seconds)s"
        }
        if seconds < 3600 {
            return "\(seconds / 60)m"
        }
        return "\(seconds / 3600)h"
    }

    private static func taskComesBefore(_ lhs: CodexTaskObservation, _ rhs: CodexTaskObservation) -> Bool {
        if lhs.state.sortPriority != rhs.state.sortPriority {
            return lhs.state.sortPriority < rhs.state.sortPriority
        }
        let lhsActivity = lhs.lastEventAt ?? lhs.session.lastActivityAt ?? lhs.session.startedAt ?? .distantPast
        let rhsActivity = rhs.lastEventAt ?? rhs.session.lastActivityAt ?? rhs.session.startedAt ?? .distantPast
        if lhsActivity != rhsActivity {
            return lhsActivity > rhsActivity
        }
        return lhs.sessionKey < rhs.sessionKey
    }

    private static func sourceLabel(_ source: AgentSession.Source) -> String {
        switch source {
        case .desktopApp:
            "Codex App"
        case .cli:
            "Codex CLI"
        case .ide:
            "IDE"
        case .unknown:
            "Codex"
        }
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }
        return value
    }
}
