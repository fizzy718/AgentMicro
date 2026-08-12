import SwiftUI

public struct UsageMetricPresentation: Sendable {
    public let title: String
    public let percent: Double
    public let percentLabel: String
    public let resetText: String?
    public let statusText: String?
    public let detailLeftText: String?
    public let detailRightText: String?
    public let detailText: String?
    public let pacePercent: Double?
    public let paceOnTop: Bool
    public let warningMarkerPercents: [Double]
    public let workdayMarkerPercents: [Double]
    public let accessibilityLabel: String
    public let cardStyle: Bool
    public let compactHeader: Bool
    public let showsProgress: Bool
    public let supplementalLines: [String]

    public init(
        title: String,
        percent: Double,
        percentLabel: String,
        resetText: String?,
        statusText: String? = nil,
        detailLeftText: String? = nil,
        detailRightText: String? = nil,
        detailText: String? = nil,
        pacePercent: Double? = nil,
        paceOnTop: Bool = true,
        warningMarkerPercents: [Double] = [],
        workdayMarkerPercents: [Double] = [],
        accessibilityLabel: String,
        cardStyle: Bool = false,
        compactHeader: Bool = false,
        showsProgress: Bool = true,
        supplementalLines: [String] = [])
    {
        self.title = title
        self.percent = percent
        self.percentLabel = percentLabel
        self.resetText = resetText
        self.statusText = statusText
        self.detailLeftText = detailLeftText
        self.detailRightText = detailRightText
        self.detailText = detailText
        self.pacePercent = pacePercent
        self.paceOnTop = paceOnTop
        self.warningMarkerPercents = warningMarkerPercents
        self.workdayMarkerPercents = workdayMarkerPercents
        self.accessibilityLabel = accessibilityLabel
        self.cardStyle = cardStyle
        self.compactHeader = compactHeader
        self.showsProgress = showsProgress
        self.supplementalLines = supplementalLines
    }
}

public struct UsageMetricView: View {
    private let presentation: UsageMetricPresentation
    private let tint: Color
    private let isHighlighted: Bool

    public init(
        presentation: UsageMetricPresentation,
        tint: Color,
        isHighlighted: Bool = false)
    {
        self.presentation = presentation
        self.tint = tint
        self.isHighlighted = isHighlighted
    }

    public var body: some View {
        Group {
            if self.presentation.compactHeader {
                self.compactBody
            } else {
                self.standardBody
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(self.presentation.cardStyle ? 10 : 0)
        .background(
            self.presentation.cardStyle
                ? Color.secondary.opacity(self.isHighlighted ? 0.2 : 0.08)
                : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: self.presentation.cardStyle ? 10 : 0))
    }

    private var standardBody: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(self.presentation.title)
                .font(.body)
                .fontWeight(.medium)
            if !self.presentation.showsProgress {
                EmptyView()
            } else if let statusText = self.presentation.statusText {
                Text(statusText)
                    .font(.footnote)
                    .foregroundStyle(self.secondaryColor)
                    .lineLimit(1)
            } else {
                SharedUsageProgressBar(
                    percent: self.presentation.percent,
                    tint: self.tint,
                    accessibilityLabel: self.presentation.accessibilityLabel,
                    pacePercent: self.presentation.pacePercent,
                    paceOnTop: self.presentation.paceOnTop,
                    warningMarkerPercents: self.presentation.warningMarkerPercents,
                    workdayMarkerPercents: self.presentation.workdayMarkerPercents,
                    isHighlighted: self.isHighlighted)
                VStack(alignment: .leading, spacing: 2) {
                    self.detailRow(
                        left: self.presentation.percentLabel,
                        right: self.presentation.resetText,
                        leftColor: self.primaryColor)
                    if self.presentation.detailLeftText != nil || self.presentation.detailRightText != nil {
                        self.detailRow(
                            left: self.presentation.detailLeftText,
                            right: self.presentation.detailRightText,
                            leftColor: self.primaryColor)
                    }
                    ForEach(Array(self.presentation.supplementalLines.enumerated()), id: \.offset) { index, line in
                        Text(line)
                            .font(.footnote)
                            .foregroundStyle(index == 0 ? self.primaryColor : self.secondaryColor)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if let detailText = self.presentation.detailText {
                    Text(detailText)
                        .font(.footnote)
                        .foregroundStyle(self.secondaryColor)
                        .lineLimit(1)
                }
            }
        }
    }

    private var compactBody: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(self.presentation.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(self.primaryColor)
                    .lineLimit(1)
                Spacer(minLength: 8)
                if let resetText = self.presentation.resetText {
                    Text(resetText)
                        .font(.system(size: 11, weight: .regular))
                        .monospacedDigit()
                        .foregroundStyle(self.secondaryColor)
                        .lineLimit(1)
                }
            }
            if !self.presentation.showsProgress {
                EmptyView()
            } else if let statusText = self.presentation.statusText {
                Text(statusText)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(self.secondaryColor)
                    .lineLimit(1)
            } else {
                SharedUsageProgressBar(
                    percent: self.presentation.percent,
                    tint: self.tint,
                    accessibilityLabel: self.presentation.accessibilityLabel,
                    pacePercent: self.presentation.pacePercent,
                    paceOnTop: self.presentation.paceOnTop,
                    warningMarkerPercents: self.presentation.warningMarkerPercents,
                    workdayMarkerPercents: self.presentation.workdayMarkerPercents,
                    isHighlighted: self.isHighlighted)
                if self.presentation.detailLeftText != nil || self.presentation.detailRightText != nil {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        if let detailLeftText = self.presentation.detailLeftText {
                            Text(detailLeftText)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(self.secondaryColor)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 8)
                        if let detailRightText = self.presentation.detailRightText {
                            Text(detailRightText)
                                .font(.system(size: 11, weight: .regular))
                                .monospacedDigit()
                                .foregroundStyle(self.secondaryColor)
                                .lineLimit(1)
                        }
                    }
                }
            }
        }
    }

    private var primaryColor: Color {
        self.isHighlighted ? Color(nsColor: .selectedMenuItemTextColor) : Color(nsColor: .controlTextColor)
    }

    private var secondaryColor: Color {
        self.isHighlighted ? Color(nsColor: .selectedMenuItemTextColor) : Color(nsColor: .secondaryLabelColor)
    }

    private func detailRow(left: String?, right: String?, leftColor: Color) -> some View {
        HStack(alignment: .firstTextBaseline) {
            if let left {
                Text(left).font(.footnote).foregroundStyle(leftColor).lineLimit(1)
            }
            Spacer()
            if let right {
                Text(right).font(.footnote).foregroundStyle(self.secondaryColor).lineLimit(1)
            }
        }
    }
}

