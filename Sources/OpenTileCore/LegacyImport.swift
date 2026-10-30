import Foundation

/// Restricted binary plist reader. Archive UIDs stay integer references; no classes are instantiated.
private final class DecodeBudget { var visits = 0 }

struct ArchiveReader {
    private let budget = DecodeBudget()
    let bytes: [UInt8]
    let offsets: [Int]
    let refSize: Int
    let top: Int
    init(_ data: Data) throws {
        let b = Array(data)
        guard b.count >= 40, b.count <= 4_194_304, String(bytes: b.prefix(8), encoding: .ascii) == "bplist00" else { throw ConfigError.invalid("Not a binary property list archive.") }
        func number(_ start: Int, _ count: Int) throws -> Int {
            guard count > 0, count <= 8, start >= 0, start <= b.count-count else { throw ConfigError.invalid("Invalid plist bounds.") }
            var n: UInt64 = 0
            for value in b[start..<start+count] { n = (n << 8) | UInt64(value) }
            guard n <= UInt64(Int.max) else { throw ConfigError.invalid("Oversized plist integer.") }
            return Int(n)
        }
        let t = b.count-32, offsetSize = Int(b[t+6]), refs = Int(b[t+7])
        let count = try number(t+8, 8), root = try number(t+16, 8), table = try number(t+24, 8)
        guard (1...8).contains(offsetSize), (1...8).contains(refs), count > 0, count <= 100_000,
              root < count, table >= 8, table <= t, count <= (t-table)/offsetSize else { throw ConfigError.invalid("Invalid archive trailer.") }
        var positions: [Int] = []
        for i in 0..<count { let p = try number(table+i*offsetSize, offsetSize); guard p >= 8, p < table else { throw ConfigError.invalid("Invalid object offset.") }; positions.append(p) }
        bytes = b; offsets = positions; refSize = refs; top = root
    }
    func integer(_ p: Int, _ size: Int) throws -> Int {
        guard (1...8).contains(size), p >= 0, p <= bytes.count-size else { throw ConfigError.invalid("Invalid archive integer.") }
        var n: UInt64 = 0
        for b in bytes[p..<p+size] { n = n << 8 | UInt64(b) }
        guard n <= UInt64(Int.max) else { throw ConfigError.invalid("Archive integer overflow.") }
        return Int(n)
    }
    func object(_ index: Int, depth: Int = 0) throws -> Any {
        budget.visits += 1
        guard budget.visits <= 200_000, depth < 32, offsets.indices.contains(index) else { throw ConfigError.invalid("Invalid archive reference.") }
        let p = offsets[index], marker = bytes[p], kind = marker >> 4, info = Int(marker & 15)
        var start = p+1, count = info
        if [4,5,6,10,13].contains(Int(kind)), info == 15 {
            guard start < bytes.count, bytes[start] >> 4 == 1 else { throw ConfigError.invalid("Invalid archive length.") }
            let width = 1 << Int(bytes[start] & 15)
            count = try integer(start+1, width); start += 1+width
        }
        guard count <= 100_000 else { throw ConfigError.invalid("Archive item too large.") }
        func bounds(_ n: Int) throws { guard start <= bytes.count-n else { throw ConfigError.invalid("Truncated archive.") } }
        switch kind {
        case 0: return info == 9
        case 1: return try integer(start, 1 << info)
        case 8: return try integer(start, info+1) // UID reference
        case 4: try bounds(count); return Data(bytes[start..<start+count])
        case 5: try bounds(count); guard let s = String(bytes: bytes[start..<start+count], encoding: .ascii) else { throw ConfigError.invalid("Invalid string.") }; return s
        case 6: try bounds(count*2); guard let s = String(data: Data(bytes[start..<start+count*2]), encoding: .utf16BigEndian) else { throw ConfigError.invalid("Invalid Unicode.") }; return s
        case 10:
            try bounds(count*refSize)
            return try (0..<count).map { try object(integer(start+$0*refSize, refSize), depth: depth+1) }
        case 13:
            try bounds(count*refSize*2); var result: [String: Any] = [:]
            for i in 0..<count {
                guard let key = try object(integer(start+i*refSize, refSize), depth: depth+1) as? String else { throw ConfigError.invalid("Invalid dictionary key.") }
                result[key] = try object(integer(start+(count+i)*refSize, refSize), depth: depth+1)
            }
            return result
        default: throw ConfigError.invalid("Unsupported archive value.")
        }
    }
}

