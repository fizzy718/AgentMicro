import CodexBarCore
import Foundation

enum CodexTaskState: String, Equatable, Sendable {
    case idle
    case unread
    case thinking
    case requiresInput
    case error
    case unknown

    var displayName: String {
        switch self {
        case .idle:
            AgentMicroLocalization.text("state.idle")
        case .unread:
            AgentMicroLocalization.text("state.unread")
        case .thinking:
            AgentMicroLocalization.text("state.thinking")
        case .requiresInput:
            AgentMicroLocalization.text("state.requiresInput")
        case .error:
            AgentMicroLocalization.text("state.error")
        case .unknown:
            AgentMicroLocalization.text("state.unknown")
        }
    }

    var colorHex: UInt32? {
        switch self {
        case .idle:
            0xFFFFFF
        case .unread:
            0x9BF396
        case .thinking:
            0x9CD5FE
        case .requiresInput:
            0xFFD0B8
        case .error:
            0xFF7373
        case .unknown:
            0xFFFFFF
        }
    }

    var isWorking: Bool {
        self == .thinking
    }
}

struct CodexTaskObservation: Equatable, Sendable {
    let session: AgentSession
    let state: CodexTaskState
    let currentAction: String?
    let lastEventAt: Date?
    let runStartedAt: Date?
    let stateChangedAt: Date?
    let usesFastModel: Bool

    var sessionKey: String {
        "\(self.session.host):\(self.session.id)"
    }
}

struct CodexRolloutSnapshot: Equatable, Sendable {
    let hasParsedEvents: Bool
    let isThinking: Bool
    let isRateLimited: Bool
    let hasBlockingError: Bool
    let hasPendingToolCall: Bool
    let requiresInput: Bool
    let currentAction: String?
    let lastEventAt: Date?
    let isTurnActive: Bool?
    let turnStartedAt: Date?
    let stateChangedAt: Date?
    let usesFastModel: Bool
}

enum CodexTaskStateResolver {
    static let defaultUnknownWindow: TimeInterval = 30
    static let defaultCompletedRetention: TimeInterval = 24 * 60 * 60
    static let defaultThinkingFreshness: TimeInterval = 2 * 60

    static func observation(
        session: AgentSession,
        snapshot: CodexRolloutSnapshot?,
        now: Date,
        unknownWindow: TimeInterval = CodexTaskStateResolver.defaultUnknownWindow,
        completedRetention: TimeInterval = CodexTaskStateResolver.defaultCompletedRetention,
        thinkingFreshness: TimeInterval = CodexTaskStateResolver.defaultThinkingFreshness) -> CodexTaskObservation?
    {
        let activity = snapshot?.lastEventAt ?? session.lastActivityAt ?? session.startedAt
        let activityAge = activity.map { max(0, now.timeIntervalSince($0)) }

        guard session.pid != nil else {
            guard activityAge.map({ $0 <= completedRetention }) ?? false else { return nil }
            let state: CodexTaskState = if let snapshot,
                                           snapshot.isTurnActive == true ||
                                           snapshot.hasPendingToolCall ||
                                           snapshot.isThinking ||
                                           snapshot.requiresInput ||
                                           snapshot.isRateLimited ||
                                           snapshot.hasBlockingError
            {
                self.liveState(
                    snapshot: snapshot,
                    activityAge: activityAge,
                    thinkingFreshness: thinkingFreshness)
            } else if snapshot?.isTurnActive == false {
                .unread
            } else {
                activityAge.map { $0 <= unknownWindow } == true ? .unknown : .unread
            }
            return CodexTaskObservation(
                session: session,
                state: state,
                currentAction: state == .thinking || state == .requiresInput || state == .unknown
                    ? snapshot?.currentAction
                    : nil,
                lastEventAt: activity,
                runStartedAt: snapshot?.turnStartedAt ?? snapshot?.stateChangedAt,
                stateChangedAt: snapshot?.stateChangedAt ?? activity,
                usesFastModel: snapshot?.usesFastModel ?? false)
        }

        guard let snapshot, snapshot.hasParsedEvents else {
            return CodexTaskObservation(
                session: session,
                state: .unknown,
                currentAction: nil,
                lastEventAt: activity,
                runStartedAt: session.startedAt,
                stateChangedAt: activity,
                usesFastModel: false)
        }

        let state = self.liveState(
            snapshot: snapshot,
            activityAge: activityAge,
            thinkingFreshness: thinkingFreshness)

        return CodexTaskObservation(
            session: session,
            state: state,
            currentAction: state == .thinking || state == .requiresInput ? snapshot.currentAction : nil,
            lastEventAt: activity,
            runStartedAt: snapshot.turnStartedAt ?? snapshot.stateChangedAt,
            stateChangedAt: snapshot.stateChangedAt ?? activity,
            usesFastModel: snapshot.usesFastModel)
    }

    private static func liveState(
        snapshot: CodexRolloutSnapshot,
        activityAge: TimeInterval?,
        thinkingFreshness: TimeInterval) -> CodexTaskState
    {
        if snapshot.isRateLimited || snapshot.hasBlockingError {
            return .error
        }
        if snapshot.requiresInput {
            return .requiresInput
        }
        if snapshot.hasPendingToolCall {
            return .thinking
        }
        if snapshot.isTurnActive == true {
            return .thinking
        }
        if snapshot.isThinking, activityAge.map({ $0 <= thinkingFreshness }) ?? false {
            return .thinking
        }
        return .idle
    }
}
