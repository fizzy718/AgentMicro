import AppKit
import Observation
import SwiftUI

enum AgentMicroVersionDisplay {
    static func value(shortVersion: String?, buildNumber: String?) -> String {
        let version = shortVersion?.trimmingCharacters(in: .whitespacesAndNewlines)
        let build = buildNumber?.trimmingCharacters(in: .whitespacesAndNewlines)
        return switch (version?.isEmpty == false ? version : nil, build?.isEmpty == false ? build : nil) {
        case let (.some(version), .some(build)):
            "\(version) (\(build))"
        case let (.some(version), .none):
            version
        case let (.none, .some(build)):
            "(\(build))"
        case (.none, .none):
            "–"
        }
    }
}

enum AgentMicroSettingsPane: String, CaseIterable, Identifiable {
    case guide
    case general
    case tasks
    case updates

    var id: String {
        self.rawValue
    }

    var title: String {
        switch self {
        case .guide:
            AgentMicroLocalization.text("guide.title")
        case .general:
            AgentMicroLocalization.text("settings.general")
        case .tasks:
            AgentMicroLocalization.text("settings.taskDisplay")
        case .updates:
            AgentMicroLocalization.text("updates.section")
        }
    }

    var systemImage: String {
        switch self {
        case .guide: "sparkles"
        case .general: "gearshape.fill"
        case .tasks: "checklist"
        case .updates: "arrow.triangle.2.circlepath"
        }
    }

    var color: Color {
        switch self {
        case .guide: .blue
        case .general: .gray
        case .tasks: .green
        case .updates: .purple
        }
    }
}

@MainActor
@Observable
final class AgentMicroSettingsSelection {
    var pane: AgentMicroSettingsPane = .guide
}

@MainActor
final class AgentMicroSettingsWindowController: NSWindowController, NSWindowDelegate {
    private let selection: AgentMicroSettingsSelection

