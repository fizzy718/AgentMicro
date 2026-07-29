import CodexBarCore
import Foundation

enum CodexTaskState: String, Equatable, Sendable {
    case thinking
    case executing
    case waiting
    case rateLimited
    case unknown
    case done

    var displayName: String {
        switch self {
        case .thinking:
            "Thinking"
        case .executing:
            "Executing"
        case .waiting:
            "Waiting"
        case .rateLimited:
            "Rate limited"
        case .unknown:
            "Unknown"
        case .done:
            "Done"
        }
    }

    var symbol: String {
        switch self {
        case .thinking:
            "●"
        case .executing:
            "◉"
        case .waiting:
            "○"
        case .rateLimited:
            "!"
        case .unknown:
            "?"
        case .done:
            "◌"
        }
    }

    var isWorking: Bool {
        self == .thinking || self == .executing
    }

    var sortPriority: Int {
        switch self {
        case .thinking, .executing:
            0
        case .rateLimited:
            1
        case .waiting:
            2
        case .unknown:
            3
        case .done:
            4
        }
    }
}

struct CodexTaskObservation: Equatable, Sendable {
    let session: AgentSession
    let state: CodexTaskState
    let currentAction: String?
    let lastEventAt: Date?

    var sessionKey: String {
        "\(self.session.host):\(self.session.id)"
    }
}

struct CodexRolloutSnapshot: Equatable, Sendable {
    let hasParsedEvents: Bool
    let isThinking: Bool
    let isRateLimited: Bool
    let hasPendingToolCall: Bool
    let currentAction: String?
    let lastEventAt: Date?
}

enum CodexTaskStateResolver {
    static let defaultUnknownWindow: TimeInterval = 30
    static let defaultCompletedRetention: TimeInterval = 5 * 60
    static let defaultThinkingFreshness: TimeInterval = 2 * 60

    static func observation(
        session: AgentSession,
        snapshot: CodexRolloutSnapshot?,
        now: Date,
        unknownWindow: TimeInterval = CodexTaskStateResolver.defaultUnknownWindow,
        completedRetention: TimeInterval = CodexTaskStateResolver.defaultCompletedRetention,
        thinkingFreshness: TimeInterval = CodexTaskStateResolver.defaultThinkingFreshness
    ) -> CodexTaskObservation? {
        let activity = snapshot?.lastEventAt ?? session.lastActivityAt ?? session.startedAt
        let activityAge = activity.map { max(0, now.timeIntervalSince($0)) }

        guard session.pid != nil else {
            guard activityAge.map({ $0 <= completedRetention }) ?? false else { return nil }
            let state: CodexTaskState = activityAge.map { $0 <= unknownWindow } == true ? .unknown : .done
            return CodexTaskObservation(
                session: session,
                state: state,
                currentAction: state == .unknown ? snapshot?.currentAction : nil,
                lastEventAt: activity
            )
        }

        guard let snapshot, snapshot.hasParsedEvents else {
            return CodexTaskObservation(
                session: session,
                state: .unknown,
                currentAction: nil,
                lastEventAt: activity
            )
        }

        let state: CodexTaskState = if snapshot.hasPendingToolCall {
            .executing
        } else if snapshot.isThinking, activityAge.map({ $0 <= thinkingFreshness }) ?? false {
            .thinking
        } else if snapshot.isRateLimited {
            .rateLimited
        } else {
            .waiting
        }

        return CodexTaskObservation(
            session: session,
            state: state,
            currentAction: state == .executing ? snapshot.currentAction : nil,
            lastEventAt: activity
        )
    }
}
