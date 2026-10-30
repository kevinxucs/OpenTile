import AppKit
import OpenTileCore

extension AppController {
    /// Live acceptance run against the dedicated empty fixture only. Uses the production AX driver.
    func validateFixture() {
        guard let fixtureApp = NSRunningApplication.runningApplications(withBundleIdentifier:"org.opentile.fixture").first else {
            message = "Open build/OpenTileFixture.app before running live validation."; return
        }
        let originalTarget = driver.target
        defer { driver.target = originalTarget }
        let application = AXUIElementCreateApplication(fixtureApp.processIdentifier)
        var value: CFTypeRef?
        guard WindowDriver.trusted, AXUIElementCopyAttributeValue(application,kAXWindowsAttribute as CFString,&value) == .success,
              let windows = value as? [AXUIElement], let window = windows.first(where: { element in
                  var title: CFTypeRef?; AXUIElementCopyAttributeValue(element,kAXTitleAttribute as CFString,&title)
                  return title as? String == "OpenTile Validation Window"
              }) else { message = "Fixture window unavailable or Accessibility permission missing."; return }
        driver.target = ManagedWindow(element:window,app:fixtureApp)
        guard let originalFrame = driver.frame(), let screen = driver.screen() else { message = "Could not read fixture frame."; return }
        defer { _ = try? driver.apply(originalFrame) }
        var results: [[String:Any]] = []
        for shortcut in config.shortcuts {
            do {
                guard let expected = Geometry.frame(for:shortcut.selection,in:WindowDriver.visibleFrame(screen),margins:config.margins) else { throw ConfigError.invalid("Invalid geometry") }
                let actual = try driver.apply(expected)
                let passed = abs(expected.minX-actual.minX)<1 && abs(expected.minY-actual.minY)<1 && abs(expected.width-actual.width)<1 && abs(expected.height-actual.height)<1
                results.append(["keyCode":shortcut.binding.keyCode,"passed":passed,"expected":[expected.minX,expected.minY,expected.width,expected.height],"actual":[actual.minX,actual.minY,actual.width,actual.height]])
            } catch { results.append(["keyCode":shortcut.binding.keyCode,"passed":false,"error":error.localizedDescription]) }
        }
        let passed = results.filter { $0["passed"] as? Bool == true }.count
        let report: [String:Any] = ["date":ISO8601DateFormatter().string(from:Date()),"kind":"production AX driver acceptance; Divvy parity requires baseline comparison", "passed":passed,"total":results.count,"results":results]
        do {
            let output = configURL.deletingLastPathComponent().appendingPathComponent("validation.json")
            try FileManager.default.createDirectory(at:output.deletingLastPathComponent(),withIntermediateDirectories:true)
            try JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys]).write(to:output,options:.atomic)
            message = "Live AX validation: \(passed)/\(results.count) placements passed. Report: \(output.path)"
        } catch { message = "Validation completed \(passed)/\(results.count), but report failed: \(error.localizedDescription)" }
    }
}

extension AppController {
    func inspectActiveWindow() {
        do {
            try driver.capture()
            guard let frame = driver.frame(), let screen = driver.screen() else { throw ConfigError.invalid("Could not inspect the focused window.") }
            if observedWindow == nil { observedWindow = driver.target; observedFrame = frame }
            let visible = WindowDriver.visibleFrame(screen)
            message = "Window: x=\(frame.minX), y=\(frame.minY), width=\(frame.width), height=\(frame.height). Usable screen: \(visible)."
            let report: [String:Any] = ["time":Date().timeIntervalSince1970,"frame":[frame.minX,frame.minY,frame.width,frame.height],"screen":[visible.minX,visible.minY,visible.width,visible.height]]
            let output = configURL.deletingLastPathComponent().appendingPathComponent("inspection.json")
            try JSONSerialization.data(withJSONObject:report,options:[.sortedKeys]).write(to:output,options:.atomic)
        } catch { message = error.localizedDescription }
    }
    func restoreObservedWindow() {
        guard let observedWindow, let observedFrame else { message = "Inspect a window before restoring it."; return }
        let previous = driver.target; driver.target = observedWindow; defer { driver.target = previous }
        do { _ = try driver.apply(observedFrame); message = "Restored the inspected window’s original frame."; self.observedWindow = nil; self.observedFrame = nil }
        catch { message = error.localizedDescription }
    }
}
