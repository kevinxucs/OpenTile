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
