import XCTest
import CoreGraphics
@testable import OpenTileCore

final class CoreTests: XCTestCase {
    func testInclusiveBoundsAndSubdivision() throws {
        let s = GridSelection(rows: 9, columns: 9, startRow: 1, endRow: 16, startColumn: 2, endColumn: 15, subdivided: true)
        XCTAssertEqual(Geometry.frame(for: s, in: CGRect(x: 0, y: 25, width: 1800, height: 900)), CGRect(x: 200, y: 75, width: 1400, height: 800))
    }
    func testNegativeScreenOriginAndOddDimensions() {
        let s = GridSelection(rows: 3, columns: 3, startRow: 1, endRow: 1, startColumn: 1, endColumn: 2)
        XCTAssertEqual(Geometry.frame(for: s, in: CGRect(x: -1001, y: -500, width: 1001, height: 701)), CGRect(x: -667, y: -266, width: 667, height: 234))
    }
    func testMarginsAtEdgesAndBetweenWindows() throws {
        var m = Margins(); m.enabled = true; m.left = 20; m.right = 30; m.horizontal = 12
        let left = try XCTUnwrap(Geometry.frame(for: GridSelection(rows: 1, columns: 2, endRow: 0, endColumn: 0), in: CGRect(x: 0, y: 0, width: 1000, height: 800), margins: m))
        let right = try XCTUnwrap(Geometry.frame(for: GridSelection(rows: 1, columns: 2, endRow: 0, startColumn: 1, endColumn: 1), in: CGRect(x: 0, y: 0, width: 1000, height: 800), margins: m))
        XCTAssertEqual(left.minX, 20); XCTAssertEqual(right.maxX, 970); XCTAssertEqual(right.minX-left.maxX, 12)
    }
    func testInvalidGeometry() {
        XCTAssertNil(Geometry.frame(for: GridSelection(rows: 0), in: CGRect(x: 0, y: 0, width: 100, height: 100)))
        var m = Margins(); m.enabled = true; m.left = 300; m.right = 300
        XCTAssertNil(Geometry.frame(for: GridSelection(rows: 1, columns: 1, endRow: 0, endColumn: 0), in: CGRect(x: 0, y: 0, width: 100, height: 100), margins: m))
    }
    func testArchiveAndURLImport() throws {
        let file = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Fixtures/shortcuts.plist")
        let data = try Data(contentsOf: file)
        let shortcuts = try DivvyImport.shortcuts(from: data)
        XCTAssertEqual(shortcuts.count, 1); XCTAssertEqual(shortcuts[0].name, "Synthetic centered")
        XCTAssertEqual(shortcuts[0].selection.effectiveRows, 18); XCTAssertEqual(shortcuts[0].binding.keyCode, 8)
        XCTAssertEqual(try DivvyImport.importURL("divvy://import/" + data.base64EncodedString())[0].selection, shortcuts[0].selection)
    }
    func testMalformedArchivesAreRejected() throws {
        for data in [Data(), Data("not a plist".utf8), Data(repeating: 255, count: 100)] { XCTAssertThrowsError(try DivvyImport.shortcuts(from: data)) }
        let file = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Fixtures/shortcuts.plist")
        let good = try Data(contentsOf: file)
        for length in stride(from: 0, to: good.count, by: 7) { XCTAssertThrowsError(try DivvyImport.shortcuts(from: good.prefix(length))) }
    }
    func testModifiersAndConflicts() throws {
        XCTAssertEqual(KeyBinding.normalize(1<<20 | 1<<17 | 1<<19 | 1<<18), 256|512|2048|4096)
        XCTAssertEqual(KeyBinding.normalize(2048), 2048)
        var c = Configuration()
        c.shortcuts = [Shortcut(name: "Conflict", binding: c.activation, selection: GridSelection())]
        XCTAssertThrowsError(try c.validated())
        c.shortcuts[0].enabled = false; XCTAssertNoThrow(try c.validated())
    }
    func testPersistenceRoundTripAndInvalidConfig() throws {
        var c = Configuration(); c.shortcuts = [Shortcut(name: "Test", binding: KeyBinding(keyCode: 14), selection: GridSelection())]
        XCTAssertEqual(try JSONDecoder().decode(Configuration.self, from: JSONEncoder().encode(c)).validated(), c)
        c.rows = 11; XCTAssertThrowsError(try c.validated())
    }
}

extension CoreTests {
    func testDivvyPreferenceKeysAndDefaults() throws {
        let plist: [String:Any] = ["defaultRowCount":9,"defaultColumnCount":8,"useDefaultGrid":true,
            "mustDismissPanel":true,"useMonitorCycling":true,"enableMargins":true,
            "defaultScreenMarginLeft":13.0,"defaultScreenMarginRight":17.0,"defaultScreenMarginTop":19.0,
            "defaultScreenMarginBottom":23.0,"defaultWindowMarginWidth":29.0,"defaultWindowMarginHeight":31.0,
            "useGlobalHotkey":true,"globalHotkey":["keyCode":49,"modifiers":2048]]
        let c = try DivvyImport.configuration(preferences:PropertyListSerialization.data(fromPropertyList:plist,format:.binary,options:0))
        XCTAssertTrue(c.keepOpen); XCTAssertTrue(c.cycleScreens); XCTAssertTrue(c.resetGrid)
        XCTAssertEqual(c.margins.left,13); XCTAssertEqual(c.margins.right,17); XCTAssertEqual(c.margins.top,19)
        XCTAssertEqual(c.margins.bottom,23); XCTAssertEqual(c.margins.horizontal,29); XCTAssertEqual(c.margins.vertical,31)
        XCTAssertEqual(c.activation,KeyBinding(keyCode:49,modifiers:2048))
    }
    func testMissingPreferencesUseDivvyDefaults() throws {
        let data = try PropertyListSerialization.data(fromPropertyList:[:],format:.binary,options:0)
        let c = try DivvyImport.configuration(preferences:data)
        XCTAssertFalse(c.activationEnabled); XCTAssertEqual(c.rows,6); XCTAssertTrue(c.animations)
    }
    func testGlobalBareKeyAndInvalidMarginsRejected() {
        var c = Configuration(); var shortcut = Shortcut(name:"Bad global",binding:KeyBinding(keyCode:14),selection:GridSelection())
        shortcut.global = true; c.shortcuts = [shortcut]; XCTAssertThrowsError(try c.validated())
        c.shortcuts = []; c.margins.left = .nan; XCTAssertThrowsError(try c.validated())
        c.margins.left = -1; XCTAssertThrowsError(try c.validated())
    }
    func testEveryGridCellAndSubdivisionStaysWithinScreen() throws {
        let screen = CGRect(x:-1449,y:33,width:1449,height:949)
        for n in 1...10 { for sub in [false,true] {
            let count = n * (sub ? 2:1)
            for row in 0..<count { for col in 0..<count {
                let s = GridSelection(rows:n,columns:n,startRow:row,endRow:row,startColumn:col,endColumn:col,subdivided:sub)
                let f = try XCTUnwrap(Geometry.frame(for:s,in:screen))
                XCTAssertGreaterThanOrEqual(f.minX,screen.minX); XCTAssertGreaterThanOrEqual(f.minY,screen.minY)
                XCTAssertLessThanOrEqual(f.maxX,screen.maxX+1); XCTAssertLessThanOrEqual(f.maxY,screen.maxY+1)
            } }
        } }
    }
}
