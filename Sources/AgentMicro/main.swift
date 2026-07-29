import AppKit

let application = NSApplication.shared
let delegate = AgentMicroAppDelegate()
application.setActivationPolicy(.accessory)
application.delegate = delegate
application.run()
