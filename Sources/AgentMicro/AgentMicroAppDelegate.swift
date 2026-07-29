import AppKit
import CodexBarCore
import Foundation

@MainActor
final class AgentMicroAppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let scanner = LocalAgentSessionScanner(config: AgentMicroSessionPolicy.scannerConfiguration)
    private let taskStateEngine = CodexTaskStateEngine()
    private let settings = AgentMicroSettings()
    private lazy var updater = AgentMicroUpdaterFactory.make(
        automaticallyChecksForUpdates: self.settings.autoUpdateEnabled)
    private let menu = NSMenu()
    private var statusItem: NSStatusItem?
    private var settingsWindowController: AgentMicroSettingsWindowController?
    private var tasks: [CodexTaskObservation] = []
    private var knownSessions: [AgentSession] = []
    private var viewedTurnTracker = AgentMicroViewedTurnTracker()
    private var hasCompletedInitialScan = false
    private var refreshTask: Task<Void, Never>?
    private var refreshRequestedWhileRunning = false
    private var reconciliationTask: Task<Void, Never>?
    private var reconciliationRequestedWhileRunning = false
    private var reconciliationBurstTask: Task<Void, Never>?
    private var pollingTask: Task<Void, Never>?
    private var statusAnimationTimer: Timer?
    private var menuDurationTimer: Timer?
    private var statusAnimationPhase = 0
    private var isMenuOpen = false
    private lazy var sessionChangeMonitor = CodexSessionChangeMonitor { [weak self] in
        self?.sessionFilesDidChange()
    }

    func applicationDidFinishLaunching(_: Notification) {
        self.settings.onChange = { [weak self] in
            guard let self else { return }
            self.updater.automaticallyChecksForUpdates = self.settings.autoUpdateEnabled
            self.updater.automaticallyDownloadsUpdates = self.settings.autoUpdateEnabled
            self.settingsWindowController?.refreshLocalization()
            self.updateStatusItem()
            self.rebuildMenu()
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
        self.reconciliationTask?.cancel()
        self.reconciliationBurstTask?.cancel()
        self.pollingTask?.cancel()
        self.statusAnimationTimer?.invalidate()
        self.menuDurationTimer?.invalidate()
        self.sessionChangeMonitor.stop()
    }

    func menuWillOpen(_: NSMenu) {
        self.isMenuOpen = true
        self.startMenuDurationTimerIfNeeded()
        self.reconcileKnownSessions()
        self.refresh()
        self.scheduleReconciliationBurst()
    }

    func menuDidClose(_: NSMenu) {
        self.isMenuOpen = false
        self.stopMenuDurationTimer()
    }

    private func configureStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.imagePosition = .imageOnly
            button.toolTip = "AgentMicro"
            button.setAccessibilityLabel(AgentMicroLocalization.text("accessibility.status"))
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
                        withBundleIdentifier: "com.openai.codex").isEmpty)
                try? await Task.sleep(for: interval)
            }
        }
    }

    private func refresh() {
        guard self.refreshTask == nil else {
            self.refreshRequestedWhileRunning = true
            return
        }
        let scanner = self.scanner
        let taskStateEngine = self.taskStateEngine
        self.refreshTask = Task { @MainActor [weak self] in
            let scannedSessions = await scanner.scan()
            let codexSessions = scannedSessions.filter { $0.provider == .codex }
            let tasks = await taskStateEngine.observe(
                sessions: codexSessions)
            guard !Task.isCancelled, let self else { return }
            self.sessionChangeMonitor.update(
                transcriptPaths: scannedSessions.compactMap(\.transcriptPath))
            self.knownSessions = codexSessions
            self.hasCompletedInitialScan = true
            self.refreshTask = nil
            self.applyTasks(tasks)
            if self.refreshRequestedWhileRunning {
                self.refreshRequestedWhileRunning = false
                self.refresh()
            }
        }
    }

    private func updateStatusItem() {
        let rows = AgentMicroMenuModel.rows(
            from: self.tasks,
            preferences: self.settings.preferences,
            readSessionKeys: self.settings.readSessionKeys(for: self.tasks))
        let activeCount = rows.count(where: \.isActive)
        let shouldAnimate = activeCount > 0 &&
            !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        self.setStatusAnimationEnabled(shouldAnimate)
        self.drawStatusItemImage(rows: rows)
        self.statusItem?.button?.title = ""
        self.statusItem?.button?.toolTip = if rows.isEmpty {
            AgentMicroLocalization.text("status.tooltip.none")
        } else if activeCount > 0 {
            AgentMicroLocalization.text(
                "status.tooltip.active",
                arguments: activeCount,
                rows.count)
        } else if rows.count == 1 {
            AgentMicroLocalization.text("status.tooltip.recent.one", arguments: rows.count)
        } else {
            AgentMicroLocalization.text("status.tooltip.recent.other", arguments: rows.count)
        }
    }

    private func rebuildMenu(now: Date = Date()) {
        self.menu.removeAllItems()

        let rows = AgentMicroMenuModel.rows(
            from: self.tasks,
            preferences: self.settings.preferences,
            readSessionKeys: self.settings.readSessionKeys(for: self.tasks),
            now: now)
        let activeCount = rows.count(where: \.isActive)
        let headline = activeCount > 0
            ? AgentMicroLocalization.text("menu.headline.active", arguments: activeCount)
            : "AgentMicro"
        let headlineItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        headlineItem.isEnabled = false
        headlineItem.view = AgentMicroMenuHeaderView(title: headline)
        self.menu.addItem(headlineItem)
        self.menu.addItem(.separator())
        self.addTaskRows(rows)
        self.addMenuFooter()
    }

    private func addTaskRows(_ rows: [AgentMicroMenuRow]) {
        if rows.isEmpty {
            let title = self.hasCompletedInitialScan
                ? AgentMicroLocalization.text("menu.empty")
                : AgentMicroLocalization.text("menu.scanning")
            let emptyItem = NSMenuItem(title: title, action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            self.menu.addItem(emptyItem)
        } else {
            for row in rows {
                let item = NSMenuItem(title: "", action: nil, keyEquivalent: "")
                item.view = AgentMicroTaskMenuItemView(row: row) { [weak self] in
                    self?.focusSession(sessionKey: row.sessionKey)
                }
                self.menu.addItem(item)
            }
        }
    }

    private func setStatusAnimationEnabled(_ enabled: Bool) {
        if enabled {
            guard self.statusAnimationTimer == nil else { return }
            let timer = Timer(
                timeInterval: AgentMicroStatusIcon.animationFrameInterval,
                target: self,
                selector: #selector(self.advanceStatusAnimation),
                userInfo: nil,
                repeats: true)
            RunLoop.main.add(timer, forMode: .common)
            self.statusAnimationTimer = timer
            return
        }

        self.statusAnimationTimer?.invalidate()
        self.statusAnimationTimer = nil
        self.statusAnimationPhase = 0
    }

    private func drawStatusItemImage(rows: [AgentMicroMenuRow]? = nil) {
        let currentRows = rows ?? AgentMicroMenuModel.rows(
            from: self.tasks,
            preferences: self.settings.preferences,
            readSessionKeys: self.settings.readSessionKeys(for: self.tasks))
        self.statusItem?.button?.image = AgentMicroStatusIcon.statusItemImage(
            states: currentRows.map(\.state),
            animationPhase: self.statusAnimationTimer == nil ? nil : self.statusAnimationPhase)
    }

    @objc
    private func advanceStatusAnimation() {
        self.statusAnimationPhase = (self.statusAnimationPhase + 1) %
            AgentMicroStatusIcon.animationFrameCount
        self.drawStatusItemImage()
    }

    private func addMenuFooter() {
        self.menu.addItem(.separator())
        let refreshItem = NSMenuItem(
            title: AgentMicroLocalization.text("menu.footer.refresh"),
            action: #selector(self.refreshFromMenu),
            keyEquivalent: "r")
        refreshItem.target = self
        self.menu.addItem(refreshItem)

        let settingsItem = NSMenuItem(
            title: AgentMicroLocalization.text("menu.footer.settings"),
            action: #selector(self.showSettings),
            keyEquivalent: ",")
        settingsItem.target = self
        self.menu.addItem(settingsItem)

        if self.updater.isAvailable {
            let updateItem = NSMenuItem(
                title: AgentMicroLocalization.text("updates.check"),
                action: #selector(self.checkForUpdates),
                keyEquivalent: "")
            updateItem.target = self
            self.menu.addItem(updateItem)
        }

        let quitItem = NSMenuItem(
            title: AgentMicroLocalization.text("menu.footer.quit"),
            action: #selector(self.quit),
            keyEquivalent: "q")
        quitItem.target = self
        self.menu.addItem(quitItem)
    }

    private func focusSession(sessionKey: String) {
        guard let task = self.tasks.first(where: { $0.sessionKey == sessionKey }) else { return }
        self.viewedTurnTracker.noteViewing(task)
        self.settings.markSessionRead(task)
        _ = SessionWindowFocuser.focus(task.session, promptForAccessibility: false)
        self.reconcileKnownSessions()
        self.scheduleReconciliationBurst()
    }

    @objc
    private func refreshFromMenu() {
        self.reconcileKnownSessions()
        self.refresh()
        self.scheduleReconciliationBurst()
    }

    @objc
    private func showSettings() {
        self.settings.refreshLaunchAtLoginStatus()
        if self.settingsWindowController == nil {
            self.settingsWindowController = AgentMicroSettingsWindowController(
                settings: self.settings,
                updater: self.updater)
        }
        self.settingsWindowController?.present()
    }

    @objc
    private func quit() {
        NSApplication.shared.terminate(nil)
    }

    @objc
    private func checkForUpdates() {
        self.updater.checkForUpdates(nil)
    }
}

