import AppKit
import ApplicationServices
import CodexBarCore
import Foundation

struct CodexEnhancedStatusSnapshot: Equatable {
    let selectedSessionKey: String?
    let stateOverride: CodexTaskState?
}

enum AgentMicroAccessibilityAccess {
    static var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    @discardableResult
    static func requestPermission() -> Bool {
        AXIsProcessTrustedWithOptions(
            ["AXTrustedCheckOptionPrompt": true] as CFDictionary)
    }

    static func openSystemSettings() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
        else { return }
        NSWorkspace.shared.open(url)
    }
}

enum CodexEnhancedStatusResolver {
    static func selectedSessionKey(
        tasks: [CodexTaskObservation],
        windowTitle: String?,
        selectedLabels: [String]) -> String?
    {
        let windowTitle = windowTitle.map(self.normalize)
        let selectedLabels = selectedLabels.map(self.normalize).filter { !$0.isEmpty }
        let scored = tasks.compactMap { task -> (key: String, score: Int)? in
            var score = 0
            if let name = task.session.sessionName.map(self.normalize), !name.isEmpty {
                if windowTitle == name {
                    score = max(score, 10)
                } else if let windowTitle, name.count >= 4, windowTitle.contains(name) {
                    score = max(score, 8)
                }
                for label in selectedLabels {
                    if label == name {
                        score = max(score, 10)
                    } else if name.count >= 4, label.contains(name) {
                        score = max(score, 8)
                    }
                }
            }
            if let name = task.session.projectName.map(self.normalize), !name.isEmpty {
                if windowTitle == name {
                    score = max(score, 5)
                } else if let windowTitle, name.count >= 4, windowTitle.contains(name) {
                    score = max(score, 4)
                }
                for label in selectedLabels {
                    if label == name {
                        score = max(score, 5)
                    } else if name.count >= 4, label.contains(name) {
                        score = max(score, 4)
                    }
                }
            }
            return score > 0 ? (task.sessionKey, score) : nil
        }
        guard let bestScore = scored.map(\.score).max() else { return nil }
        let bestMatches = scored.filter { $0.score == bestScore }
        guard bestMatches.count == 1 else { return nil }
        return bestMatches[0].key
    }

    static func stateOverride(buttonLabels: [String], alertLabels: [String]) -> CodexTaskState? {
        let buttons = buttonLabels.map(self.normalize)
        let alerts = alertLabels.map(self.normalize)
        if alerts.contains(where: self.isBlockingErrorLabel) {
            return .error
        }
        let hasApproval = buttons.contains(where: self.isApprovalButton)
        let hasRejection = buttons.contains(where: self.isRejectionButton)
        return hasApproval && hasRejection ? .requiresInput : nil
    }

    private static func normalize(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }

    private static func isApprovalButton(_ value: String) -> Bool {
        [
            "allow",
            "allow once",
            "always allow",
            "approve",
            "grant access",
            "允许",
            "允许一次",
            "始终允许",
            "批准",
            "授权",
        ].contains { value == $0 || value.hasPrefix($0) }
    }

    private static func isRejectionButton(_ value: String) -> Bool {
        [
            "deny",
            "decline",
            "reject",
            "not now",
            "拒绝",
            "不允许",
            "暂不",
        ].contains { value == $0 || value.hasPrefix($0) }
    }

    private static func isBlockingErrorLabel(_ value: String) -> Bool {
        [
            "something went wrong",
            "task failed",
            "execution failed",
            "unable to continue",
            "发生错误",
            "出了点问题",
            "任务失败",
            "执行失败",
            "无法继续",
        ].contains(where: value.contains)
    }
}

struct CodexEnhancedStatusTracker {
    private struct Evidence {
        let state: CodexTaskState
        let activity: Date?
    }

    private var evidenceBySessionKey: [String: Evidence] = [:]

    mutating func reset() {
        self.evidenceBySessionKey.removeAll()
    }

    mutating func apply(
        snapshot: CodexEnhancedStatusSnapshot?,
        to tasks: [CodexTaskObservation]) -> [CodexTaskObservation]
    {
        let taskKeys = Set(tasks.map(\.sessionKey))
        self.evidenceBySessionKey = self.evidenceBySessionKey.filter { taskKeys.contains($0.key) }
        for task in tasks {
            guard let evidence = self.evidenceBySessionKey[task.sessionKey] else { continue }
            if (Self.activity(of: task) ?? .distantPast) >
                (evidence.activity ?? .distantPast)
            {
                self.evidenceBySessionKey.removeValue(forKey: task.sessionKey)
            }
        }

        if let sessionKey = snapshot?.selectedSessionKey,
           let state = snapshot?.stateOverride,
           let task = tasks.first(where: { $0.sessionKey == sessionKey })
        {
            self.evidenceBySessionKey[sessionKey] = Evidence(
                state: state,
                activity: Self.activity(of: task))
        }

        return tasks.map { task in
            guard let evidence = self.evidenceBySessionKey[task.sessionKey] else { return task }
            let state = Self.higherPriority(task.state, evidence.state)
            guard state != task.state else { return task }
            return CodexTaskObservation(
                session: task.session,
                state: state,
                currentAction: task.currentAction,
                lastEventAt: task.lastEventAt,
                runStartedAt: task.runStartedAt,
                stateChangedAt: task.stateChangedAt,
                usesFastModel: task.usesFastModel)
        }
    }

