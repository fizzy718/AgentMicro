import AppKit

struct AgentMicroIconSlot: Equatable {
    let column: Int
    let row: Int
}

@MainActor
enum AgentMicroStatusIcon {
    static let maximumTrackedTasks = 6
    static let slotLayout = [
        AgentMicroIconSlot(column: 0, row: 0),
        AgentMicroIconSlot(column: 1, row: 0),
        AgentMicroIconSlot(column: 2, row: 0),
        AgentMicroIconSlot(column: 2, row: 1),
        AgentMicroIconSlot(column: 1, row: 1),
        AgentMicroIconSlot(column: 0, row: 1),
    ]
    static let animationFramesPerSlot = 9
    static let animationFrameInterval: TimeInterval = 0.07
    static let animationFrameCount = Self.maximumTrackedTasks * Self.animationFramesPerSlot

    static func statusItemImage(
        states: [CodexTaskState],
        animationPhase: Int?) -> NSImage
    {
        let image = NSImage(size: NSSize(width: 19, height: 19), flipped: false) { bounds in
            let blockSize = NSSize(width: 4.5, height: 6)
            let horizontalStep: CGFloat = 6
            let verticalStep: CGFloat = 7.5
            let originX = bounds.minX + 1.25
            let originY = bounds.maxY - 1.75 - blockSize.height

            for (index, slot) in Self.slotLayout.enumerated() {
                let rect = NSRect(
                    x: originX + CGFloat(slot.column) * horizontalStep,
                    y: originY - CGFloat(slot.row) * verticalStep,
                    width: blockSize.width,
                    height: blockSize.height)
                let state = states.indices.contains(index) ? states[index] : nil
                Self.drawBlock(
                    in: rect,
                    state: state,
                    opacity: Self.opacity(forSlotAt: index, animationPhase: animationPhase))
            }
            return true
        }
        image.isTemplate = false
        image.accessibilityDescription = AgentMicroLocalization.text("accessibility.taskStatus")
        return image
    }

    static func opacity(forSlotAt index: Int, animationPhase: Int?) -> CGFloat {
        guard let animationPhase else { return 1 }
        let normalizedPhase = animationPhase % Self.animationFrameCount
        let activeSlot = normalizedPhase / Self.animationFramesPerSlot
        guard index == activeSlot else { return 1 }
        let frame = normalizedPhase % Self.animationFramesPerSlot
        let progress = CGFloat(frame) / CGFloat(Self.animationFramesPerSlot - 1)
        return 1 - 0.55 * sin(.pi * progress)
    }

    private static func drawBlock(
        in rect: NSRect,
        state: CodexTaskState?,
        opacity: CGFloat)
    {
        let path = NSBezierPath(roundedRect: rect, xRadius: 1.35, yRadius: 1.35)
        let color = Self.fillColor(for: state)
        color.withAlphaComponent(color.alphaComponent * opacity).setFill()
        path.fill()
    }

    static func fillColor(for state: CodexTaskState?) -> NSColor {
        state.flatMap(self.color(for:)) ??
            NSColor.labelColor.withAlphaComponent(0.22)
    }

    static func color(for state: CodexTaskState) -> NSColor? {
        guard let hex = state.colorHex else { return nil }
        return NSColor(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1)
    }
}
