import AppKit
import Foundation
import Observation

enum AgentMicroDistribution {
    static let isAppStore = {
        #if ENABLE_AGENTMICRO_APP_STORE
        true
        #else
        false
        #endif
    }()
}

@MainActor
@Observable
final class AgentMicroCodexDataAccess {
    private enum Key {
        static let bookmark = "agentMicro.codexHomeBookmark"
    }

    private(set) var directoryURL: URL?
    private(set) var lastError: String?

    @ObservationIgnored
    private let defaults: UserDefaults

    @ObservationIgnored
    private var isAccessingSecurityScopedResource = false

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.restoreAccess()
    }

    var requiresSelection: Bool {
        AgentMicroDistribution.isAppStore && self.directoryURL == nil
    }

    var displayPath: String? {
        self.directoryURL?.path(percentEncoded: false)
    }

    var scanEnvironment: [String: String] {
        var environment = ProcessInfo.processInfo.environment
        if let directoryURL {
            environment["CODEX_HOME"] = directoryURL.path(percentEncoded: false)
        }
        return environment
    }

    @discardableResult
    func chooseDirectory() -> Bool {
        #if ENABLE_AGENTMICRO_APP_STORE
        let panel = NSOpenPanel()
        panel.title = AgentMicroLocalization.text("settings.codexData.choose")
        panel.message = AgentMicroLocalization.text("settings.codexData.panelMessage")
        panel.prompt = AgentMicroLocalization.text("settings.codexData.authorize")
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = false
        panel.allowsMultipleSelection = false
        panel.showsHiddenFiles = true
        panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser
        guard panel.runModal() == .OK, let selectedURL = panel.url else { return false }
        return self.persistAccess(to: selectedURL)
        #else
        return false
        #endif
    }

    private func restoreAccess() {
        #if ENABLE_AGENTMICRO_APP_STORE
        guard let bookmarkData = self.defaults.data(forKey: Key.bookmark) else { return }
        do {
            var isStale = false
            let url = try URL(
                resolvingBookmarkData: bookmarkData,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale)
            guard url.startAccessingSecurityScopedResource() else {
                self.lastError = AgentMicroLocalization.text("settings.codexData.accessFailed")
                return
            }
            self.directoryURL = url
            self.isAccessingSecurityScopedResource = true
            if isStale {
                _ = self.persistBookmark(for: url)
            }
        } catch {
            self.lastError = error.localizedDescription
        }
        #endif
    }

    private func persistAccess(to url: URL) -> Bool {
        let standardizedURL = url.standardizedFileURL
        guard self.looksLikeCodexHome(standardizedURL) else {
            self.lastError = AgentMicroLocalization.text("settings.codexData.invalidFolder")
            return false
        }
        guard self.persistBookmark(for: standardizedURL) else { return false }
        if self.isAccessingSecurityScopedResource {
            self.directoryURL?.stopAccessingSecurityScopedResource()
        }
        self.isAccessingSecurityScopedResource = standardizedURL.startAccessingSecurityScopedResource()
        guard self.isAccessingSecurityScopedResource else {
            self.directoryURL = nil
            self.lastError = AgentMicroLocalization.text("settings.codexData.accessFailed")
            return false
        }
        self.directoryURL = standardizedURL
        self.lastError = nil
        return true
    }

    private func persistBookmark(for url: URL) -> Bool {
        do {
            let bookmarkData = try url.bookmarkData(
                options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
                includingResourceValuesForKeys: nil,
                relativeTo: nil)
            self.defaults.set(bookmarkData, forKey: Key.bookmark)
            return true
        } catch {
            self.lastError = error.localizedDescription
            return false
        }
    }

    private func looksLikeCodexHome(_ url: URL) -> Bool {
        let fileManager = FileManager.default
        return fileManager.fileExists(atPath: url.appendingPathComponent("sessions").path) ||
            fileManager.fileExists(atPath: url.appendingPathComponent("state_5.sqlite").path) ||
            fileManager.fileExists(atPath: url.appendingPathComponent(".codex-global-state.json").path)
    }
}