public enum DivvyImport {
    public static func shortcuts(from data: Data) throws -> [Shortcut] {
        let reader = try ArchiveReader(data)
        guard let archive = try reader.object(reader.top) as? [String: Any],
              archive["$archiver"] as? String == "NSKeyedArchiver",
              let objects = archive["$objects"] as? [Any], let top = archive["$top"] as? [String: Any],
              let rootIndex = top["root"] as? Int, objects.indices.contains(rootIndex),
              let root = objects[rootIndex] as? [String: Any], let entries = root["NS.objects"] as? [Int] else { throw ConfigError.invalid("Invalid Divvy shortcut archive.") }
        return try entries.map { index in
            guard objects.indices.contains(index), let item = objects[index] as? [String: Any] else { throw ConfigError.invalid("Invalid shortcut reference.") }
            func number(_ key: String) throws -> Int { guard let v = item[key] as? Int else { throw ConfigError.invalid("Missing shortcut field: \(key)") }; return v }
            let selection = try GridSelection(rows: number("sizeRows"), columns: number("sizeColumns"),
                startRow: number("selectionStartRow"), endRow: number("selectionEndRow"),
                startColumn: number("selectionStartColumn"), endColumn: number("selectionEndColumn"), subdivided: item["subdivided"] as? Bool ?? false)
            let nameIndex = try number("nameKey"), code = try number("keyComboCode"), flags = try number("keyComboFlags")
            guard selection.isValid, objects.indices.contains(nameIndex), (0...127).contains(code), flags <= Int(UInt32.max) else { throw ConfigError.invalid("Invalid shortcut coordinates or key.") }
            var shortcut = Shortcut(name: objects[nameIndex] as? String ?? "", binding: KeyBinding(keyCode: UInt32(code), modifiers: KeyBinding.normalize(UInt32(flags))), selection: selection)
            shortcut.enabled = item["enabled"] as? Bool ?? true; shortcut.global = item["global"] as? Bool ?? false
            return shortcut
        }
    }
    public static func configuration(preferences data: Data) throws -> Configuration {
        guard let p = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else { throw ConfigError.invalid("Invalid preferences plist.") }
        var c = Configuration()
        c.rows = p["defaultRowCount"] as? Int ?? 6; c.columns = p["defaultColumnCount"] as? Int ?? 6
        c.resetGrid = p["useDefaultGrid"] as? Bool ?? false
        c.showMenuIcon = p["showMenuIcon"] as? Bool ?? true
        c.keepOpen = p["mustDismissPanel"] as? Bool ?? false
        c.cycleScreens = p["useMonitorCycling"] as? Bool ?? false
        c.animations = p["enableAnimations"] as? Bool ?? true
        c.preview = p["showResizePreview"] as? Bool ?? true
        c.activationEnabled = p["useGlobalHotkey"] as? Bool ?? false
        if let key = p["globalHotkey"] as? [String: Any], let code = key["keyCode"] as? UInt32, let flags = key["modifiers"] as? UInt32 {
            c.activation = KeyBinding(keyCode: code, modifiers: KeyBinding.normalize(flags))
        }
        c.margins.enabled = p["enableMargins"] as? Bool ?? false
        c.margins.left = p["defaultScreenMarginLeft"] as? Double ?? 10; c.margins.right = p["defaultScreenMarginRight"] as? Double ?? 10
        c.margins.top = p["defaultScreenMarginTop"] as? Double ?? 10; c.margins.bottom = p["defaultScreenMarginBottom"] as? Double ?? 10
        c.margins.horizontal = p["defaultWindowMarginWidth"] as? Double ?? 10; c.margins.vertical = p["defaultWindowMarginHeight"] as? Double ?? 10
        if let data = p["shortcuts"] as? Data { c.shortcuts = try shortcuts(from: data) }
        return try c.validated()
    }
    public static func importURL(_ string: String) throws -> [Shortcut] {
        let prefix = "divvy://import/"
        guard string.hasPrefix(prefix), let decoded = String(string.dropFirst(prefix.count)).removingPercentEncoding,
              let data = Data(base64Encoded: decoded) else { throw ConfigError.invalid("Invalid Divvy import URL.") }
        return try shortcuts(from: data)
    }
}
