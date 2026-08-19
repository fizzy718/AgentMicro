import CodexBarCore
import Foundation

struct AgentMicroWeeklyUsage: Equatable, Sendable {
    let usedPercent: Double
    let resetsAt: Date?
    let expectedUsedPercent: Double?
    let paceDeltaPercent: Double?
    let etaSeconds: TimeInterval?
    let willLastToReset: Bool
    let warningMarkerPercents: [Double]

    init(
        usedPercent: Double,
        resetsAt: Date?,
        expectedUsedPercent: Double? = nil,
        paceDeltaPercent: Double? = nil,
        etaSeconds: TimeInterval? = nil,
        willLastToReset: Bool = false,
        warningMarkerPercents: [Double] = [])
    {
        self.usedPercent = usedPercent
        self.resetsAt = resetsAt
        self.expectedUsedPercent = expectedUsedPercent
        self.paceDeltaPercent = paceDeltaPercent
        self.etaSeconds = etaSeconds
        self.willLastToReset = willLastToReset
        self.warningMarkerPercents = warningMarkerPercents
    }

    var clampedUsedPercent: Double {
        min(100, max(0, self.usedPercent))
    }

    var clampedRemainingPercent: Double {
        100 - self.clampedUsedPercent
    }
}

enum AgentMicroUsageState: Equatable, Sendable {
    case loading
    case available(AgentMicroWeeklyUsage)
    case unavailable
}

enum AgentMicroUsageModel {
    static let refreshInterval: TimeInterval = 5 * 60

    static func state(
        snapshot: UsageSnapshot?,
        isLoading: Bool,
        now: Date = Date()) -> AgentMicroUsageState
    {
        if let weekly = snapshot?.secondary {
            let pace = self.displayableWeeklyPace(window: weekly, now: now)
            return .available(AgentMicroWeeklyUsage(
                usedPercent: weekly.usedPercent,
                resetsAt: weekly.resetsAt,
                expectedUsedPercent: pace.flatMap { abs($0.deltaPercent) > 2 ? $0.expectedUsedPercent : nil },
                paceDeltaPercent: pace?.deltaPercent,
                etaSeconds: pace?.etaSeconds,
                willLastToReset: pace?.willLastToReset ?? false,
                warningMarkerPercents: QuotaWarningThresholds.active(QuotaWarningThresholds.defaults)
                    .map { 100 - Double($0) }
                    .filter { $0 > 0 && $0 < 100 }))
        }
        return isLoading ? .loading : .unavailable
    }

    static func shouldRefresh(lastAttemptAt: Date?, now: Date = Date()) -> Bool {
        guard let lastAttemptAt else { return true }
        return now.timeIntervalSince(lastAttemptAt) >= self.refreshInterval
    }

    private static func displayableWeeklyPace(window: RateWindow, now: Date) -> UsagePace? {
        guard window.remainingPercent > 0,
              let pace = UsagePace.weekly(
                  window: window,
                  now: now,
                  defaultWindowMinutes: 7 * 24 * 60)
        else { return nil }
        return pace.expectedUsedPercent >= 3 || pace.etaSeconds == 0 ? pace : nil
    }
}
