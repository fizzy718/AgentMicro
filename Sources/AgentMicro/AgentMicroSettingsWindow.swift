import AppKit
import SwiftUI

@MainActor
final class AgentMicroSettingsWindowController: NSWindowController, NSWindowDelegate {
    init(settings: AgentMicroSettings) {
        let rootView = AgentMicroSettingsView(settings: settings)
        let hostingController = NSHostingController(rootView: rootView)
        let window = NSWindow(contentViewController: hostingController)
        window.title = "AgentMicro Settings"
        window.styleMask = [.titled, .closable]
        window.setContentSize(NSSize(width: 460, height: 300))
        window.isReleasedWhenClosed = false
        window.center()
        super.init(window: window)
        window.delegate = self
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func present() {
        self.window?.center()
        self.showWindow(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
}

private struct AgentMicroSettingsView: View {
    @Bindable var settings: AgentMicroSettings

    var body: some View {
        Form {
            Section("General") {
                Toggle(
                    "Start AgentMicro at login",
                    isOn: Binding(
                        get: { self.settings.launchAtLogin },
                        set: { self.settings.setLaunchAtLogin($0) }
                    )
                )
                if let error = self.settings.launchAtLoginError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Section("Task display") {
                Picker("Task names", selection: self.$settings.taskNameMode) {
                    ForEach(AgentMicroTaskNameMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                Toggle("Show recently completed tasks", isOn: self.$settings.showRecentlyCompleted)
            }

            Section {
                Text("AgentMicro reads task state locally and does not upload task data.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 460, height: 300)
    }
}
