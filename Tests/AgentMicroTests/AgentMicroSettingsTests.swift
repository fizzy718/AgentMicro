@testable import AgentMicro
import Foundation
import ServiceManagement
import Testing

@MainActor
struct AgentMicroSettingsTests {
    @Test
    func `settings default to privacy preserving local values`() throws {
        let (defaults, suiteName) = try Self.makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let settings = AgentMicroSettings(
            defaults: defaults,
            launchAtLoginStatus: { false },
            updateLaunchAtLogin: { _ in }
        )

        #expect(settings.taskNameMode == .projectOnly)
        #expect(settings.showRecentlyCompleted)
        #expect(!settings.launchAtLogin)
    }

    @Test
    func `task display preferences persist across settings instances`() throws {
        let (defaults, suiteName) = try Self.makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let first = AgentMicroSettings(
            defaults: defaults,
            launchAtLoginStatus: { false },
            updateLaunchAtLogin: { _ in }
        )

        first.taskNameMode = .taskTitleAndProject
        first.showRecentlyCompleted = false

        let reloaded = AgentMicroSettings(
            defaults: defaults,
            launchAtLoginStatus: { false },
            updateLaunchAtLogin: { _ in }
        )
        #expect(reloaded.taskNameMode == .taskTitleAndProject)
        #expect(!reloaded.showRecentlyCompleted)
    }

    @Test
    func `launch at login updates only after successful registration`() throws {
        let (defaults, suiteName) = try Self.makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        var requestedValues: [Bool] = []
        let settings = AgentMicroSettings(
            defaults: defaults,
            launchAtLoginStatus: { false },
            updateLaunchAtLogin: { requestedValues.append($0) }
        )

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
            updateLaunchAtLogin: { _ in throw TestError.registrationFailed }
        )

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
            unregister: { unregistrations += 1 }
        )
        try AgentMicroLaunchAtLoginManager.setEnabled(
            false,
            status: { .enabled },
            register: { registrations += 1 },
            unregister: { unregistrations += 1 }
        )

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
            unregister: {}
        )

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
