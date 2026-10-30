import AppKit
import ApplicationServices
import OpenTileCore

struct ManagedWindow {
    let element: AXUIElement
    let app: NSRunningApplication
}

class WindowDriver {
    var target: ManagedWindow?
    var lastExternal: NSRunningApplication?
    static var trusted: Bool { AXIsProcessTrusted() }
    static func requestPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }
    func capture() throws {
        target = nil
        guard Self.trusted else { throw ConfigError.invalid("Allow OpenTile in System Settings → Privacy & Security → Accessibility, then try again.") }
        let front = NSWorkspace.shared.frontmostApplication
        let app = front?.processIdentifier == ProcessInfo.processInfo.processIdentifier ? lastExternal : front
        guard let app, app.processIdentifier != ProcessInfo.processInfo.processIdentifier else { throw ConfigError.invalid("Activate a window in another application first.") }
        let ax = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(ax, 0.5)
        var value: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(ax, kAXFocusedWindowAttribute as CFString, &value)
        guard error == .success, let value, CFGetTypeID(value) == AXUIElementGetTypeID() else { throw ConfigError.invalid("\(app.localizedName ?? "The application") has no accessible focused window.") }
        target = ManagedWindow(element: unsafeBitCast(value, to: AXUIElement.self), app: app)
    }
    func frame() -> CGRect? {
        guard let element = target?.element else { return nil }
        var p: CFTypeRef?, s: CFTypeRef?, point = CGPoint.zero, size = CGSize.zero
        guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &p) == .success,
              AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &s) == .success,
              let p, let s, CFGetTypeID(p) == AXValueGetTypeID(), CFGetTypeID(s) == AXValueGetTypeID(),
              AXValueGetValue(unsafeBitCast(p, to: AXValue.self), .cgPoint, &point),
              AXValueGetValue(unsafeBitCast(s, to: AXValue.self), .cgSize, &size) else { return nil }
        return CGRect(origin: point, size: size)
    }
    func apply(_ frame: CGRect) throws -> CGRect {
        guard let element = target?.element else { throw ConfigError.invalid("No target window selected.") }
        var point = frame.origin, size = frame.size
        guard let p = AXValueCreate(.cgPoint, &point), let s = AXValueCreate(.cgSize, &size) else { throw ConfigError.invalid("Invalid window frame.") }
        // Some applications clamp movement at the old size; size both before and after moving.
        let firstSize = AXUIElementSetAttributeValue(element, kAXSizeAttribute as CFString, s)
        let position = AXUIElementSetAttributeValue(element, kAXPositionAttribute as CFString, p)
        let finalSize = AXUIElementSetAttributeValue(element, kAXSizeAttribute as CFString, s)
        guard position == .success, firstSize == .success || finalSize == .success else { throw ConfigError.invalid("The application refused to move or resize this window (AX \(position.rawValue)/\(finalSize.rawValue)).") }
        guard let actual = self.frame() else { throw ConfigError.invalid("Could not verify the resized window.") }
        return actual
    }
    static var primaryTop: CGFloat { NSScreen.screens.first?.frame.maxY ?? 0 }
    static func visibleFrame(_ screen: NSScreen) -> CGRect {
        CGRect(x: screen.visibleFrame.minX, y: primaryTop-screen.visibleFrame.maxY, width: screen.visibleFrame.width, height: screen.visibleFrame.height)
    }
    static func cocoaFrame(_ frame: CGRect) -> CGRect {
        CGRect(x: frame.minX, y: primaryTop-frame.maxY, width: frame.width, height: frame.height)
    }
    func screen() -> NSScreen? {
        guard let frame = frame() else { return NSScreen.main }
        return NSScreen.screens.max { a, b in
            let x = frame.intersection(Self.visibleFrame(a)), y = frame.intersection(Self.visibleFrame(b))
            return max(0,x.width)*max(0,x.height) < max(0,y.width)*max(0,y.height)
        }
    }
}
