import AppKit
import CodexBarCore
import Foundation

@MainActor
final class AgentMicroAppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let scanner = LocalAgentSessionScanner(config: AgentMicroSessionPolicy.scannerConfiguration)
    private let taskStateEngine = CodexTaskStateEngine()
    private let settings = AgentMicroSettings()
    private let menu = NSMenu()
    private var statusItem: NSStatusItem?
    private var settingsWindowController: AgentMicroSettingsWindowController?
    private var tasks: [CodexTaskObservation] = []
    private var hasCompletedInitialScan = false
    private var refreshTask: Task<Void, Never>?
    private var pollingTask: Task<Void, Never>?

    func applicationDidFinishLaunching(_: Notification) {
        self.settings.onChange = { [weak self] in
            self?.updateStatusItem()
            self?.rebuildMenu()
        }
        self.configureStatusItem()
        self.rebuildMenu()
        self.startPolling()
        if CommandLine.arguments.contains("--show-settings") {
            self.showSettings()
        }
    }

    func applicationWillTerminate(_: Notification) {
        self.refreshTask?.cancel()
        self.pollingTask?.cancel()
    }

    func menuWillOpen(_: NSMenu) {
        self.refresh()
    }

    private func configureStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            let image = NSImage(
                systemSymbolName: "waveform.path.ecg",
                accessibilityDescription: "AgentMicro",
            )
            image?.isTemplate = true
            button.image = image
            button.imagePosition = .imageLeft
            button.toolTip = "AgentMicro"
            button.setAccessibilityLabel("AgentMicro Codex tasks")
        }
        self.menu.delegate = self
        item.menu = self.menu
        self.statusItem = item
        self.updateStatusItem()
    }

    private func startPolling() {
        guard self.pollingTask == nil else { return }
        self.pollingTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                self.refresh()
                let interval = AgentMicroRefreshPolicy.interval(
                    tasks: self.tasks,
                    isDesktopAppRunning: !NSRunningApplication.runningApplications(
                        withBundleIdentifier: "com.openai.codex"
                    ).isEmpty
                )
                try? await Task.sleep(for: interval)
            }
        }
    }

    private func refresh() {
        guard self.refreshTask == nil else { return }
        let scanner = self.scanner
        let taskStateEngine = self.taskStateEngine
        self.refreshTask = Task { @MainActor [weak self] in
            let scannedSessions = await scanner.scan()
            let tasks = await taskStateEngine.observe(
                sessions: scannedSessions.filter { $0.provider == .codex }
            )
            guard !Task.isCancelled, let self else { return }
            self.tasks = tasks
            self.hasCompletedInitialScan = true
            self.refreshTask = nil
            self.updateStatusItem()
            self.rebuildMenu()
        }
    }

    private func updateStatusItem() {
        let activeCount = self.tasks.count { $0.state.isWorking }
        self.statusItem?.button?.title = activeCount > 0 ? " \(activeCount)" : ""
        self.statusItem?.button?.toolTip = activeCount > 0
            ? "AgentMicro — \(activeCount) active Codex task\(activeCount == 1 ? "" : "s")"
            : "AgentMicro — no active Codex tasks"
    }

    private func rebuildMenu(now: Date = Date()) {
        self.menu.removeAllItems()

        let rows = AgentMicroMenuModel.rows(
            from: self.tasks,
            preferences: self.settings.preferences,
            now: now
        )
        let activeCount = rows.count(where: \.isActive)
        let headline = activeCount > 0
            ? "AgentMicro — \(activeCount) active"
            : "AgentMicro"
        let headlineItem = NSMenuItem(title: headline, action: nil, keyEquivalent: "")
        headlineItem.isEnabled = false
        self.menu.addItem(headlineItem)
        self.menu.addItem(.separator())
        self.addTaskRows(rows)
        self.addMenuFooter()
    }

    private func addTaskRows(_ rows: [AgentMicroMenuRow]) {
        if rows.isEmpty {
            let title = self.hasCompletedInitialScan ? "No Codex tasks found" : "Scanning for Codex tasks…"
            let emptyItem = NSMenuItem(title: title, action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            self.menu.addItem(emptyItem)
        } else {
            for row in rows {
                let item = NSMenuItem(
                    title: "\(row.symbol) \(row.title)",
                    action: #selector(self.focusSession(_:)),
                    keyEquivalent: "",
                )
                if #available(macOS 14.4, *) {
                    item.subtitle = row.subtitle
                } else {
                    item.title += " — \(row.subtitle)"
                }
                item.representedObject = row.sessionKey
                item.target = self
                self.menu.addItem(item)
            }
        }
    }

    private func addMenuFooter() {
        self.menu.addItem(.separator())
        let refreshItem = NSMenuItem(
            title: "Refresh",
            action: #selector(self.refreshFromMenu),
            keyEquivalent: "r",
        )
        refreshItem.target = self
        self.menu.addItem(refreshItem)

        let settingsItem = NSMenuItem(
            title: "Settings…",
            action: #selector(self.showSettings),
            keyEquivalent: ",",
        )
        settingsItem.target = self
        self.menu.addItem(settingsItem)

        let quitItem = NSMenuItem(
            title: "Quit AgentMicro",
            action: #selector(self.quit),
            keyEquivalent: "q",
        )
        quitItem.target = self
        self.menu.addItem(quitItem)
    }

    @objc
    private func focusSession(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String,
              let session = self.tasks.first(where: { $0.sessionKey == key })?.session
        else { return }
        _ = SessionWindowFocuser.focus(session, promptForAccessibility: false)
    }

    @objc
    private func refreshFromMenu() {
        self.refresh()
    }

    @objc
    private func showSettings() {
        self.settings.refreshLaunchAtLoginStatus()
        if self.settingsWindowController == nil {
            self.settingsWindowController = AgentMicroSettingsWindowController(settings: self.settings)
        }
        self.settingsWindowController?.present()
    }

    @objc
    private func quit() {
        NSApplication.shared.terminate(nil)
    }
}