    init(
        settings: AgentMicroSettings,
        updater: AgentMicroUpdaterProviding,
        codexDataAccess: AgentMicroCodexDataAccess,
        onCodexDataAccessChanged: @escaping @MainActor () -> Void)
    {
        let selection = AgentMicroSettingsSelection()
        self.selection = selection
        let rootView = AgentMicroSettingsView(
            settings: settings,
            updater: updater,
            codexDataAccess: codexDataAccess,
            onCodexDataAccessChanged: onCodexDataAccessChanged,
            selection: selection)
        let hostingController = NSHostingController(rootView: rootView)
        let window = NSWindow(contentViewController: hostingController)
        window.title = AgentMicroLocalization.text("settings.title")
        window.styleMask = [.titled, .closable, .resizable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titlebarSeparatorStyle = .none
        window.setContentSize(NSSize(width: 760, height: 540))
        window.minSize = NSSize(width: 680, height: 480)
        window.isReleasedWhenClosed = false
        window.center()
        super.init(window: window)
        window.delegate = self
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func present(pane: AgentMicroSettingsPane? = nil) {
        if let pane {
            self.selection.pane = pane
        }
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
    @Bindable var codexDataAccess: AgentMicroCodexDataAccess
    let onCodexDataAccessChanged: @MainActor () -> Void
    @Bindable var selection: AgentMicroSettingsSelection

    private var version: String {
        AgentMicroVersionDisplay.value(
            shortVersion: Bundle.main.object(
                forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
            buildNumber: Bundle.main.object(
                forInfoDictionaryKey: "CFBundleVersion") as? String)
    }

    var body: some View {
        HStack(spacing: 0) {
            AgentMicroSettingsSidebar(selection: self.$selection.pane)
                .frame(width: 210)
                .background {
                    AgentMicroSettingsSidebarMaterial()
                        .ignoresSafeArea()
                }

            Divider()
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                Text(self.selection.pane.title)
                    .font(.title2.bold())
                    .padding(.horizontal, 28)
                    .padding(.top, 28)
                    .padding(.bottom, 18)

                Divider()

                self.detailView
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(
            minWidth: 680,
            idealWidth: 760,
            maxWidth: .infinity,
            minHeight: 480,
            idealHeight: 540,
            maxHeight: .infinity)
        .id(self.settings.appLanguage)
        .environment(
            \.layoutDirection,
            AgentMicroLocalization.isRightToLeft ? LayoutDirection.rightToLeft : .leftToRight)
    }

    @ViewBuilder
    private var detailView: some View {
        switch self.selection.pane {
        case .guide:
            AgentMicroGuidePane(settings: self.settings)
        case .general:
            self.generalPane
        case .tasks:
            self.tasksPane
        case .updates:
            self.updatesPane
        }
    }

    private var generalPane: some View {
        Form {
            #if ENABLE_AGENTMICRO_APP_STORE
            Section(AgentMicroLocalization.text("settings.codexData.title")) {
                Text(
                    self.codexDataAccess.displayPath ??
                        AgentMicroLocalization.text("settings.codexData.notAuthorized"))
                    .font(.caption)
                    .foregroundStyle(self.codexDataAccess.requiresSelection ? .orange : .secondary)
                    .textSelection(.enabled)
                Button(AgentMicroLocalization.text("settings.codexData.choose")) {
                    if self.codexDataAccess.chooseDirectory() {
                        self.onCodexDataAccessChanged()
                    }
                }
                if let error = self.codexDataAccess.lastError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                Text(AgentMicroLocalization.text("settings.codexData.description"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            #endif

            Section {
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

            Section {
                Toggle(
                    AgentMicroLocalization.text("settings.enhancedStatus"),
                    isOn: Binding(
                        get: { self.settings.enhancedStatusDetection },
                        set: { enabled in
                            self.settings.enhancedStatusDetection = enabled
                            if enabled {
                                AgentMicroAccessibilityAccess.requestPermission()
                            }
                        }))
                Text(AgentMicroLocalization.text("settings.enhancedStatus.description"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if self.settings.enhancedStatusDetection,
                   !AgentMicroAccessibilityAccess.isTrusted
                {
                    HStack {
                        Text(AgentMicroLocalization.text(
                            "settings.enhancedStatus.permissionRequired"))
                            .font(.caption)
                            .foregroundStyle(.orange)
                        Spacer()
                        Button(AgentMicroLocalization.text(
                            "settings.enhancedStatus.openSettings"))
                        {
                            AgentMicroAccessibilityAccess.openSystemSettings()
                        }
                    }
                }
            }

            Section {
                Text(AgentMicroLocalization.text("settings.privacy"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Link(
                    AgentMicroLocalization.text("settings.privacyPolicy"),
                    destination: URL(string: "https://agentmicro.cc/privacy.html")!)
            }
        }
        .formStyle(.grouped)
    }

    private var tasksPane: some View {
        Form {
            Section {
                Picker(
                    AgentMicroLocalization.text("settings.taskNames"),
                    selection: self.$settings.taskNameMode)
                {
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
        }
        .formStyle(.grouped)
    }

    private var updatesPane: some View {
        Form {
            Section {
                #if ENABLE_AGENTMICRO_APP_STORE
                LabeledContent(
                    AgentMicroLocalization.text("updates.version", arguments: self.version))
                {
                    EmptyView()
                }
                Text(AgentMicroLocalization.text("updates.appStore"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                #else
                Toggle(
                    AgentMicroLocalization.text("updates.automatic"),
                    isOn: self.$settings.autoUpdateEnabled)
                LabeledContent(
                    AgentMicroLocalization.text("updates.version", arguments: self.version))
                {
                    Button(AgentMicroLocalization.text("updates.check")) {
                        self.updater.checkForUpdates(nil)
                    }
                    .disabled(!self.updater.isAvailable)
                }
                if !self.updater.isAvailable {
                    Text(
                        self.updater.unavailableReason?.localizedDescription() ??
                            AgentMicroLocalization.text("updates.unavailable.build"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                #endif
            }
        }
        .formStyle(.grouped)
    }
}

private struct AgentMicroSettingsSidebar: View {
    @Binding var selection: AgentMicroSettingsPane

    var body: some View {
        List(selection: self.selectionBinding) {
            ForEach(AgentMicroSettingsPane.allCases) { pane in
                HStack(spacing: 9) {
                    AgentMicroSettingsIconChip(
                        systemImage: pane.systemImage,
                        color: pane.color)
                    Text(pane.title)
                }
                .tag(pane)
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .padding(.horizontal, 8)
        .padding(.top, 14)
    }

    private var selectionBinding: Binding<AgentMicroSettingsPane?> {
        Binding(
            get: { self.selection },
            set: { newValue in
                if let newValue {
                    self.selection = newValue
                }
            })
    }
}

private struct AgentMicroSettingsIconChip: View {
    let systemImage: String
    let color: Color

    var body: some View {
        Image(systemName: self.systemImage)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 22, height: 22)
            .background(self.color.gradient, in: RoundedRectangle(cornerRadius: 5))
            .accessibilityHidden(true)
    }
}

private struct AgentMicroGuidePane: View {
    @Bindable var settings: AgentMicroSettings

    private let states: [CodexTaskState] = [
        .idle,
        .unread,
        .thinking,
        .requiresInput,
        .error,
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text(AgentMicroLocalization.text("guide.subtitle"))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 0) {
                ForEach(self.states, id: \.rawValue) { state in
                    AgentMicroGuideStateRow(state: state)
                    if state != self.states.last {
                        Divider()
                            .padding(.leading, 44)
                    }
                }
            }
            .background(.quaternary.opacity(0.65), in: RoundedRectangle(cornerRadius: 12))

            Spacer(minLength: 16)

            HStack {
                Spacer()
                Toggle(
                    AgentMicroLocalization.text("guide.dontShowAgain"),
                    isOn: Binding(
                        get: { !self.settings.showGuideOnLaunch },
                        set: { self.settings.showGuideOnLaunch = !$0 }))
                    .toggleStyle(.checkbox)
            }
        }
        .padding(28)
    }
}

private struct AgentMicroGuideStateRow: View {
    let state: CodexTaskState

    var body: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(nsColor: AgentMicroStatusIcon.fillColor(for: self.state)))
                .overlay {
                    if self.state == .idle {
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(.secondary.opacity(0.35), lineWidth: 1)
                    }
                }
                .frame(width: 22, height: 16)

            VStack(alignment: .leading, spacing: 3) {
                Text(self.state.displayName)
                    .font(.body.weight(.semibold))
                Text(AgentMicroLocalization.text("guide.state.\(self.state.rawValue)"))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

@MainActor
private struct AgentMicroSettingsSidebarMaterial: NSViewRepresentable {
    func makeNSView(context _: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        self.configure(view)
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context _: Context) {
        self.configure(nsView)
    }

    private func configure(_ view: NSVisualEffectView) {
        view.material = .sidebar
        view.blendingMode = .behindWindow
        view.state = .followsWindowActiveState
    }
}
