import AppKit
import CodexBarCore
import Foundation

@MainActor
final class AgentMicroAppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private struct MenuContentFingerprint: Equatable {
        let sessionKey: String
        let title: String
        let subtitle: String
        let state: CodexTaskState
        let usesFastModel: Bool
    }

    private let codexDataAccess = AgentMicroCodexDataAccess()
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
    private let enhancedStatusReader = CodexEnhancedStatusReader()
    private var enhancedStatusTracker = CodexEnhancedStatusTracker()
    private lazy var codexUnreadThreadStateReader = CodexUnreadThreadStateReader(
        environment: self.codexDataAccess.scanEnvironment)
    private var hasCompletedInitialScan = false
    private var refreshTask: Task<Void, Never>?
    private var refreshRequestedWhileRunning = false
    private var reconciliationTask: Task<Void, Never>?
    private var reconciliationRequestedWhileRunning = false
    private var reconciliationBurstTask: Task<Void, Never>?
    private var discoveryRefreshTask: Task<Void, Never>?
    private var pollingTask: Task<Void, Never>?
    private var usageRefreshTask: Task<Void, Never>?
    private let taskCPUSampler = AgentMicroTaskCPUSampler()
    private var taskCPURefreshTask: Task<Void, Never>?
    private var cpuPercentBySessionKey: [String: Double] = [:]
    private let conversationSearchIndex = AgentMicroConversationSearchIndex()
    private var conversationSearchTask: Task<Void, Never>?
    private var usageSnapshot: UsageSnapshot?
    private var usageLastAttemptAt: Date?
    private var statusAnimationTimer: Timer?
    private var menuDurationTimer: Timer?
    private var menuOutsideClickMonitor: Any?
    private var applicationResignObserver: NSObjectProtocol?
    private var statusAnimationPhase = 0
    private var statusAnimationStates: [CodexTaskState] = []
    private var statusAnimationFrames: [NSImage] = []
    private var renderedStatusTooltip: String?
    private var renderedMenuFingerprint: [MenuContentFingerprint]?
    private var renderedMenuWasInitialScanComplete: Bool?
    private var isMenuOpen = false
    private var isSearchActive = false
    private var searchQuery = ""
    private var contentMatchingSessionKeys: Set<String> = []
    private lazy var sessionChangeMonitor = CodexSessionChangeMonitor { [weak self] requiresDiscovery in
        self?.sessionFilesDidChange(requiresDiscovery: requiresDiscovery)
    }

    func applicationDidFinishLaunching(_: Notification) {
        self.settings.onChange = { [weak self] in
            guard let self else { return }
            self.updater.automaticallyChecksForUpdates = self.settings.autoUpdateEnabled
            self.updater.automaticallyDownloadsUpdates = self.settings.autoUpdateEnabled
            self.settingsWindowController?.refreshLocalization()
            self.reconcileKnownSessions()
            self.updateStatusItem()
            self.rebuildMenu(force: true)
            self.reconcileTaskCPUObservation()
        }
        self.configureStatusItem()
        self.rebuildMenu()
        self.startPolling()
        self.refreshUsageIfNeeded()
        if self.codexDataAccess.requiresSelection {
            self.presentSettings(pane: .general)
            Task { @MainActor [weak self] in
                await Task.yield()
                self?.chooseCodexDataDirectory()
            }
        } else if CommandLine.arguments.contains("--show-settings") {
            self.showSettings()
        } else if self.settings.shouldPresentGuideOnLaunch {
            self.settings.markGuidePresented()
            self.presentSettings(pane: .guide)
        }
    }

    func applicationWillTerminate(_: Notification) {
        self.refreshTask?.cancel()
        self.reconciliationTask?.cancel()
        self.reconciliationBurstTask?.cancel()
        self.discoveryRefreshTask?.cancel()
        self.pollingTask?.cancel()
        self.usageRefreshTask?.cancel()
        self.taskCPURefreshTask?.cancel()
        self.conversationSearchTask?.cancel()
        self.statusAnimationTimer?.invalidate()
        self.menuDurationTimer?.invalidate()
        self.stopMenuDismissalMonitoring()
        self.sessionChangeMonitor.stop()
    }

    func menuWillOpen(_: NSMenu) {
        self.isMenuOpen = true
        self.rebuildMenu(force: true)
        self.startMenuDismissalMonitoring()
        self.startMenuDurationTimerIfNeeded()
        self.reconcileTaskCPUObservation()
        self.reconcileKnownSessions()
        self.refresh()
        self.refreshUsageIfNeeded()
        self.scheduleReconciliationBurst()
    }

    func menuDidClose(_: NSMenu) {
        self.isMenuOpen = false
        self.endSearch()
        self.stopMenuDismissalMonitoring()
        self.stopMenuDurationTimer()
        self.stopTaskCPUObservation()
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

    private func startMenuDismissalMonitoring() {
        self.stopMenuDismissalMonitoring()
        self.menuOutsideClickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown])
        { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.isMenuOpen, !self.isSearchActive else { return }
                self.menu.cancelTracking()
            }
        }
        self.applicationResignObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: NSApplication.shared,
            queue: .main)
        { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.isMenuOpen, !self.isSearchActive else { return }
                self.menu.cancelTracking()
            }
        }
    }

    private func stopMenuDismissalMonitoring() {
        if let menuOutsideClickMonitor {
            NSEvent.removeMonitor(menuOutsideClickMonitor)
            self.menuOutsideClickMonitor = nil
        }
        if let applicationResignObserver {
            NotificationCenter.default.removeObserver(applicationResignObserver)
            self.applicationResignObserver = nil
        }
    }

    private func startPolling() {
        guard self.pollingTask == nil else { return }
        self.pollingTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                self.refresh(trigger: .polling)
                let interval = AgentMicroRefreshPolicy.interval(
                    tasks: self.tasks,
                    isDesktopAppRunning: !NSRunningApplication.runningApplications(
                        withBundleIdentifier: "com.openai.codex").isEmpty)
                try? await Task.sleep(for: interval)
            }
        }
    }

    private func refresh(trigger: AgentMicroRefreshTrigger = .event) {
        guard !self.codexDataAccess.requiresSelection else {
            self.hasCompletedInitialScan = true
            self.rebuildMenu()
            return
        }
        guard self.refreshTask == nil else {
            if AgentMicroRefreshPolicy.shouldQueueFollowUp(
                whileRefreshIsRunning: true,
                trigger: trigger)
            {
                self.refreshRequestedWhileRunning = true
            }
            return
        }
        let scanner = self.scanner
        let taskStateEngine = self.taskStateEngine
        let environment = self.codexDataAccess.scanEnvironment
        self.refreshTask = Task { @MainActor [weak self] in
            let scannedSessions = await scanner.scan(
                environment: environment,
                includeProcessSessions: !AgentMicroDistribution.isAppStore)
            let codexSessions = scannedSessions.filter { $0.provider == .codex }
            let tasks = await taskStateEngine.observe(
                sessions: codexSessions)
            guard !Task.isCancelled, let self else { return }
            self.sessionChangeMonitor.update(
                transcriptPaths: scannedSessions.compactMap(\.transcriptPath),
                environment: environment)
            self.knownSessions = codexSessions
            self.hasCompletedInitialScan = true
            self.refreshTask = nil
            self.applyTasks(tasks)
            if self.refreshRequestedWhileRunning {
                self.refreshRequestedWhileRunning = false
                self.refresh(trigger: .event)
            }
        }
    }

    private func updateStatusItem() {
        let rows = AgentMicroMenuModel.rows(
            from: self.tasks,
            preferences: self.settings.preferences,
            readSessionKeys: self.effectiveReadSessionKeys(for: self.tasks))
        let activeCount = rows.count(where: \.isActive)
        let states = rows.map(\.state)
        let hasAnimatedSlot = !AgentMicroStatusIcon.animatedSlotIndices(for: states).isEmpty
        let shouldAnimate = hasAnimatedSlot &&
            !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let tooltip = if rows.isEmpty {
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
        let needsAnimationFrames = states != self.statusAnimationStates
            || self.statusAnimationFrames.isEmpty
            || shouldAnimate != (self.statusAnimationFrames.count > 1)
            || tooltip != self.renderedStatusTooltip
        guard needsAnimationFrames else { return }
        self.renderedStatusTooltip = tooltip
        self.statusAnimationStates = states
        self.statusAnimationPhase = 0
        self.statusAnimationFrames = AgentMicroStatusIcon.statusItemImages(
            states: states,
            animated: shouldAnimate)
        self.setStatusAnimationEnabled(shouldAnimate)
        self.drawStatusItemImage()
        self.statusItem?.button?.title = ""
        self.statusItem?.button?.toolTip = tooltip
    }

    private func rebuildMenu(
        now: Date = Date(),
        force: Bool = false,
        preservingSearchHeader: Bool = false)
    {
        let rows = AgentMicroMenuModel.rows(
            from: self.tasks,
            preferences: self.settings.preferences,
            readSessionKeys: self.effectiveReadSessionKeys(for: self.tasks, now: now),
            searchQuery: self.isSearchActive ? self.searchQuery : nil,
            contentMatchingSessionKeys: self.contentMatchingSessionKeys,
            cpuPercentBySessionKey: self.cpuPercentBySessionKey,
            now: now)
        let fingerprint = rows.map {
            MenuContentFingerprint(
                sessionKey: $0.sessionKey,
                title: $0.title,
                subtitle: $0.subtitle,
                state: $0.state,
                usesFastModel: $0.usesFastModel)
        }
        guard force
            || fingerprint != self.renderedMenuFingerprint
            || self.renderedMenuWasInitialScanComplete != self.hasCompletedInitialScan
        else { return }
        self.renderedMenuFingerprint = fingerprint
        self.renderedMenuWasInitialScanComplete = self.hasCompletedInitialScan
        if preservingSearchHeader || self.isSearchActive,
           self.isSearchActive,
           self.menu.items.count >= 2,
           self.menu.items[0].view is AgentMicroMenuHeaderView
        {
            while self.menu.items.count > 2 {
                self.menu.removeItem(at: self.menu.items.count - 1)
            }
            self.addTaskRows(rows)
            self.addUsageSection()
            self.addMenuFooter()
            return
        }
        self.menu.removeAllItems()

        let activeCount = rows.count(where: \.isActive)
        let headline = activeCount > 0
            ? AgentMicroLocalization.text("menu.headline.active", arguments: activeCount)
            : "AgentMicro"
        let headlineItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        headlineItem.isEnabled = true
        headlineItem.view = AgentMicroMenuHeaderView(
            title: headline,
            isSearching: self.isSearchActive,
            searchQuery: self.searchQuery,
            onBeginSearch: { [weak self] in
                guard let self else { return }
                self.isSearchActive = true
                self.updateSearchResults(resetContentMatches: true, debounce: false)
            },
            onSearchQueryChange: { [weak self] query in
                guard let self else { return }
                guard query != self.searchQuery else { return }
                self.searchQuery = query
                self.updateSearchResults()
            },
            onEndSearch: { [weak self] in
                self?.endSearch(rebuildMenu: true)
            })
        self.menu.addItem(headlineItem)
        self.menu.addItem(.separator())
        self.addTaskRows(rows)
        self.addUsageSection()
        self.addMenuFooter()
    }

    private func addTaskRows(_ rows: [AgentMicroMenuRow]) {
        if rows.isEmpty {
            let title = if self.isSearchActive, !self.searchQuery.isEmpty {
                AgentMicroLocalization.text("menu.search.noResults")
            } else if self.hasCompletedInitialScan {
                AgentMicroLocalization.text("menu.empty")
            } else {
                AgentMicroLocalization.text("menu.scanning")
            }
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
            timer.tolerance = AgentMicroStatusIcon.animationTimerTolerance
            RunLoop.main.add(timer, forMode: .common)
            self.statusAnimationTimer = timer
            return
        }

        self.statusAnimationTimer?.invalidate()
        self.statusAnimationTimer = nil
        self.statusAnimationPhase = 0
    }

    private func drawStatusItemImage() {
        guard !self.statusAnimationFrames.isEmpty else { return }
        let frameIndex = self.statusAnimationTimer == nil
            ? 0
            : self.statusAnimationPhase % self.statusAnimationFrames.count
        self.statusItem?.button?.image = self.statusAnimationFrames[frameIndex]
    }

    @objc
    private func advanceStatusAnimation() {
        guard !self.statusAnimationFrames.isEmpty else { return }
        self.statusAnimationPhase = (self.statusAnimationPhase + 1) %
            self.statusAnimationFrames.count
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
        let focusResult = SessionWindowFocuser.focus(task.session, promptForAccessibility: false)
        if AgentMicroReadStateResolver.focusResultConfirmsView(
            focusResult,
            source: task.session.source)
        {
            self.viewedTurnTracker.noteViewing(task)
            self.settings.markSessionRead(task)
        }
        self.reconcileKnownSessions()
        self.scheduleReconciliationBurst()
    }

    private func updateSearchResults(
        resetContentMatches: Bool = true,
        debounce: Bool = true)
    {
        self.conversationSearchTask?.cancel()
        if resetContentMatches {
            self.contentMatchingSessionKeys = []
        }
        self.rebuildMenu(preservingSearchHeader: true)
        let query = self.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard self.isSearchActive, !query.isEmpty else { return }
        let tasks = self.tasks
        let index = self.conversationSearchIndex
        self.conversationSearchTask = Task { @MainActor [weak self] in
            if debounce {
                try? await Task.sleep(for: .milliseconds(120))
                guard !Task.isCancelled else { return }
            }
            let matches = await index.matchingSessionKeys(in: tasks, query: query)
            guard !Task.isCancelled,
                  let self,
                  self.isSearchActive,
                  self.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines) == query
            else { return }
            guard matches != self.contentMatchingSessionKeys else {
                self.conversationSearchTask = nil
                return
            }
            self.contentMatchingSessionKeys = matches
            self.conversationSearchTask = nil
            self.rebuildMenu(preservingSearchHeader: true)
        }
    }

    private func endSearch(rebuildMenu: Bool = false) {
        self.conversationSearchTask?.cancel()
        self.conversationSearchTask = nil
        self.isSearchActive = false
        self.searchQuery = ""
        self.contentMatchingSessionKeys = []
        if rebuildMenu {
            self.rebuildMenu(force: true)
        }
    }

    private func reconcileTaskCPUObservation() {
        guard self.isMenuOpen,
              self.settings.showTaskCPU,
              !AgentMicroDistribution.isAppStore
        else {
            self.stopTaskCPUObservation()
            return
        }
        guard self.taskCPURefreshTask == nil else { return }
        let sampler = self.taskCPUSampler
        self.taskCPURefreshTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                guard let self, self.isMenuOpen, self.settings.showTaskCPU else { break }
                let readings = await sampler.sample(tasks: self.tasks)
                guard !Task.isCancelled else { break }
                self.cpuPercentBySessionKey = readings
                self.updateVisibleTaskCPU()
                try? await Task.sleep(for: AgentMicroTaskCPUSampler.refreshInterval)
            }
        }
    }

    private func stopTaskCPUObservation() {
        self.taskCPURefreshTask?.cancel()
        self.taskCPURefreshTask = nil
        self.cpuPercentBySessionKey = [:]
        let sampler = self.taskCPUSampler
        Task { await sampler.reset() }
    }

    private func updateVisibleTaskCPU() {
        let rows = AgentMicroMenuModel.rows(
            from: self.tasks,
            preferences: self.settings.preferences,
            readSessionKeys: self.effectiveReadSessionKeys(for: self.tasks),
            searchQuery: self.isSearchActive ? self.searchQuery : nil,
            contentMatchingSessionKeys: self.contentMatchingSessionKeys,
            cpuPercentBySessionKey: self.cpuPercentBySessionKey)
        let rowsBySessionKey = Dictionary(uniqueKeysWithValues: rows.map { ($0.sessionKey, $0) })
        for case let view as AgentMicroTaskMenuItemView in self.menu.items.compactMap(\.view) {
            view.updateCPU(rowsBySessionKey[view.sessionKey]?.cpuLabel)
        }
    }

    @objc
    private func refreshFromMenu() {
        self.reconcileKnownSessions()
        self.refresh()
        self.refreshUsageIfNeeded(force: true)
        self.scheduleReconciliationBurst()
    }

    private func addUsageSection() {
        #if !ENABLE_AGENTMICRO_APP_STORE
        self.menu.addItem(.separator())
        let state = AgentMicroUsageModel.state(
            snapshot: self.usageSnapshot,
            isLoading: self.usageRefreshTask != nil)
        let item = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        item.isEnabled = false
        item.view = AgentMicroUsageMenuItemView(state: state)
        self.menu.addItem(item)
        #endif
    }

    private func refreshUsageIfNeeded(force: Bool = false, now: Date = Date()) {
        #if !ENABLE_AGENTMICRO_APP_STORE
        guard self.usageRefreshTask == nil else { return }
        guard force || AgentMicroUsageModel.shouldRefresh(lastAttemptAt: self.usageLastAttemptAt, now: now) else {
            return
        }
        self.usageLastAttemptAt = now
        self.usageRefreshTask = Task { @MainActor [weak self] in
            let snapshot = try? await UsageFetcher().loadLatestUsage()
            guard !Task.isCancelled, let self else { return }
            self.usageSnapshot = snapshot
            self.usageRefreshTask = nil
            self.rebuildMenu(force: true)
        }
        self.rebuildMenu(force: true)
        #endif
    }

    @objc
    private func showSettings() {
        self.presentSettings()
    }

    private func presentSettings(pane: AgentMicroSettingsPane? = nil) {
        self.settings.refreshLaunchAtLoginStatus()
        if self.settingsWindowController == nil {
            self.settingsWindowController = AgentMicroSettingsWindowController(
                settings: self.settings,
                updater: self.updater,
                codexDataAccess: self.codexDataAccess,
                onCodexDataAccessChanged: { [weak self] in
                    self?.codexDataAccessDidChange()
                })
        }
        self.settingsWindowController?.present(pane: pane)
    }

    @objc
    private func quit() {
        NSApplication.shared.terminate(nil)
    }

    @objc
    private func checkForUpdates() {
        self.updater.checkForUpdates(nil)
    }

    private func chooseCodexDataDirectory() {
        guard self.codexDataAccess.chooseDirectory() else { return }
        self.codexDataAccessDidChange()
    }

    private func codexDataAccessDidChange() {
        self.codexUnreadThreadStateReader = CodexUnreadThreadStateReader(
            environment: self.codexDataAccess.scanEnvironment)
        self.hasCompletedInitialScan = false
        self.knownSessions = []
        self.tasks = []
        self.refresh()
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
            readSessionKeys: self.effectiveReadSessionKeys(for: self.tasks))
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
        let enhancedSnapshot: CodexEnhancedStatusSnapshot? = if self.settings
            .enhancedStatusDetection,
            AgentMicroAccessibilityAccess.isTrusted
        {
            self.enhancedStatusReader.snapshot(for: tasks, now: now)
        } else {
            nil
        }
        if !self.settings.enhancedStatusDetection ||
            !AgentMicroAccessibilityAccess.isTrusted
        {
            self.enhancedStatusTracker.reset()
            self.enhancedStatusReader.resetCache()
        }
        if let selectedSessionKey = enhancedSnapshot?.selectedSessionKey,
           let selectedTask = tasks.first(where: { $0.sessionKey == selectedSessionKey })
        {
            self.viewedTurnTracker.noteViewing(selectedTask, now: now)
            if selectedTask.state == .unread {
                self.settings.markSessionRead(
                    selectedTask,
                    now: selectedTask.lastEventAt ?? now,
                    notifyChange: false)
            }
        }
        let effectiveTasks = self.enhancedStatusTracker.apply(
            snapshot: enhancedSnapshot,
            to: tasks)
        let completedViewedTasks = self.viewedTurnTracker.completedTasksToMarkRead(
            in: effectiveTasks,
            now: now)
        for task in completedViewedTasks {
            self.settings.markSessionRead(task, now: task.lastEventAt ?? now, notifyChange: false)
        }
        self.tasks = effectiveTasks
        self.updateStatusItem()
        if self.isSearchActive {
            self.rebuildMenu(now: now, preservingSearchHeader: true)
        } else {
            self.rebuildMenu(now: now)
        }
        if self.isMenuOpen, effectiveTasks.contains(where: \.state.isWorking) {
            self.startMenuDurationTimerIfNeeded()
        } else {
            self.stopMenuDurationTimer()
        }
    }

    private func effectiveReadSessionKeys(
        for tasks: [CodexTaskObservation],
        now: Date = Date()) -> Set<String>
    {
        AgentMicroReadStateResolver.readSessionKeys(
            for: tasks,
            locallyReadSessionKeys: self.settings.readSessionKeys(for: tasks),
            codexUnreadSnapshot: self.codexUnreadThreadStateReader.snapshot(),
            now: now)
    }

    private func sessionFilesDidChange(requiresDiscovery: Bool) {
        self.reconcileKnownSessions()
        self.scheduleReconciliationBurst()
        guard requiresDiscovery, self.discoveryRefreshTask == nil else { return }
        self.discoveryRefreshTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: AgentMicroRefreshPolicy.discoveryEventDelay)
            guard !Task.isCancelled, let self else { return }
            self.discoveryRefreshTask = nil
            self.refresh(trigger: .event)
        }
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