extension AgentMicroAppDelegate {
    private func startMenuDurationTimerIfNeeded() {
        guard self.menuDurationTimer == nil,
              self.tasks.contains(where: \.state.isWorking)
        else { return }
        let timer = Timer(
            timeInterval: AgentMicroMenuModel.durationUpdateInterval,
            target: self,
            selector: #selector(self.updateVisibleMenuDurations),
            userInfo: nil,
            repeats: true)
        RunLoop.main.add(timer, forMode: .common)
        self.menuDurationTimer = timer
    }

    private func stopMenuDurationTimer() {
        self.menuDurationTimer?.invalidate()
        self.menuDurationTimer = nil
    }

    @objc
    private func updateVisibleMenuDurations() {
        let rows = AgentMicroMenuModel.rows(
            from: self.tasks,
            preferences: self.settings.preferences,
            readSessionKeys: self.settings.readSessionKeys(for: self.tasks))
        let rowsBySessionKey = Dictionary(uniqueKeysWithValues: rows.map { ($0.sessionKey, $0) })
        for case let view as AgentMicroTaskMenuItemView in self.menu.items.compactMap(\.view) {
            guard let row = rowsBySessionKey[view.sessionKey] else { continue }
            view.updateDuration(row.duration)
        }
    }

    private func reconcileKnownSessions() {
        guard !self.knownSessions.isEmpty else {
            self.refresh()
            return
        }
        guard self.reconciliationTask == nil else {
            self.reconciliationRequestedWhileRunning = true
            return
        }
        let sessions = self.knownSessions
        let taskStateEngine = self.taskStateEngine
        self.reconciliationTask = Task { @MainActor [weak self] in
            let tasks = await taskStateEngine.observe(sessions: sessions)
            guard !Task.isCancelled, let self else { return }
            self.reconciliationTask = nil
            self.applyTasks(tasks)
            if self.reconciliationRequestedWhileRunning {
                self.reconciliationRequestedWhileRunning = false
                self.reconcileKnownSessions()
            }
        }
    }

    private func applyTasks(_ tasks: [CodexTaskObservation], now: Date = Date()) {
        let completedViewedTasks = self.viewedTurnTracker.completedTasksToMarkRead(
            in: tasks,
            now: now)
        for task in completedViewedTasks {
            self.settings.markSessionRead(task, now: task.lastEventAt ?? now, notifyChange: false)
        }
        self.tasks = tasks
        self.updateStatusItem()
        self.rebuildMenu(now: now)
        if self.isMenuOpen, tasks.contains(where: \.state.isWorking) {
            self.startMenuDurationTimerIfNeeded()
        } else {
            self.stopMenuDurationTimer()
        }
    }

    private func sessionFilesDidChange() {
        self.reconcileKnownSessions()
        self.refresh()
        self.scheduleReconciliationBurst()
    }

    private func scheduleReconciliationBurst() {
        self.reconciliationBurstTask?.cancel()
        self.reconciliationBurstTask = Task { @MainActor [weak self] in
            for delay in AgentMicroRefreshPolicy.reconciliationDelays {
                try? await Task.sleep(for: delay)
                guard !Task.isCancelled, let self else { return }
                self.reconcileKnownSessions()
            }
            self?.reconciliationBurstTask = nil
        }
    }
}