    private static func activity(of task: CodexTaskObservation) -> Date? {
        [task.lastEventAt, task.stateChangedAt, task.session.lastActivityAt]
            .compactMap(\.self)
            .max()
    }

    private static func higherPriority(
        _ current: CodexTaskState,
        _ enhanced: CodexTaskState) -> CodexTaskState
    {
        if current == .error || enhanced == .error {
            return .error
        }
        if current == .requiresInput || enhanced == .requiresInput {
            return .requiresInput
        }
        return current
    }
}

@MainActor
final class CodexEnhancedStatusReader {
    private static let maximumElementCount = 1000
    nonisolated static let minimumScanInterval: TimeInterval = 1
    private var lastScanAt: Date?
    private var cachedSnapshot: CodexEnhancedStatusSnapshot?

    func snapshot(
        for tasks: [CodexTaskObservation],
        now: Date = Date()) -> CodexEnhancedStatusSnapshot?
    {
        if Self.shouldReuseCachedSnapshot(lastScanAt: self.lastScanAt, now: now) {
            return self.cachedSnapshot
        }
        self.lastScanAt = now
        self.cachedSnapshot = nil
        guard AgentMicroAccessibilityAccess.isTrusted,
              let application = NSRunningApplication.runningApplications(
                  withBundleIdentifier: SessionWindowFocuser.codexApplicationBundleIdentifier)
                  .first(where: \.isActive)
        else { return nil }

        let appElement = AXUIElementCreateApplication(application.processIdentifier)
        guard let window = Self.elementAttribute(kAXFocusedWindowAttribute, from: appElement) else {
            return nil
        }

        let evidence = Self.collectEvidence(from: window)
        let selectedSessionKey = CodexEnhancedStatusResolver.selectedSessionKey(
            tasks: tasks,
            windowTitle: evidence.windowTitle,
            selectedLabels: evidence.selectedLabels)
        guard selectedSessionKey != nil else { return nil }
        let snapshot = CodexEnhancedStatusSnapshot(
            selectedSessionKey: selectedSessionKey,
            stateOverride: CodexEnhancedStatusResolver.stateOverride(
                buttonLabels: evidence.buttonLabels,
                alertLabels: evidence.alertLabels))
        self.cachedSnapshot = snapshot
        return snapshot
    }

    func resetCache() {
        self.lastScanAt = nil
        self.cachedSnapshot = nil
    }

    nonisolated static func shouldReuseCachedSnapshot(lastScanAt: Date?, now: Date) -> Bool {
        guard let lastScanAt else { return false }
        return now.timeIntervalSince(lastScanAt) < self.minimumScanInterval
    }

    private struct AccessibilityEvidence {
        var windowTitle: String?
        var selectedLabels: [String] = []
        var buttonLabels: [String] = []
        var alertLabels: [String] = []
    }

    private struct PendingElement {
        let element: AXUIElement
        let insideAlert: Bool
    }

    private static func collectEvidence(from window: AXUIElement) -> AccessibilityEvidence {
        var evidence = AccessibilityEvidence(windowTitle: self.stringAttribute(
            kAXTitleAttribute,
            from: window))
        var queue = [PendingElement(element: window, insideAlert: false)]
        var cursor = 0

        while cursor < queue.count, cursor < self.maximumElementCount {
            let pending = queue[cursor]
            cursor += 1
            let role = self.stringAttribute(kAXRoleAttribute, from: pending.element)
            let subrole = self.stringAttribute(kAXSubroleAttribute, from: pending.element)
            let insideAlert = pending.insideAlert ||
                role == kAXSheetRole ||
                subrole == kAXDialogSubrole
            let isSelected = self.boolAttribute(kAXSelectedAttribute, from: pending.element) == true
            let shouldReadLabels = isSelected || role == kAXButtonRole || insideAlert
            let labels = shouldReadLabels ? self.labels(for: pending.element) : []
            if isSelected {
                evidence.selectedLabels.append(contentsOf: labels)
            }
            if role == kAXButtonRole {
                evidence.buttonLabels.append(contentsOf: labels)
            }
            if insideAlert {
                evidence.alertLabels.append(contentsOf: labels)
            }
            for child in self.elementArrayAttribute(kAXChildrenAttribute, from: pending.element) {
                queue.append(PendingElement(element: child, insideAlert: insideAlert))
            }
        }
        return evidence
    }

    private static func labels(for element: AXUIElement) -> [String] {
        [
            self.stringAttribute(kAXTitleAttribute, from: element),
            self.stringAttribute(kAXValueAttribute, from: element),
            self.stringAttribute(kAXDescriptionAttribute, from: element),
            self.stringAttribute(kAXHelpAttribute, from: element),
        ]
            .compactMap(\.self)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    private static func stringAttribute(_ name: String, from element: AXUIElement) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else {
            return nil
        }
        return value as? String
    }

    private static func boolAttribute(_ name: String, from element: AXUIElement) -> Bool? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else {
            return nil
        }
        if let value = value as? Bool {
            return value
        }
        return (value as? NSNumber)?.boolValue
    }

    private static func elementAttribute(_ name: String, from element: AXUIElement) -> AXUIElement? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success,
              let value,
              CFGetTypeID(value) == AXUIElementGetTypeID()
        else { return nil }
        return unsafeDowncast(value, to: AXUIElement.self)
    }

    private static func elementArrayAttribute(
        _ name: String,
        from element: AXUIElement) -> [AXUIElement]
    {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success,
              let values = value as? [AXUIElement]
        else { return [] }
        return values
    }
}
