import AppKit
import XCTest
import OpenTileCore
@testable import OpenTileApp

private final class UnavailableWindowDriver: WindowDriver {
    override func capture() throws { throw ConfigError.invalid("No accessible test window.") }
}

@MainActor
final class PanelTests: XCTestCase {
    private func controller() throws -> AppController {
        let application = NSApplication.shared
        configureBackgroundApplication(application)
        guard !NSScreen.screens.isEmpty else { throw XCTSkip("Panel checks require a macOS display session.") }
        let controller = AppController(driver:UnavailableWindowDriver())
        controller.config.animations = false
        controller.config.rows = 9; controller.config.columns = 9; controller.config.resetGrid = true
        return controller
    }

    func testActivationShowsGridWhenWindowAccessFails() throws {
        let app = try controller(); defer { app.dismiss() }
        app.toggle()
        XCTAssertNil(app.settingsWindow)
        XCTAssertEqual(app.panels.count,NSScreen.screens.count)
        XCTAssertEqual(app.grids.count,app.panels.count)
        XCTAssertTrue(app.panels.allSatisfy(\.isVisible))
        XCTAssertTrue(app.grids.allSatisfy { $0.rows == 9 && $0.columns == 9 })
        XCTAssertTrue(app.panelStatusLabels.allSatisfy { !$0.isHidden && $0.stringValue == "No accessible test window." })
        XCTAssertEqual(NSApp.activationPolicy(),.accessory)
    }

    func testSecondActivationDismissesGrid() throws {
        let app = try controller(); defer { app.dismiss() }
        app.toggle(); app.toggle()
        XCTAssertTrue(app.panels.isEmpty); XCTAssertTrue(app.grids.isEmpty)
        XCTAssertTrue(app.panelStatusLabels.isEmpty); XCTAssertNil(app.settingsWindow)
    }

    func testEscapeDismissesThePanel() throws {
        let app = try controller(); defer { app.dismiss() }
        app.toggle()
        let escape = try XCTUnwrap(NSEvent.keyEvent(with:.keyDown,location:.zero,modifierFlags:[],timestamp:0,windowNumber:app.panels[0].windowNumber,context:nil,characters:"\u{1b}",charactersIgnoringModifiers:"\u{1b}",isARepeat:false,keyCode:53))
        XCTAssertTrue(app.handle(escape)); XCTAssertTrue(app.panels.isEmpty)
        XCTAssertNil(app.settingsWindow)
    }

    func testPlacementFailureStaysInGrid() throws {
        let app = try controller(); defer { app.dismiss() }
        app.toggle()
        XCTAssertFalse(app.place(GridSelection(),on:try XCTUnwrap(NSScreen.screens.first),shift:false))
        XCTAssertFalse(app.panels.isEmpty); XCTAssertNil(app.settingsWindow)
        XCTAssertTrue(app.panelStatusLabels.allSatisfy { $0.stringValue == "No accessible test window." })
    }

    func testReopeningApplicationShowsGrid() throws {
        let app = try controller(); defer { app.dismiss() }
        XCTAssertFalse(app.applicationShouldHandleReopen(NSApp,hasVisibleWindows:false))
        XCTAssertFalse(app.panels.isEmpty); XCTAssertNil(app.settingsWindow)
    }

    func testGlobalShortcutFailureShowsGrid() throws {
        let app = try controller(); defer { app.dismiss() }
        app.run(Shortcut(name:"Test",binding:KeyBinding(keyCode:14),selection:GridSelection()),global:true)
        XCTAssertFalse(app.panels.isEmpty); XCTAssertNil(app.settingsWindow)
    }

    func testExplicitSettingsRemainsOutsideDock() throws {
        let app = try controller()
        defer { app.dismiss(); app.settingsWindow?.orderOut(nil); app.settingsWindow?.contentView = nil; app.settingsWindow = nil }
        app.toggle(); app.showSettings()
        XCTAssertTrue(app.panels.isEmpty)
        XCTAssertNotNil(app.settingsWindow)
        XCTAssertEqual(NSApp.activationPolicy(),.accessory)
    }
}
