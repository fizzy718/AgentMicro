import AppKit
import SwiftUI

@MainActor
final class AgentMicroSettingsWindowController: NSWindowController, NSWindowDelegate {
    init(settings: AgentMicroSettings, updater: AgentMicroUpdaterProviding) {
        let rootView = AgentMicroSettingsView(settings: settings, updater: updater)
        let hostingController = NSHostingController(rootView: rootView)
        let window = NSWindow(contentViewController: hostingController)
        window.title = AgentMicroLocalization.text("settings.title")
        window.styleMask = [.titled, .closable]
        window.setContentSize(NSSize(width: 460, height: 480))
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

    func refreshLocalization() {
        self.window?.title = AgentMicroLocalization.text("settings.title")
    }
}

private struct AgentMicroSettingsView: View {
    @Bindable var settings: AgentMicroSettings
    let updater: AgentMicroUpdaterProviding

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "–"
    }

    var body: some View {
        Form {
            Section(AgentMicroLocalization.text("settings.general")) {
                Picker(
                    AgentMicroLocalization.text("language.title"),
                    selection: self.$settings.appLanguage)
                {
                    ForEach(AgentMicroAppLanguage.allCases) { language in
                        Text(verbatim: language.displayName).tag(language)
                    }
                }
                Toggle(
                    AgentMicroLocalization.text("settings.launchAtLogin"),
                    isOn: Binding(
                        get: { self.settings.launchAtLogin },
                        set: { self.settings.setLaunchAtLogin($0) }))
                if let error = self.settings.launchAtLoginError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Section(AgentMicroLocalization.text("settings.taskDisplay")) {
                Picker(AgentMicroLocalization.text("settings.taskNames"), selection: self.$settings.taskNameMode) {
                    ForEach(AgentMicroTaskNameMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                LabeledContent(AgentMicroLocalization.text("settings.tasksShown")) {
                    HStack(spacing: 10) {
                        TextField(
                            value: self.$settings.taskDisplayLimit,
                            format: .number)
                        {
                            EmptyView()
                        }
                        .textFieldStyle(.roundedBorder)
                        .multilineTextAlignment(.trailing)
                        .monospacedDigit()
                        .frame(width: 52)
                        .accessibilityLabel(
                            AgentMicroLocalization.text("settings.tasksShown"))
                        Stepper(
                            "",
                            value: self.$settings.taskDisplayLimit,
                            in: AgentMicroSettings.minimumTaskDisplayLimit ...
                                AgentMicroSettings.maximumTaskDisplayLimit)
                            .labelsHidden()
                    }
                }
                Toggle(
                    AgentMicroLocalization.text("settings.showRecentlyCompleted"),
                    isOn: self.$settings.showRecentlyCompleted)
            }

            Section(AgentMicroLocalization.text("updates.section")) {
                if self.updater.isAvailable {
                    Toggle(
                        AgentMicroLocalization.text("updates.automatic"),
                        isOn: self.$settings.autoUpdateEnabled)
                    LabeledContent(
                        AgentMicroLocalization.text("updates.version", arguments: self.version))
                    {
                        Button(AgentMicroLocalization.text("updates.check")) {
                            self.updater.checkForUpdates(nil)
                        }
                    }
                } else {
                    Text(
                        self.updater.unavailableReason?.localizedDescription() ??
                            AgentMicroLocalization.text("updates.unavailable.build"))
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Text(AgentMicroLocalization.text("settings.privacy"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 460, height: 480)
        .environment(
            \.layoutDirection,
            AgentMicroLocalization.isRightToLeft ? LayoutDirection.rightToLeft : .leftToRight)
    }
}
