import AppKit
import OpenTileCore

final class TilePanel: NSPanel {
    var onKey: ((NSEvent) -> Void)?
    var onFlags: ((NSEvent) -> Void)?
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
    override func keyDown(with event: NSEvent) { onKey?(event) }
    override func flagsChanged(with event: NSEvent) { onFlags?(event) }
}

final class GridView: NSView {
    var rows = 6 { didSet { needsDisplay = true } }
    var columns = 6 { didSet { needsDisplay = true } }
    var subdivided = false { didSet { needsDisplay = true } }
    var selection: GridSelection? { didSet { needsDisplay = true } }
    var anchor: (Int, Int)?
    var onPreview: ((GridSelection?) -> Void)?
    var onSelect: ((GridSelection, Bool) -> Void)?
    var tracking: NSTrackingArea?
    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { false }
    var effectiveRows: Int { rows*(subdivided ? 2:1) }
    var effectiveColumns: Int { columns*(subdivided ? 2:1) }
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking { removeTrackingArea(tracking) }
        tracking = NSTrackingArea(rect: bounds, options: [.mouseMoved,.mouseEnteredAndExited,.activeAlways,.inVisibleRect], owner: self)
        addTrackingArea(tracking!)
    }
    func cell(_ event: NSEvent) -> (Int, Int) {
        let p = convert(event.locationInWindow, from: nil)
        return (max(0,min(effectiveRows-1,Int(p.y/bounds.height*CGFloat(effectiveRows)))), max(0,min(effectiveColumns-1,Int(p.x/bounds.width*CGFloat(effectiveColumns)))))
    }
    func region(_ a: (Int, Int), _ b: (Int, Int)) -> GridSelection {
        GridSelection(rows: rows, columns: columns, startRow: min(a.0,b.0), endRow: max(a.0,b.0), startColumn: min(a.1,b.1), endColumn: max(a.1,b.1), subdivided: subdivided)
    }
    override func mouseDown(with event: NSEvent) { anchor = cell(event); selection = region(anchor!,anchor!); onPreview?(selection) }
    override func mouseDragged(with event: NSEvent) { guard let anchor else { return }; selection = region(anchor,cell(event)); onPreview?(selection) }
    override func mouseUp(with event: NSEvent) {
        guard let anchor else { return }; let s = region(anchor,cell(event)); self.anchor = nil; selection = s
        onSelect?(s,event.modifierFlags.contains(.shift))
    }
    override func mouseMoved(with event: NSEvent) { guard anchor == nil else { return }; let p = cell(event); selection = region(p,p); onPreview?(selection) }
    override func mouseExited(with event: NSEvent) { if anchor == nil { selection = nil; onPreview?(nil) } }
    func cancel() { anchor = nil; selection = nil; onPreview?(nil) }
    override func draw(_ dirtyRect: NSRect) {
        for row in 0..<effectiveRows { for col in 0..<effectiveColumns {
            let w = bounds.width/CGFloat(effectiveColumns), h = bounds.height/CGFloat(effectiveRows)
            let rect = CGRect(x: CGFloat(col)*w+2, y: CGFloat(row)*h+2, width: max(1,w-4), height: max(1,h-4))
            let selected = selection.map { row >= $0.startRow && row <= $0.endRow && col >= $0.startColumn && col <= $0.endColumn } ?? false
            (selected ? NSColor.controlAccentColor : NSColor.quaternaryLabelColor).setFill()
            NSBezierPath(roundedRect: rect, xRadius: 4, yRadius: 4).fill()
        } }
    }
}
