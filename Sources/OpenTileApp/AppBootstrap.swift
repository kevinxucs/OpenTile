import AppKit

/// Apply the background-app policy before the event loop, including `swift run` launches.
func configureBackgroundApplication(_ application: NSApplication) {
    application.setActivationPolicy(.accessory)
}

public func runOpenTileApplication() {
    let application = NSApplication.shared
    configureBackgroundApplication(application)
    let delegate = AppController()
    application.delegate = delegate
    withExtendedLifetime(delegate) { application.run() }
}
