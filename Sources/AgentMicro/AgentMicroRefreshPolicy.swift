import Foundation

enum AgentMicroRefreshTrigger: Equatable, Sendable {
    case polling
    case event
}

enum AgentMicroRefreshPolicy {
    static let activeInterval: Duration = .seconds(15)
    static let idleInterval: Duration = .seconds(30)
    static let discoveryEventDelay: Duration = .seconds(2)
    static let reconciliationDelays: [Duration] = [
        .milliseconds(150),
        .milliseconds(350),
        .milliseconds(800),
    ]

    static func shouldQueueFollowUp(
        whileRefreshIsRunning: Bool,
        trigger: AgentMicroRefreshTrigger) -> Bool
    {
        whileRefreshIsRunning && trigger == .event
    }

    static func interval(
        tasks: [CodexTaskObservation],
        isDesktopAppRunning: Bool) -> Duration
    {
        if isDesktopAppRunning ||
            tasks.contains(where: { $0.session.pid != nil || $0.state.isWorking })
        {
            return self.activeInterval
        }
        return self.idleInterval
    }
}
