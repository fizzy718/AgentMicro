import Foundation
import Observation
import ServiceManagement

enum AgentMicroTaskNameMode: String, CaseIterable, Identifiable, Sendable {
    case projectOnly
    case taskTitle
    case taskTitleAndProject

    var id: String {
        self.rawValue
    }

    var displayName: String {
        switch self {
        case .projectOnly:
            "Project name only"
        case .taskTitle:
            "Task title"
        case .taskTitleAndProject:
            "Task title and project"
        }
    }
}

struct AgentMicroPreferences: Equatable, Sendable {
    var taskNameMode: AgentMicroTaskNameMode = .projectOnly
    var showRecentlyCompleted = true
}

enum AgentMicroLaunchAtLoginManager {
    typealias StatusProvider = () -> SMAppService.Status
    typealias RegistrationAction = () throws -> Void

    static var isEnabled: Bool {
        switch SMAppService.mainApp.status {
        case .enabled, .requiresApproval:
            true
        case .notRegistered, .notFound:
            false
        @unknown default:
            false
        }
    }

    static func setEnabled(_ enabled: Bool) throws {
        let service = SMAppService.mainApp
        try self.setEnabled(
            enabled,
            status: { service.status },
            register: { try service.register() },
            unregister: { try service.unregister() }
        )
    }

    static func setEnabled(
        _ enabled: Bool,
        status: StatusProvider,
        register: RegistrationAction,
        unregister: RegistrationAction
    ) throws {
        if enabled {
            switch status() {
            case .enabled, .requiresApproval:
                return
            case .notRegistered, .notFound:
                try register()
            @unknown default:
                try register()
            }
        } else {
            switch status() {
            case .enabled, .requiresApproval:
                try unregister()
            case .notRegistered, .notFound:
                return
            @unknown default:
                try unregister()
            }
        }
    }
}

@MainActor
@Observable
final class AgentMicroSettings {
    private enum Key {
        static let taskNameMode = "agentMicro.taskNameMode"
        static let showRecentlyCompleted = "agentMicro.showRecentlyCompleted"
    }

    var taskNameMode: AgentMicroTaskNameMode {
        didSet {
            self.defaults.set(self.taskNameMode.rawValue, forKey: Key.taskNameMode)
            self.notifyChange()
        }
    }

    var showRecentlyCompleted: Bool {
        didSet {
            self.defaults.set(self.showRecentlyCompleted, forKey: Key.showRecentlyCompleted)
            self.notifyChange()
        }
    }

    private(set) var launchAtLogin: Bool
    private(set) var launchAtLoginError: String?

    @ObservationIgnored
    var onChange: (() -> Void)?

    @ObservationIgnored
    private let defaults: UserDefaults

    @ObservationIgnored
    private let launchAtLoginStatus: () -> Bool

    @ObservationIgnored
    private let updateLaunchAtLogin: (Bool) throws -> Void

    init(
        defaults: UserDefaults = .standard,
        launchAtLoginStatus: @escaping () -> Bool = { AgentMicroLaunchAtLoginManager.isEnabled },
        updateLaunchAtLogin: @escaping (Bool) throws -> Void = { enabled in
            try AgentMicroLaunchAtLoginManager.setEnabled(enabled)
        }
    ) {
        self.defaults = defaults
        self.launchAtLoginStatus = launchAtLoginStatus
        self.updateLaunchAtLogin = updateLaunchAtLogin
        self.taskNameMode = defaults.string(forKey: Key.taskNameMode)
            .flatMap(AgentMicroTaskNameMode.init(rawValue:)) ?? .projectOnly
        self.showRecentlyCompleted = defaults.object(forKey: Key.showRecentlyCompleted) as? Bool ?? true
        self.launchAtLogin = launchAtLoginStatus()
    }

    var preferences: AgentMicroPreferences {
        AgentMicroPreferences(
            taskNameMode: self.taskNameMode,
            showRecentlyCompleted: self.showRecentlyCompleted
        )
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            try self.updateLaunchAtLogin(enabled)
            self.launchAtLogin = enabled
            self.launchAtLoginError = nil
        } catch {
            self.launchAtLogin = self.launchAtLoginStatus()
            self.launchAtLoginError = "Could not update login item: \(error.localizedDescription)"
        }
        self.notifyChange()
    }

    func refreshLaunchAtLoginStatus() {
        self.launchAtLogin = self.launchAtLoginStatus()
        self.launchAtLoginError = nil
    }

    private func notifyChange() {
        self.onChange?()
    }
}
