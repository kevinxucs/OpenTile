import AppKit

final class Fixture: NSObject, NSWindowDelegate {
    var window: NSWindow!
    var label: NSTextField!
    var timer: Timer?
    var output: URL {
        Bundle.main.bundleURL.deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent(".local/fixture.jsonl")
    }
    func show() {
        NSApp.setActivationPolicy(.regular)
        window = NSWindow(contentRect: CGRect(x: 100,y: 100,width: 800,height: 600), styleMask: [.titled,.closable,.resizable,.miniaturizable], backing: .buffered, defer: false)
        window.title = "OpenTile Validation Window"; window.minSize = CGSize(width: 80,height: 80); window.delegate = self
        label = NSTextField(wrappingLabelWithString: "")
        label.font = .monospacedSystemFont(ofSize: 16, weight: .regular)
        label.frame = CGRect(x:20,y:20,width:700,height:100); label.autoresizingMask = [.width,.maxYMargin]
        window.contentView?.addSubview(label)
        window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps:true); record()
    }
    func windowDidMove(_ notification: Notification) { schedule() }
    func windowDidResize(_ notification: Notification) { schedule() }
    func schedule() { timer?.invalidate(); timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats:false) { [weak self] _ in self?.record() } }
    func record() {
        let f = window.frame, top = NSScreen.screens.first?.frame.maxY ?? 0
        let ax = CGRect(x:f.minX,y:top-f.maxY,width:f.width,height:f.height)
        label.stringValue = "Frame: x=\(ax.minX) y=\(ax.minY) w=\(ax.width) h=\(ax.height)\nUse this empty resizable window for Divvy comparisons."
        let displays = NSScreen.screens.map { ["x": $0.visibleFrame.minX,"y":top-$0.visibleFrame.maxY,"width":$0.visibleFrame.width,"height":$0.visibleFrame.height] }
        let event: [String: Any] = ["time":Date().timeIntervalSince1970,"x":ax.minX,"y":ax.minY,"width":ax.width,"height":ax.height,"screens":displays]
        do {
            try FileManager.default.createDirectory(at:output.deletingLastPathComponent(),withIntermediateDirectories:true)
            var data = try JSONSerialization.data(withJSONObject:event,options:[.sortedKeys]); data.append(10)
            if !FileManager.default.fileExists(atPath:output.path) { try Data().write(to:output) }
            let file = try FileHandle(forWritingTo:output); try file.seekToEnd(); try file.write(contentsOf:data); try file.close()
        } catch { NSLog("Fixture log: %@",error.localizedDescription) }
    }
}
