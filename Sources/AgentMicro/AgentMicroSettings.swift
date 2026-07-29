import Foundation
import Observation
import ServiceManagement

enum AgentMicroAppLanguage: String, CaseIterable, Identifiable, Sendable {
    case system = ""
    case english = "en"
    case chineseSimplified = "zh-Hans"
    case chineseTraditional = "zh-Hant"
    case japanese = "ja"
    case spanish = "es"
    case portugueseBrazilian = "pt-BR"
    case korean = "ko"
    case german = "de"
    case french = "fr"
    case arabic = "ar"
    case italian = "it"
    case vietnamese = "vi"
    case dutch = "nl"
    case turkish = "tr"
    case ukrainian = "uk"
    case russian = "ru"
    case indonesian = "id"
    case polish = "pl"
    case persian = "fa"
    case thai = "th"
    case galician = "gl"
    case catalan = "ca"
    case swedish = "sv"

    var id: String {
        self.rawValue
    }

    var displayName: String {
        switch self {
        case .system:
            AgentMicroLocalization.text("language.system")
        case .english:
            "English"
        case .chineseSimplified:
            "简体中文"
        case .chineseTraditional:
            "繁體中文"
        case .spanish:
            "Español"
        case .catalan:
            "Català"
        case .portugueseBrazilian:
            "Português (Brasil)"
        case .german:
            "Deutsch"
        case .swedish:
            "Svenska"
        case .french:
            "Français"
        case .italian:
            "Italiano"
        case .dutch:
            "Nederlands"
        case .japanese:
            "日本語"
        case .korean:
            "한국어"
        case .vietnamese:
            "Tiếng Việt"
        case .turkish:
            "Türkçe"
        case .ukrainian:
            "Українська"
        case .russian:
            "Русский"
        case .indonesian:
            "Bahasa Indonesia"
        case .polish:
            "Polski"
        case .arabic:
            "العربية"
        case .persian:
            "فارسی"
        case .thai:
            "ไทย"
        case .galician:
            "Galego"
        }
    }
}

enum AgentMicroTaskNameMode: String, CaseIterable, Identifiable, Sendable {
    case taskTitleAndProject
    case taskTitle
    case projectOnly

    var id: String {
        self.rawValue
    }

    var displayName: String {
        switch self {
        case .projectOnly:
            AgentMicroLocalization.text("settings.taskNameMode.projectOnly")
        case .taskTitle:
            AgentMicroLocalization.text("settings.taskNameMode.taskTitle")
        case .taskTitleAndProject:
            AgentMicroLocalization.text("settings.taskNameMode.taskTitleAndProject")
        }
    }
}

