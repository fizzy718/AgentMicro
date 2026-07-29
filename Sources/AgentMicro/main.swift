import AppKit

if let focusIndex = CommandLine.arguments.firstIndex(of: "--diagnose-focus"),
   CommandLine.arguments.indices.contains(CommandLine.arguments.index(after: focusIndex)) {
    let sessionID = CommandLine.arguments[CommandLine.arguments.index(after: focusIndex)]
    await print(AgentMicroDiagnostics.focus(sessionID: sessionID))
} else if CommandLine.arguments.contains("--diagnose-once") {
    try await AgentMicroDiagnostics.writeSnapshot()
} else {
    let application = NSApplication.shared
    let delegate = AgentMicroAppDelegate()
    application.setActivationPolicy(.accessory)
    application.delegate = delegate
    application.run()
}
