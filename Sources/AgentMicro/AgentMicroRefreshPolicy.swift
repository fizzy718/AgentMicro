import Foundation

enum AgentMicroRefreshPolicy {
    static let activeInterval: Duration = .seconds(2)
    static let idleInterval: Duration = .seconds(5)
    static let reconciliationDelays: [Duration] = [
        .milliseconds(150),
        .milliseconds(350),
        .milliseconds(800),
    ]

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
