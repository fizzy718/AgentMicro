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
    static let animationFramesPerSlot = 21
    static let animationFrameInterval: TimeInterval = 0.05
    static let animationTimerTolerance: TimeInterval = 0.005
    static let blockSize = NSSize(width: 5.5, height: 4)
    static let horizontalStep: CGFloat = 6.5
    static let verticalStep: CGFloat = 5.5

    static func statusItemImage(
        states: [CodexTaskState],
        animationPhase: Int?) -> NSImage
    {
        let animatedSlotIndices = Self.animatedSlotIndices(for: states)
        let image = NSImage(size: NSSize(width: 19, height: 19), flipped: false) { bounds in
            let gridWidth = Self.blockSize.width + Self.horizontalStep * 2
            let originX = bounds.midX - gridWidth / 2
            let originY = bounds.midY + (Self.verticalStep - Self.blockSize.height) / 2

            for (index, slot) in Self.slotLayout.enumerated() {
                let rect = NSRect(
                    x: originX + CGFloat(slot.column) * Self.horizontalStep,
                    y: originY - CGFloat(slot.row) * Self.verticalStep,
                    width: Self.blockSize.width,
                    height: Self.blockSize.height)
                let state = states.indices.contains(index) ? states[index] : nil
                Self.drawBlock(
                    in: rect,
                    state: state,
                    opacity: Self.opacity(
                        forSlotAt: index,
                        animatedSlotIndices: animatedSlotIndices,
                        animationPhase: animationPhase))
            }
            return true
        }
        image.cacheMode = .always
        image.isTemplate = false
        image.accessibilityDescription = AgentMicroLocalization.text("accessibility.taskStatus")
        return image
    }

    static func statusItemImages(states: [CodexTaskState], animated: Bool) -> [NSImage] {
        guard animated else {
            return [self.statusItemImage(states: states, animationPhase: nil)]
        }
        return (0..<self.animationFrameCount(for: states)).map { phase in
            self.statusItemImage(states: states, animationPhase: phase)
        }
    }

    static func animatedSlotIndices(for states: [CodexTaskState]) -> [Int] {
        states
            .prefix(self.maximumTrackedTasks)
            .enumerated()
            .compactMap { index, state in self.shouldAnimate(state) ? index : nil }
    }

    static func shouldAnimate(_ state: CodexTaskState) -> Bool {
        switch state {
        case .thinking, .unread, .requiresInput, .error:
            true
        case .idle, .unknown:
            false
        }
    }

    static func animationFrameCount(for states: [CodexTaskState]) -> Int {
        max(1, self.animatedSlotIndices(for: states).count) * self.animationFramesPerSlot
    }

    static func opacity(
        forSlotAt index: Int,
        animatedSlotIndices: [Int],
        animationPhase: Int?) -> CGFloat
    {
        guard let animationPhase, !animatedSlotIndices.isEmpty else { return 1 }
        let animationFrameCount = animatedSlotIndices.count * Self.animationFramesPerSlot
        let normalizedPhase = animationPhase % animationFrameCount
        let activeSlot = animatedSlotIndices[normalizedPhase / Self.animationFramesPerSlot]
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
        let path = NSBezierPath(roundedRect: rect, xRadius: 1.2, yRadius: 1.2)
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