private struct SharedUsageProgressBar: View {
    let percent: Double
    let tint: Color
    let accessibilityLabel: String
    let pacePercent: Double?
    let paceOnTop: Bool
    let warningMarkerPercents: [Double]
    let workdayMarkerPercents: [Double]
    let isHighlighted: Bool

    var body: some View {
        Canvas { context, size in
            let rect = CGRect(origin: .zero, size: size)
            let radius = size.height / 2
            context.clip(to: Path(rect))
            context.fill(
                Path(roundedRect: rect, cornerRadius: radius),
                with: .color(self.trackColor))

            let fillWidth = size.width * self.clamped(self.percent) / 100
            if fillWidth > 0 {
                context.fill(
                    Path(roundedRect: CGRect(x: 0, y: 0, width: fillWidth, height: size.height), cornerRadius: radius),
                    with: .color(self.isHighlighted ? .white : self.tint))
            }

            for percent in self.normalized(self.workdayMarkerPercents) {
                let x = size.width * percent / 100
                context.fill(
                    Path(CGRect(x: x - 0.5, y: size.height / 2, width: 1, height: size.height / 2)),
                    with: .color(self.isHighlighted ? .white.opacity(0.55) : .primary.opacity(0.3)))
            }
            for percent in self.normalized(self.warningMarkerPercents) {
                let x = size.width * percent / 100
                context.blendMode = .destinationOut
                context.fill(Path(CGRect(x: x - 2.5, y: 0, width: 5, height: size.height)), with: .color(.white))
                context.blendMode = .normal
                context.fill(
                    Path(CGRect(x: x - 0.5, y: 0, width: 1, height: size.height)),
                    with: .color(self.isHighlighted ? .white : .primary.opacity(0.68)))
            }
            if let pacePercent {
                let x = size.width * self.clamped(pacePercent) / 100
                context.blendMode = .destinationOut
                context.fill(Path(CGRect(x: x - 3, y: 0, width: 6, height: size.height)), with: .color(.white))
                context.blendMode = .normal
                let color: Color = self.isHighlighted ? .white : (self.paceOnTop ? .green : .red)
                context.fill(Path(CGRect(x: x - 1, y: 0, width: 2, height: size.height)), with: .color(color))
            }
        }
        .frame(height: 6)
        .accessibilityLabel(self.accessibilityLabel)
        .accessibilityValue("\(Int(self.clamped(self.percent).rounded()))%")
    }

    private var trackColor: Color {
        self.isHighlighted ? .white.opacity(0.22) : Color(nsColor: .tertiaryLabelColor).opacity(0.22)
    }

    private func clamped(_ value: Double) -> Double {
        min(100, max(0, value))
    }

    private func normalized(_ values: [Double]) -> [Double] {
        values.map(self.clamped).filter { $0 > 0 && $0 < 100 }
    }
}
