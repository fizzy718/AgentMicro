import AppKit
import QuartzCore

enum AgentMicroMenuLayout {
    static let width: CGFloat = 310
    static let horizontalPadding: CGFloat = 20
    static let selectionHorizontalInset: CGFloat = 5
    static let selectionVerticalInset: CGFloat = 2
    static let selectionCornerRadius: CGFloat = 7
}

@MainActor
final class AgentMicroTaskMenuItemView: NSView {
    static let titleFontSize: CGFloat = 13

    private let onSelect: () -> Void
    let sessionKey: String
    private let indicator = AgentMicroTaskIndicatorView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let subtitleLabel = NSTextField(labelWithString: "")
    private let durationLabel = NSTextField(labelWithString: "")
    private let speedIndicator = NSImageView()
    private let usesFastModel: Bool
    private var trackingAreaReference: NSTrackingArea?
    private var isHovered = false

    init(row: AgentMicroMenuRow, onSelect: @escaping () -> Void) {
        self.onSelect = onSelect
        self.sessionKey = row.sessionKey
        self.usesFastModel = row.usesFastModel
        super.init(frame: NSRect(x: 0, y: 0, width: AgentMicroMenuLayout.width, height: 52))

        self.indicator.configure(state: row.state)

        self.titleLabel.stringValue = row.title
        self.titleLabel.font = .menuFont(ofSize: Self.titleFontSize)
        self.titleLabel.lineBreakMode = .byTruncatingTail

        self.subtitleLabel.stringValue = row.subtitle
        self.subtitleLabel.font = .menuFont(ofSize: 11)
        self.subtitleLabel.textColor = .secondaryLabelColor
        self.subtitleLabel.lineBreakMode = .byTruncatingTail
        self.subtitleLabel.isHidden = row.subtitle.isEmpty

        self.durationLabel.stringValue = row.duration
        self.durationLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        self.durationLabel.textColor = .secondaryLabelColor
        self.durationLabel.alignment = .right
        self.durationLabel.lineBreakMode = .byClipping

        self.speedIndicator.image = NSImage(
            systemSymbolName: "bolt.fill",
            accessibilityDescription: AgentMicroLocalization.text("task.fastMode"))
        self.speedIndicator.symbolConfiguration = NSImage.SymbolConfiguration(
            pointSize: 9,
            weight: .semibold)
        self.speedIndicator.contentTintColor = .secondaryLabelColor
        self.speedIndicator.imageScaling = .scaleProportionallyDown
        self.speedIndicator.isHidden = !row.usesFastModel

        self.addSubview(self.indicator)
        self.addSubview(self.titleLabel)
        self.addSubview(self.subtitleLabel)
        self.addSubview(self.durationLabel)
        self.addSubview(self.speedIndicator)

        self.setAccessibilityRole(.button)
        self.setAccessibilityLabel(
            ([
                row.title,
                row.subtitle,
                row.duration,
                row.usesFastModel ? AgentMicroLocalization.text("task.fastMode") : nil,
                row.state == .unread ? AgentMicroLocalization.text("accessibility.task.unread") : nil,
            ] as [String?])
                .compactMap(\.self)
                .filter { !$0.isEmpty }
                .joined(separator: ", "))
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    override func layout() {
        super.layout()
        let durationWidth: CGFloat = 82
        let speedWidth: CGFloat = self.usesFastModel ? 12 : 0
        let speedGap: CGFloat = self.usesFastModel ? 3 : 0
        let metadataWidth = durationWidth + speedGap + speedWidth
        let textX: CGFloat
        let textWidth: CGFloat
        if AgentMicroLocalization.isRightToLeft {
            self.indicator.frame = NSRect(
                x: self.bounds.width - AgentMicroMenuLayout.horizontalPadding - 14,
                y: 19,
                width: 14,
                height: 14)
            self.durationLabel.frame = NSRect(
                x: AgentMicroMenuLayout.horizontalPadding + speedWidth + speedGap,
                y: 18,
                width: durationWidth,
                height: 16)
            self.speedIndicator.frame = NSRect(
                x: AgentMicroMenuLayout.horizontalPadding,
                y: 20,
                width: speedWidth,
                height: 12)
            textX = AgentMicroMenuLayout.horizontalPadding + metadataWidth
            let textRight = self.bounds.width - AgentMicroMenuLayout.horizontalPadding - 26
            textWidth = max(0, textRight - textX)
            self.titleLabel.alignment = .right
            self.subtitleLabel.alignment = .right
        } else {
            self.indicator.frame = NSRect(
                x: AgentMicroMenuLayout.horizontalPadding,
                y: 19,
                width: 14,
                height: 14)
            self.durationLabel.frame = NSRect(
                x: self.bounds.width - metadataWidth - AgentMicroMenuLayout.horizontalPadding,
                y: 18,
                width: durationWidth,
                height: 16)
            self.speedIndicator.frame = NSRect(
                x: self.durationLabel.frame.maxX + speedGap,
                y: 20,
                width: speedWidth,
                height: 12)
            textX = AgentMicroMenuLayout.horizontalPadding + 26
            textWidth = max(
                0,
                self.bounds.width - textX - metadataWidth - AgentMicroMenuLayout.horizontalPadding)
            self.titleLabel.alignment = .left
            self.subtitleLabel.alignment = .left
        }
        let hasSubtitle = !self.subtitleLabel.stringValue.isEmpty
        self.titleLabel.frame = NSRect(x: textX, y: hasSubtitle ? 26 : 17, width: textWidth, height: 18)
        self.subtitleLabel.frame = NSRect(x: textX, y: 8, width: textWidth, height: 16)
    }

    override func draw(_ dirtyRect: NSRect) {
        if self.isHovered {
            NSColor.selectedContentBackgroundColor.setFill()
            let selectionRect = self.bounds.insetBy(
                dx: AgentMicroMenuLayout.selectionHorizontalInset,
                dy: AgentMicroMenuLayout.selectionVerticalInset)
            NSBezierPath(
                roundedRect: selectionRect,
                xRadius: AgentMicroMenuLayout.selectionCornerRadius,
                yRadius: AgentMicroMenuLayout.selectionCornerRadius).fill()
        }
        super.draw(dirtyRect)
    }

    override func updateTrackingAreas() {
        if let trackingAreaReference {
            self.removeTrackingArea(trackingAreaReference)
        }
        let trackingArea = NSTrackingArea(
            rect: self.bounds,
            options: [.activeAlways, .mouseEnteredAndExited],
            owner: self,
            userInfo: nil)
        self.addTrackingArea(trackingArea)
        self.trackingAreaReference = trackingArea
        super.updateTrackingAreas()
    }

    override func mouseEntered(with _: NSEvent) {
        self.activateExclusiveHover()
    }

    func activateExclusiveHover() {
        guard let menu = self.enclosingMenuItem?.menu else {
            self.setHovered(true)
            return
        }
        for case let view as AgentMicroTaskMenuItemView in menu.items.compactMap(\.view) {
            view.setHovered(view === self)
        }
    }

    var isHoveredForTesting: Bool {
        self.isHovered
    }

    var durationForTesting: String {
        self.durationLabel.stringValue
    }

    var showsFastModelIndicatorForTesting: Bool {
        !self.speedIndicator.isHidden
    }

    func updateDuration(_ duration: String) {
        self.durationLabel.stringValue = duration
    }

    override func mouseExited(with _: NSEvent) {
        self.setHovered(false)
    }

    override func mouseUp(with event: NSEvent) {
        guard self.bounds.contains(self.convert(event.locationInWindow, from: nil)) else { return }
        self.enclosingMenuItem?.menu?.cancelTracking()
        self.onSelect()
    }

    private func setHovered(_ hovered: Bool) {
        guard self.isHovered != hovered else { return }
        self.isHovered = hovered
        self.needsDisplay = true
    }
}

@MainActor
final class AgentMicroMenuHeaderView: NSView {
    static let titleFont = NSFont.systemFont(ofSize: 13, weight: .semibold)
    static let titleColor = NSColor.labelColor