struct AgentMicroPreferences: Equatable, Sendable {
    var taskNameMode: AgentMicroTaskNameMode = .taskTitleAndProject
    var showRecentlyCompleted = true
    var taskDisplayLimit = AgentMicroSettings.defaultTaskDisplayLimit
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
            unregister: { try service.unregister() })
    }

    static func setEnabled(
        _ enabled: Bool,
        status: StatusProvider,
        register: RegistrationAction,
        unregister: RegistrationAction) throws
    {
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
    nonisolated static let minimumTaskDisplayLimit = 1
    nonisolated static let maximumTaskDisplayLimit = 20
    nonisolated static let defaultTaskDisplayLimit = 6

    private enum Key {
        static let appLanguage = AgentMicroLocalization.appLanguageDefaultsKey
        static let autoUpdateEnabled = "agentMicro.autoUpdateEnabled"
        static let hasPresentedGuide = "agentMicro.hasPresentedGuide"
        static let showGuideOnLaunch = "agentMicro.showGuideOnLaunch"
        static let taskNameMode = "agentMicro.taskNameMode"
        static let showRecentlyCompleted = "agentMicro.showRecentlyCompleted"
        static let taskDisplayLimit = "agentMicro.taskDisplayLimit"
        static let readSessionActivity = "agentMicro.readSessionActivity"
    }

    var appLanguage: AgentMicroAppLanguage {
        didSet {
            if self.appLanguage == .system {
                self.defaults.removeObject(forKey: Key.appLanguage)
            } else {
                self.defaults.set(self.appLanguage.rawValue, forKey: Key.appLanguage)
            }
            self.notifyChange()
        }
    }

    var autoUpdateEnabled: Bool {
        didSet {
            self.defaults.set(self.autoUpdateEnabled, forKey: Key.autoUpdateEnabled)
            self.notifyChange()
        }
    }

    var showGuideOnLaunch: Bool {
        didSet {
            self.defaults.set(self.showGuideOnLaunch, forKey: Key.showGuideOnLaunch)
            self.notifyChange()
        }
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

    var taskDisplayLimit: Int {
        didSet {
            let boundedValue = min(
                Self.maximumTaskDisplayLimit,
                max(Self.minimumTaskDisplayLimit, self.taskDisplayLimit))
            guard self.taskDisplayLimit == boundedValue else {
                self.taskDisplayLimit = boundedValue
                return
            }
            self.defaults.set(self.taskDisplayLimit, forKey: Key.taskDisplayLimit)
            self.notifyChange()
        }
    }

    private(set) var launchAtLogin: Bool
    private(set) var launchAtLoginError: String?
    private(set) var hasPresentedGuide: Bool

    @ObservationIgnored
    var onChange: (() -> Void)?

    @ObservationIgnored
    private let defaults: UserDefaults

    @ObservationIgnored
    private let launchAtLoginStatus: () -> Bool

    @ObservationIgnored
    private let updateLaunchAtLogin: (Bool) throws -> Void

    @ObservationIgnored
    private var readSessionActivity: [String: TimeInterval]

    init(
        defaults: UserDefaults = .standard,
        launchAtLoginStatus: @escaping () -> Bool = { AgentMicroLaunchAtLoginManager.isEnabled },
        updateLaunchAtLogin: @escaping (Bool) throws -> Void = { enabled in
            try AgentMicroLaunchAtLoginManager.setEnabled(enabled)
        })
    {
        self.defaults = defaults
        self.launchAtLoginStatus = launchAtLoginStatus
        self.updateLaunchAtLogin = updateLaunchAtLogin
        self.appLanguage = defaults.string(forKey: Key.appLanguage)
            .flatMap(AgentMicroAppLanguage.init(rawValue:)) ?? .system
        self.autoUpdateEnabled = defaults.object(forKey: Key.autoUpdateEnabled) as? Bool ?? true
        self.showGuideOnLaunch = defaults.object(forKey: Key.showGuideOnLaunch) as? Bool ?? false
        self.taskNameMode = defaults.string(forKey: Key.taskNameMode)
            .flatMap(AgentMicroTaskNameMode.init(rawValue:)) ?? .taskTitleAndProject
        self.showRecentlyCompleted = defaults.object(forKey: Key.showRecentlyCompleted) as? Bool ?? true
        let savedTaskDisplayLimit = defaults.object(forKey: Key.taskDisplayLimit) as? Int ??
            Self.defaultTaskDisplayLimit
        self.taskDisplayLimit = min(
            Self.maximumTaskDisplayLimit,
            max(Self.minimumTaskDisplayLimit, savedTaskDisplayLimit))
        self.readSessionActivity = defaults.dictionary(forKey: Key.readSessionActivity)?
            .compactMapValues { ($0 as? NSNumber)?.doubleValue } ?? [:]
        self.launchAtLogin = launchAtLoginStatus()
        self.hasPresentedGuide = defaults.bool(forKey: Key.hasPresentedGuide)
    }

    var shouldPresentGuideOnLaunch: Bool {
        !self.hasPresentedGuide || self.showGuideOnLaunch
    }

    var preferences: AgentMicroPreferences {
        AgentMicroPreferences(
            taskNameMode: self.taskNameMode,
            showRecentlyCompleted: self.showRecentlyCompleted,
            taskDisplayLimit: self.taskDisplayLimit)
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            try self.updateLaunchAtLogin(enabled)
            self.launchAtLogin = enabled
            self.launchAtLoginError = nil
        } catch {
            self.launchAtLogin = self.launchAtLoginStatus()
            self.launchAtLoginError = AgentMicroLocalization.text(
                "settings.error.launchAtLogin",
                arguments: error.localizedDescription)
        }
        self.notifyChange()
    }

    func refreshLaunchAtLoginStatus() {
        self.launchAtLogin = self.launchAtLoginStatus()
        self.launchAtLoginError = nil
    }

    func markGuidePresented() {
        guard !self.hasPresentedGuide else { return }
        self.hasPresentedGuide = true
        self.defaults.set(true, forKey: Key.hasPresentedGuide)
        self.notifyChange()
    }

    func readSessionKeys(for tasks: [CodexTaskObservation]) -> Set<String> {
        Set(tasks.compactMap { task in
            guard let readAt = self.readSessionActivity[task.sessionKey] else { return nil }
            let activity = task.lastEventAt ?? task.session.lastActivityAt ?? task.session.startedAt
            guard activity.map({ readAt >= $0.timeIntervalSince1970 }) ?? true else { return nil }
            return task.sessionKey
        })
    }

    func markSessionRead(
        _ task: CodexTaskObservation,
        now: Date = Date(),
        notifyChange: Bool = true)
    {
        let activity = task.lastEventAt ?? task.session.lastActivityAt ?? task.session.startedAt ?? now
        self.readSessionActivity[task.sessionKey] = max(
            now.timeIntervalSince1970,
            activity.timeIntervalSince1970)
        if self.readSessionActivity.count > 256 {
            self.readSessionActivity = Dictionary(
                uniqueKeysWithValues: self.readSessionActivity
                    .sorted { $0.value > $1.value }
                    .prefix(256)
                    .map { ($0.key, $0.value) })
        }
        self.defaults.set(self.readSessionActivity, forKey: Key.readSessionActivity)
        if notifyChange {
            self.notifyChange()
        }
    }

    private func notifyChange() {
        self.onChange?()
    }
}
