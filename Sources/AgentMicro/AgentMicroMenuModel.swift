import CodexBarCore
import Foundation

struct AgentMicroMenuRow: Equatable, Sendable {
    let sessionKey: String
    let title: String
    let subtitle: String
    let isActive: Bool
}

enum AgentMicroMenuModel {
    static func rows(from sessions: [AgentSession], now: Date = Date()) -> [AgentMicroMenuRow] {
        sessions
            .filter { $0.provider == .codex }
            .sorted(by: self.sessionComesBefore)
            .map { session in
                let title = self.title(for: session)
                var subtitleParts = [
                    session.state == .active ? "Active" : "Idle",
                    self.sourceLabel(session.source)
                ]
                if let projectName = session.projectName, projectName != title {
                    subtitleParts.append(projectName)
                }
                subtitleParts.append(self.ageLabel(for: session, now: now))
                return AgentMicroMenuRow(
                    sessionKey: self.sessionKey(for: session),
                    title: title,
                    subtitle: subtitleParts.joined(separator: " · "),
                    isActive: session.state == .active,
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

    private static func sessionComesBefore(_ lhs: AgentSession, _ rhs: AgentSession) -> Bool {
        if lhs.state != rhs.state {
            return lhs.state == .active
        }
        return (lhs.lastActivityAt ?? lhs.startedAt ?? .distantPast) >
            (rhs.lastActivityAt ?? rhs.startedAt ?? .distantPast)
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