    private let titleLabel = NSTextField(labelWithString: "")

    init(title: String) {
        super.init(frame: NSRect(x: 0, y: 0, width: AgentMicroMenuLayout.width, height: 34))
        self.titleLabel.stringValue = title
        self.titleLabel.font = Self.titleFont
        self.titleLabel.textColor = Self.titleColor
        self.titleLabel.lineBreakMode = .byTruncatingTail
        self.addSubview(self.titleLabel)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    override func layout() {
        super.layout()
        self.titleLabel.frame = NSRect(
            x: AgentMicroMenuLayout.horizontalPadding,
            y: 8,
            width: self.bounds.width - AgentMicroMenuLayout.horizontalPadding * 2,
            height: 18)
        self.titleLabel.alignment = AgentMicroLocalization.isRightToLeft ? .right : .left
    }
}

@MainActor
private final class AgentMicroTaskIndicatorView: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.wantsLayer = true
        self.layer?.cornerRadius = 3
        self.layer?.borderWidth = 0
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    func configure(state: CodexTaskState) {
        self.layer?.backgroundColor = AgentMicroStatusIcon.fillColor(for: state).cgColor
        self.layer?.opacity = 1
        self.layer?.removeAnimation(forKey: "agentmicro-breathing")

        guard state.isWorking,
              !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        else { return }
        let animation = CABasicAnimation(keyPath: "opacity")
        animation.fromValue = 0.3
        animation.toValue = 1
        animation.duration = 0.85
        animation.autoreverses = true
        animation.repeatCount = .infinity
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        self.layer?.add(animation, forKey: "agentmicro-breathing")
    }
}
