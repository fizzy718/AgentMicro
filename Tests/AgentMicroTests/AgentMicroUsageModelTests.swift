import CodexBarCore
import Foundation
import Testing
@testable import AgentMicro

struct AgentMicroUsageModelTests {
    @Test
    func `weekly usage projects the Codex secondary rate window`() throws {
        let resetAt = Date(timeIntervalSince1970: 20000)
        let snapshot = UsageSnapshot(
            primary: RateWindow(
                usedPercent: 12,
                windowMinutes: 300,
                resetsAt: nil,
                resetDescription: nil),
            secondary: RateWindow(
                usedPercent: 43,
                windowMinutes: 7 * 24 * 60,
                resetsAt: resetAt,
                resetDescription: nil),
            updatedAt: Date(timeIntervalSince1970: 10000))

        let state = AgentMicroUsageModel.state(snapshot: snapshot, isLoading: false)
        let projectedUsage: AgentMicroWeeklyUsage? = if case let .available(usage) = state {
            usage
        } else {
            nil
        }
        let usage = try #require(projectedUsage)

        #expect(usage.usedPercent == 43)
        #expect(usage.clampedUsedPercent == 43)
        #expect(usage.resetsAt == resetAt)
    }

    @Test
    func `weekly usage includes pace forecast and quota markers`() throws {
        let now = Date(timeIntervalSince1970: 4 * 24 * 60 * 60)
        let resetAt = Date(timeIntervalSince1970: 7 * 24 * 60 * 60)
        let snapshot = UsageSnapshot(
            primary: nil,
            secondary: RateWindow(
                usedPercent: 70,
                windowMinutes: 7 * 24 * 60,
                resetsAt: resetAt,
                resetDescription: nil),
            updatedAt: now)

        let state = AgentMicroUsageModel.state(snapshot: snapshot, isLoading: false, now: now)
        let projectedUsage: AgentMicroWeeklyUsage? = if case let .available(usage) = state {
            usage
        } else {
            nil
        }
        let usage = try #require(projectedUsage)

        #expect(usage.expectedUsedPercent != nil)
        #expect(usage.paceDeltaPercent != nil)
        #expect(usage.etaSeconds != nil)
        #expect(!usage.willLastToReset)
        #expect(usage.warningMarkerPercents == [50, 80])
    }

    @Test
    func `usage state distinguishes loading and unavailable data`() {
        #expect(AgentMicroUsageModel.state(snapshot: nil, isLoading: true) == .loading)
        #expect(AgentMicroUsageModel.state(snapshot: nil, isLoading: false) == .unavailable)
    }

    @Test
    func `weekly usage clamps provider values only for display`() {
        #expect(AgentMicroWeeklyUsage(usedPercent: -5, resetsAt: nil).clampedUsedPercent == 0)
        #expect(AgentMicroWeeklyUsage(usedPercent: 140, resetsAt: nil).clampedUsedPercent == 100)
    }

    @Test
    func `usage refresh becomes due after five minutes`() {
        let now = Date(timeIntervalSince1970: 10000)

        #expect(AgentMicroUsageModel.shouldRefresh(lastAttemptAt: nil, now: now))
        #expect(!AgentMicroUsageModel.shouldRefresh(lastAttemptAt: now.addingTimeInterval(-299), now: now))
        #expect(AgentMicroUsageModel.shouldRefresh(lastAttemptAt: now.addingTimeInterval(-300), now: now))
    }
}
