import AppKit

// Entry point — run the NSApplication with our AppDelegate
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
