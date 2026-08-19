import AppKit
import CodexBarUI
import SwiftUI

@MainActor
final class AgentMicroUsageMenuItemView: NSView {
    private var hostingView: NSView?

    init(state: AgentMicroUsageState, now: Date = Date()) {
        let height: CGFloat = if case .available = state { 70 } else { 34 }
        super.init(frame: NSRect(x: 0, y: 0, width: AgentMicroMenuLayout.width, height: height))

        let view = UsageMetricView(
            presentation: self.presentation(state: state, now: now),
            tint: Color(nsColor: .systemTeal))
            .padding(.horizontal, AgentMicroMenuLayout.horizontalPadding)
            .frame(width: AgentMicroMenuLayout.width, alignment: .leading)
        let hostingView = NSHostingView(rootView: view)
        self.hostingView = hostingView
        self.addSubview(hostingView)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    override func layout() {
        super.layout()
        self.hostingView?.frame = self.bounds
    }

    private func presentation(state: AgentMicroUsageState, now: Date) -> UsageMetricPresentation {
        switch state {
        case .loading:
            return UsageMetricPresentation(
                title: AgentMicroLocalization.text("menu.usage.loading"),
                percent: 0,
                percentLabel: "",
                resetText: nil,
                statusText: "",
                accessibilityLabel: AgentMicroLocalization.text("menu.usage.loading"),
                compactHeader: true,
                showsProgress: false)
        case .unavailable:
            return UsageMetricPresentation(
                title: AgentMicroLocalization.text("menu.usage.unavailable"),
                percent: 0,
                percentLabel: "",
                resetText: nil,
                statusText: "",
                accessibilityLabel: AgentMicroLocalization.text("menu.usage.unavailable"),
                compactHeader: true,
                showsProgress: false)
        case let .available(usage):
            let title = String(
                format: AgentMicroLocalization.text("menu.usage.weeklyFormat"),
                locale: Locale(identifier: AgentMicroLocalization.effectiveLanguageIdentifier),
                arguments: [usage.clampedUsedPercent])
            let resetText = usage.resetsAt.map {
                AgentMicroLocalization.text(
                    "menu.usage.resetsInFormat",
                    arguments: self.compactDuration(seconds: $0.timeIntervalSince(now)))
            }
            return UsageMetricPresentation(
                title: title,
                percent: usage.clampedRemainingPercent,
                percentLabel: title,
                resetText: resetText,
                detailLeftText: self.paceDescription(usage),
                detailRightText: self.etaDescription(usage),
                pacePercent: usage.expectedUsedPercent.map { 100 - $0 },
                paceOnTop: usage.expectedUsedPercent.map { usage.usedPercent <= $0 } ?? true,
                warningMarkerPercents: usage.warningMarkerPercents,
                accessibilityLabel: title,
                compactHeader: true)
        }
    }

    private func paceDescription(_ usage: AgentMicroWeeklyUsage) -> String? {
        guard let delta = usage.paceDeltaPercent else { return nil }
        let rounded = Int(abs(delta).rounded())
        if rounded == 0 || abs(delta) <= 2 {
            return AgentMicroLocalization.text("menu.usage.onPace")
        }
        return delta > 0
            ? AgentMicroLocalization.text("menu.usage.deficitFormat", arguments: rounded)
            : AgentMicroLocalization.text("menu.usage.reserveFormat", arguments: rounded)
    }

    private func etaDescription(_ usage: AgentMicroWeeklyUsage) -> String? {
        if usage.willLastToReset {
            return AgentMicroLocalization.text("menu.usage.lastsUntilReset")
        }
        guard let etaSeconds = usage.etaSeconds else { return nil }
        return AgentMicroLocalization.text(
            "menu.usage.runsOutInFormat",
            arguments: self.compactDuration(seconds: etaSeconds))
    }

    private func compactDuration(seconds: TimeInterval) -> String {
        let totalMinutes = max(0, Int(ceil(seconds / 60)))
        let days = totalMinutes / (24 * 60)
        let hours = totalMinutes % (24 * 60) / 60
        let minutes = totalMinutes % 60
        if days > 0, hours > 0 { return "\(days)d \(hours)h" }
        if days > 0 { return "\(days)d" }
        if hours > 0, minutes > 0 { return "\(hours)h \(minutes)m" }
        if hours > 0 { return "\(hours)h" }
        return "\(minutes)m"
    }
}
