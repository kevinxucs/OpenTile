import Foundation
import CoreGraphics

public struct GridSelection: Codable, Equatable, Sendable {
    public var rows: Int
    public var columns: Int
    public var startRow: Int
    public var endRow: Int
    public var startColumn: Int
    public var endColumn: Int
    public var subdivided: Bool
    public init(rows: Int = 6, columns: Int = 6, startRow: Int = 0, endRow: Int = 5,
                startColumn: Int = 0, endColumn: Int = 5, subdivided: Bool = false) {
        self.rows = rows; self.columns = columns; self.startRow = startRow; self.endRow = endRow
        self.startColumn = startColumn; self.endColumn = endColumn; self.subdivided = subdivided
    }
    public var effectiveRows: Int { rows * (subdivided ? 2 : 1) }
    public var effectiveColumns: Int { columns * (subdivided ? 2 : 1) }
    public var isValid: Bool {
        (1...10).contains(rows) && (1...10).contains(columns) && startRow >= 0 && startColumn >= 0 &&
        endRow >= startRow && endColumn >= startColumn && endRow < effectiveRows && endColumn < effectiveColumns
    }
}

public struct Margins: Codable, Equatable, Sendable {
    public var enabled = false
    public var left = 10.0, right = 10.0, top = 10.0, bottom = 10.0
    public var horizontal = 10.0, vertical = 10.0
    public init() {}
    public var isValid: Bool { [left, right, top, bottom, horizontal, vertical].allSatisfy { $0.isFinite && (0...300).contains($0) } }
}

public enum Geometry {
    /// Screen is in Accessibility coordinates (origin at upper-left). Endpoints are inclusive.
    public static func frame(for selection: GridSelection, in screen: CGRect, margins: Margins = Margins()) -> CGRect? {
        guard selection.isValid, margins.isValid, screen.width > 0, screen.height > 0 else { return nil }
        let c = Double(selection.effectiveColumns), r = Double(selection.effectiveRows)
        var x0 = screen.minX + screen.width * Double(selection.startColumn) / c
        var x1 = screen.minX + screen.width * Double(selection.endColumn + 1) / c
        var y0 = screen.minY + screen.height * Double(selection.startRow) / r
        var y1 = screen.minY + screen.height * Double(selection.endRow + 1) / r
        if margins.enabled {
            x0 += selection.startColumn == 0 ? margins.left : margins.horizontal / 2
            x1 -= selection.endColumn == selection.effectiveColumns - 1 ? margins.right : margins.horizontal / 2
            y0 += selection.startRow == 0 ? margins.top : margins.vertical / 2
            y1 -= selection.endRow == selection.effectiveRows - 1 ? margins.bottom : margins.vertical / 2
        }
        guard x1 > x0, y1 > y0 else { return nil }
        return CGRect(x: x0.rounded(), y: y0.rounded(), width: (x1-x0).rounded(), height: (y1-y0).rounded())
    }
}

public struct KeyBinding: Codable, Hashable, Sendable {
    public var keyCode: UInt32
    /// Carbon modifier bits: command=256, shift=512, option=2048, control=4096.
    public var modifiers: UInt32
    public init(keyCode: UInt32, modifiers: UInt32 = 0) { self.keyCode = keyCode; self.modifiers = modifiers }
    public static func normalize(_ flags: UInt32) -> UInt32 {
        if flags & 0x1E0000 != 0 {
            return (flags & (1<<20) != 0 ? 256 : 0) | (flags & (1<<17) != 0 ? 512 : 0) |
                (flags & (1<<19) != 0 ? 2048 : 0) | (flags & (1<<18) != 0 ? 4096 : 0)
        }
        return flags & (256|512|2048|4096)
    }
}

public struct Shortcut: Codable, Identifiable, Equatable, Sendable {
    public var id = UUID()
    public var name: String
    public var binding: KeyBinding
    public var selection: GridSelection
    public var enabled = true
    public var global = false
    public init(name: String, binding: KeyBinding, selection: GridSelection) {
        self.name = name; self.binding = binding; self.selection = selection
    }
}

public struct Configuration: Codable, Equatable, Sendable {
    public var version = 1
    public var rows = 6, columns = 6
    public var resetGrid = false
    public var showMenuIcon = true
    public var keepOpen = false
    public var cycleScreens = false
    public var animations = true
    public var preview = true
    public var activationEnabled = true
    public var activation = KeyBinding(keyCode: 49, modifiers: 2048)
    public var margins = Margins()
    public var shortcuts: [Shortcut] = []
    public init() {}
    public func validated() throws -> Configuration {
        guard version == 1, (1...10).contains(rows), (1...10).contains(columns), margins.isValid,
              activation.keyCode <= 127, activation.modifiers == KeyBinding.normalize(activation.modifiers),
              !activationEnabled || activation.modifiers != 0,
              Set(shortcuts.map(\.id)).count == shortcuts.count,
              shortcuts.allSatisfy({ $0.selection.isValid && $0.binding.keyCode <= 127 &&
                  $0.binding.modifiers == KeyBinding.normalize($0.binding.modifiers) && (!$0.global || $0.binding.modifiers != 0) })
        else { throw ConfigError.invalid("Invalid grid, margins, key binding, or configuration version.") }
        var keys = Set<KeyBinding>()
        if activationEnabled { keys.insert(activation) }
        for shortcut in shortcuts where shortcut.enabled {
            guard keys.insert(shortcut.binding).inserted else { throw ConfigError.invalid("Duplicate shortcut: \(shortcut.name)") }
        }
        return self
    }
}

public enum ConfigError: LocalizedError {
    case invalid(String)
    public var errorDescription: String? { if case let .invalid(message) = self { return message }; return nil }
}
