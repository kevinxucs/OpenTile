import AppKit
import OpenTileCore
import OpenTileApp

if CommandLine.arguments.contains("--audit-divvy") {
    do {
        let url = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Preferences/com.mizage.Divvy.plist")
        let config = try DivvyImport.configuration(preferences:Data(contentsOf:url))
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted,.sortedKeys]
        print(String(decoding:try encoder.encode(config),as:UTF8.self))
    } catch { fputs("\(error.localizedDescription)\n",stderr); exit(1) }
} else {
    runOpenTileApplication()
}
