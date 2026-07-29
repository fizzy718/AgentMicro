import Foundation
import ServiceManagement
import Testing
@testable import AgentMicro

@MainActor
struct AgentMicroSettingsTests {
    @Test
    func `version display includes the build number`() {
        #expect(
            AgentMicroVersionDisplay.value(
                shortVersion: "0.1.0",
                buildNumber: "7") == "0.1.0 (7)")
        #expect(
            AgentMicroVersionDisplay.value(
                shortVersion: "0.1.0",
                buildNumber: nil) == "0.1.0")
        #expect(
            AgentMicroVersionDisplay.value(
                shortVersion: nil,
                buildNumber: nil) == "–")
    }

    @Test
    func `settings use task title and project with six visible tasks by default`() throws {
        let (defaults, suiteName) = try Self.makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let settings = AgentMicroSettings(
            defaults: defaults,
            launchAtLoginStatus: { false },
            updateLaunchAtLogin: { _ in })

        #expect(settings.taskNameMode == .taskTitleAndProject)
        #expect(AgentMicroTaskNameMode.allCases.first == .taskTitleAndProject)
        #expect(settings.appLanguage == .system)
        #expect(settings.autoUpdateEnabled)
        #expect(settings.taskDisplayLimit == 6)
        #expect(settings.showRecentlyCompleted)
        #expect(!settings.enhancedStatusDetection)
        #expect(!settings.launchAtLogin)
        #expect(settings.shouldPresentGuideOnLaunch)
        #expect(!settings.showGuideOnLaunch)
        #expect(AgentMicroSettingsPane.allCases.first == .guide)
    }

    @Test
    func `guide opens once by default and can be requested on every launch`() throws {
        let (defaults, suiteName) = try Self.makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let first = AgentMicroSettings(
            defaults: defaults,
            launchAtLoginStatus: { false },
            updateLaunchAtLogin: { _ in })

        #expect(first.shouldPresentGuideOnLaunch)
        first.markGuidePresented()
        #expect(!first.shouldPresentGuideOnLaunch)

        first.showGuideOnLaunch = true
        let reloaded = AgentMicroSettings(
            defaults: defaults,
            launchAtLoginStatus: { false },
            updateLaunchAtLogin: { _ in })
        #expect(reloaded.shouldPresentGuideOnLaunch)
        #expect(reloaded.hasPresentedGuide)
        #expect(reloaded.showGuideOnLaunch)
    }

    @Test
    func `language update and enhanced preferences persist across settings instances`() throws {
        let (defaults, suiteName) = try Self.makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let first = AgentMicroSettings(
            defaults: defaults,
            launchAtLoginStatus: { false },
            updateLaunchAtLogin: { _ in })

        first.appLanguage = .chineseSimplified
        first.autoUpdateEnabled = false
        first.enhancedStatusDetection = true

        let reloaded = AgentMicroSettings(
            defaults: defaults,
            launchAtLoginStatus: { false },
            updateLaunchAtLogin: { _ in })
        #expect(reloaded.appLanguage == .chineseSimplified)
        #expect(!reloaded.autoUpdateEnabled)
        #expect(reloaded.enhancedStatusDetection)

        reloaded.appLanguage = .system
        #expect(defaults.object(forKey: AgentMicroLocalization.appLanguageDefaultsKey) == nil)
    }

    @Test
    func `task display preferences persist across settings instances`() throws {
        let (defaults, suiteName) = try Self.makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let first = AgentMicroSettings(
            defaults: defaults,
            launchAtLoginStatus: { false },
            updateLaunchAtLogin: { _ in })

        first.taskNameMode = .taskTitleAndProject
        first.showRecentlyCompleted = false
        first.taskDisplayLimit = 14

        let reloaded = AgentMicroSettings(
            defaults: defaults,
            launchAtLoginStatus: { false },
            updateLaunchAtLogin: { _ in })
        #expect(reloaded.taskNameMode == .taskTitleAndProject)
        #expect(!reloaded.showRecentlyCompleted)
        #expect(reloaded.taskDisplayLimit == 14)
    }

    @Test
    func `task display limit is clamped between one and twenty`() throws {
        let (defaults, suiteName) = try Self.makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let settings = AgentMicroSettings(
            defaults: defaults,
            launchAtLoginStatus: { false },
            updateLaunchAtLogin: { _ in })

        settings.taskDisplayLimit = 0
        #expect(settings.taskDisplayLimit == 1)

        settings.taskDisplayLimit = 21
        #expect(settings.taskDisplayLimit == 20)
    }

    @Test
    func `read activity persists and a newer completion becomes unread again`() throws {
        let (defaults, suiteName) = try Self.makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let first = AgentMicroSettings(
            defaults: defaults,
            launchAtLoginStatus: { false },
            updateLaunchAtLogin: { _ in })
        let firstActivity = Date(timeIntervalSince1970: 10000)
        let firstTask = CodexTaskStateTestSupport.observation(
            state: .unread,
            activity: firstActivity)

        first.markSessionRead(firstTask, now: firstActivity)

        let reloaded = AgentMicroSettings(
            defaults: defaults,
            launchAtLoginStatus: { false },
            updateLaunchAtLogin: { _ in })
        #expect(reloaded.readSessionKeys(for: [firstTask]) == [firstTask.sessionKey])

        let newerTask = CodexTaskStateTestSupport.observation(
            state: .unread,
            activity: firstActivity.addingTimeInterval(60))
        #expect(reloaded.readSessionKeys(for: [newerTask]).isEmpty)
    }

    @Test
    func `launch at login updates only after successful registration`() throws {
        let (defaults, suiteName) = try Self.makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        var requestedValues: [Bool] = []
        let settings = AgentMicroSettings(
            defaults: defaults,
            launchAtLoginStatus: { false },
            updateLaunchAtLogin: { requestedValues.append($0) })

        settings.setLaunchAtLogin(true)

        #expect(requestedValues == [true])
        #expect(settings.launchAtLogin)
        #expect(settings.launchAtLoginError == nil)
    }

    @Test
    func `launch at login failure restores system status and reports the error`() throws {
        let (defaults, suiteName) = try Self.makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let settings = AgentMicroSettings(
            defaults: defaults,
            launchAtLoginStatus: { false },
            updateLaunchAtLogin: { _ in throw TestError.registrationFailed })

        settings.setLaunchAtLogin(true)

        #expect(!settings.launchAtLogin)
        #expect(settings.launchAtLoginError != nil)
    }

    @Test
    func `launch manager avoids duplicate registration and unregisters enabled services`() throws {
        var registrations = 0
        var unregistrations = 0

        try AgentMicroLaunchAtLoginManager.setEnabled(
            true,
            status: { .enabled },
            register: { registrations += 1 },
            unregister: { unregistrations += 1 })
        try AgentMicroLaunchAtLoginManager.setEnabled(
            false,
            status: { .enabled },
            register: { registrations += 1 },
            unregister: { unregistrations += 1 })

        #expect(registrations == 0)
        #expect(unregistrations == 1)
    }

    @Test
    func `launch manager registers a missing service`() throws {
        var registrations = 0

        try AgentMicroLaunchAtLoginManager.setEnabled(
            true,
            status: { .notRegistered },
            register: { registrations += 1 },
            unregister: {})

        #expect(registrations == 1)
    }

    private enum TestError: Error {
        case registrationFailed
    }

    private static func makeDefaults() throws -> (UserDefaults, String) {
        let suiteName = "AgentMicroSettingsTests-\(UUID().uuidString)"
        return try (#require(UserDefaults(suiteName: suiteName)), suiteName)
    }
}
