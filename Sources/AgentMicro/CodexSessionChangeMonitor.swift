import CodexBarCore
import Darwin
import Dispatch
import Foundation

enum CodexSessionWatchPaths {
    static func globalStateFileURL(
        environment: [String: String] = ProcessInfo.processInfo.environment) -> URL
    {
        let homeDirectory = URL(
            fileURLWithPath: environment["HOME"] ?? NSHomeDirectory(),
            isDirectory: true)
        let codexHomeDirectory = URL(
            fileURLWithPath: environment["CODEX_HOME"] ??
                homeDirectory.appendingPathComponent(".codex", isDirectory: true).path,
            isDirectory: true)
        return codexHomeDirectory.appendingPathComponent(".codex-global-state.json")
    }

    static func existingPaths(
        transcriptPaths: [String],
        now: Date = Date(),
        environment: [String: String] = ProcessInfo.processInfo.environment,
        fileManager: FileManager = .default) -> Set<String>
    {
        let globalStateFile = self.globalStateFileURL(environment: environment)
        let codexHomeDirectory = globalStateFile.deletingLastPathComponent()
        let sessionsDirectory = codexHomeDirectory.appendingPathComponent("sessions", isDirectory: true)

        var candidates = Set(transcriptPaths)
        candidates.insert(sessionsDirectory.path)
        candidates.insert(globalStateFile.path)
        let databaseURL = CodexThreadMetadataReader(
            codexHomeDirectory: codexHomeDirectory,
            environment: environment).databaseURL
        candidates.formUnion([
            databaseURL.path,
            databaseURL.path + "-shm",
            databaseURL.path + "-wal",
        ])

        let calendar = Calendar(identifier: .gregorian)
        let days = [now, calendar.date(byAdding: .day, value: -1, to: now)].compactMap(\.self)
        for day in days {
            let components = calendar.dateComponents([.year, .month, .day], from: day)
            guard let year = components.year, let month = components.month, let day = components.day else {
                continue
            }
            let yearDirectory = sessionsDirectory.appendingPathComponent(String(format: "%04d", year))
            let monthDirectory = yearDirectory.appendingPathComponent(String(format: "%02d", month))
            let dayDirectory = monthDirectory.appendingPathComponent(String(format: "%02d", day))
            candidates.formUnion([yearDirectory.path, monthDirectory.path, dayDirectory.path])
        }

        return Set(candidates.filter { fileManager.fileExists(atPath: $0) })
    }

    static func requiresDiscovery(
        for path: String,
        transcriptPaths: [String],
        environment: [String: String] = ProcessInfo.processInfo.environment) -> Bool
    {
        path != self.globalStateFileURL(environment: environment).path &&
            !transcriptPaths.contains(path)
    }
}

@MainActor
final class CodexSessionChangeMonitor {
    private let onChange: @MainActor (_ requiresDiscovery: Bool) -> Void
    private var sources: [String: DispatchSourceFileSystemObject] = [:]
    private var pendingNotification: Task<Void, Never>?
    private var transcriptPaths: [String] = []
    private var environment = ProcessInfo.processInfo.environment
    private var pendingRequiresDiscovery = false

    init(onChange: @escaping @MainActor (_ requiresDiscovery: Bool) -> Void) {
        self.onChange = onChange
    }

    func update(
        transcriptPaths: [String],
        environment: [String: String] = ProcessInfo.processInfo.environment,
        now: Date = Date())
    {
        self.transcriptPaths = transcriptPaths
        self.environment = environment
        let desiredPaths = CodexSessionWatchPaths.existingPaths(
            transcriptPaths: transcriptPaths,
            now: now,
            environment: environment)
        guard desiredPaths != Set(self.sources.keys) else { return }

        self.stopSources()
        for path in desiredPaths {
            let fileDescriptor = open(path, O_EVTONLY)
            guard fileDescriptor >= 0 else { continue }
            let source = DispatchSource.makeFileSystemObjectSource(
                fileDescriptor: fileDescriptor,
                eventMask: [.write, .delete, .rename, .extend, .attrib, .link, .revoke],
                queue: .main)
            source.setEventHandler { [weak self] in
                Task { @MainActor [weak self] in
                    self?.sourceDidChange(at: path)
                }
            }
            source.setCancelHandler {
                close(fileDescriptor)
            }
            self.sources[path] = source
            source.resume()
        }
    }

    func stop() {
        self.pendingNotification?.cancel()
        self.pendingNotification = nil
        self.pendingRequiresDiscovery = false
        self.stopSources()
    }

    private func scheduleNotification(requiresDiscovery: Bool) {
        self.pendingRequiresDiscovery = self.pendingRequiresDiscovery || requiresDiscovery
        guard self.pendingNotification == nil else { return }
        self.pendingNotification = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(200))
            guard !Task.isCancelled, let self else { return }
            self.pendingNotification = nil
            let pendingRequiresDiscovery = self.pendingRequiresDiscovery
            self.pendingRequiresDiscovery = false
            self.onChange(pendingRequiresDiscovery)
        }
    }

    private func sourceDidChange(at path: String) {
        var requiresDiscovery = CodexSessionWatchPaths.requiresDiscovery(
            for: path,
            transcriptPaths: self.transcriptPaths,
            environment: self.environment)
        if let source = self.sources[path],
           source.data.contains(.delete) ||
           source.data.contains(.rename) ||
           source.data.contains(.revoke)
        {
            requiresDiscovery = true
            source.cancel()
            self.sources.removeValue(forKey: path)
        }
        self.scheduleNotification(requiresDiscovery: requiresDiscovery)
    }

    private func stopSources() {
        for source in self.sources.values {
            source.cancel()
        }
        self.sources.removeAll()
    }
}
