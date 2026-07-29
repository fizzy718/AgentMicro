import Foundation

struct AgentMicroViewedTurnTracker {
    private struct ViewedTurn {
        let startedAt: Date
        let expiresAt: Date
    }

    static let completionGraceInterval: TimeInterval = 5

    private var viewedTurns: [String: ViewedTurn] = [:]

    mutating func noteViewing(_ task: CodexTaskObservation, now: Date = Date()) {
        guard task.state != .unread, let startedAt = task.runStartedAt else { return }
        self.viewedTurns[task.sessionKey] = ViewedTurn(
            startedAt: startedAt,
            expiresAt: now.addingTimeInterval(Self.completionGraceInterval))
    }

    mutating func completedTasksToMarkRead(
        in tasks: [CodexTaskObservation],
        now: Date = Date()) -> [CodexTaskObservation]
    {
        self.viewedTurns = self.viewedTurns.filter { $0.value.expiresAt >= now }
        var completedTasks: [CodexTaskObservation] = []

        for task in tasks {
            guard let viewedTurn = self.viewedTurns[task.sessionKey] else { continue }
            guard task.runStartedAt == viewedTurn.startedAt else {
                self.viewedTurns.removeValue(forKey: task.sessionKey)
                continue
            }
            guard task.state == .unread else { continue }
            completedTasks.append(task)
            self.viewedTurns.removeValue(forKey: task.sessionKey)
        }
        return completedTasks
    }
}
