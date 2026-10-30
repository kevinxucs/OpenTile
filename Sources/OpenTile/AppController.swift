import AppKit
import SwiftUI
import ServiceManagement
import OpenTileCore

final class AppController: NSObject, NSApplicationDelegate, ObservableObject {
    @Published var config = Configuration()
    @Published var message = ""
    @Published var permission = WindowDriver.trusted
    let driver = WindowDriver()
    let hotkeys = Hotkeys()
    var status: NSStatusItem?
    var panels: [TilePanel] = []
    var grids: [GridView] = []
    var previews: [NSPanel] = []
    var settingsWindow: NSWindow?
    var fixture: Fixture?
    var observer: NSObjectProtocol?
    var screenObserver: NSObjectProtocol?
    var lastShortcut: UUID?
    var lastWindow: AXUIElement?
    var lastAppliedFrame: CGRect?
    var hotkeyFailed = false
    var currentSubdivision = false
    var observedWindow: ManagedWindow?
    var observedFrame: CGRect?
    var configURL: URL {
        if let root = ProcessInfo.processInfo.environment["OPENTILE_CONFIG_DIR"] { return URL(fileURLWithPath:root).appendingPathComponent("config.json") }
        return FileManager.default.urls(for:.applicationSupportDirectory,in:.userDomainMask)[0].appendingPathComponent("OpenTile/config.json")
    }
    func applicationDidFinishLaunching(_ notification: Notification) {
        installMenus(self)
        if Bundle.main.bundleIdentifier == "org.opentile.fixture" || CommandLine.arguments.contains("--fixture") {
            fixture = Fixture(); fixture?.show(); return
        }
        NSApp.setActivationPolicy(.accessory)
        if let app = NSWorkspace.shared.frontmostApplication, app.processIdentifier != ProcessInfo.processInfo.processIdentifier { driver.lastExternal = app }
        observer = NSWorkspace.shared.notificationCenter.addObserver(forName:NSWorkspace.didActivateApplicationNotification,object:nil,queue:.main) { [weak self] notification in
            guard let self, let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  app.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return }
            self.driver.lastExternal = app
            if !self.panels.isEmpty { try? self.driver.capture() }
        }
        screenObserver = NotificationCenter.default.addObserver(forName:NSApplication.didChangeScreenParametersNotification,object:nil,queue:.main) { [weak self] _ in self?.dismiss() }
        load(); currentRows = config.rows; currentColumns = config.columns
        if !config.resetGrid {
            let rows = UserDefaults.standard.integer(forKey:"sessionRows"), columns = UserDefaults.standard.integer(forKey:"sessionColumns")
            if (1...10).contains(rows) { currentRows = rows }; if (1...10).contains(columns) { currentColumns = columns }
            currentSubdivision = UserDefaults.standard.bool(forKey:"sessionSubdivision")
        }
        refreshStatus(); registerHotkeys()
        showSettings()
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if let fixture { fixture.show() } else { toggle() }; return false
    }
    func applicationWillTerminate(_ notification: Notification) { hotkeys.clear() }
    func load() {
        guard FileManager.default.fileExists(atPath:configURL.path) else { return }
        do { config = try JSONDecoder().decode(Configuration.self,from:Data(contentsOf:configURL)).validated() }
        catch { message = "Configuration was not loaded: \(error.localizedDescription). The original file is preserved." }
    }
    @discardableResult func save(_ proposed: Configuration) -> Bool {
        do {
            let valid = try proposed.validated()
            let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted,.sortedKeys]
            try FileManager.default.createDirectory(at:configURL.deletingLastPathComponent(),withIntermediateDirectories:true)
            if FileManager.default.fileExists(atPath:configURL.path) {
                let old = try Data(contentsOf:configURL)
                try old.write(to:configURL.deletingLastPathComponent().appendingPathComponent("config.backup.json"),options:.atomic)
            }
            try encoder.encode(valid).write(to:configURL,options:.atomic)
            config = valid; dismiss(); refreshStatus(); registerHotkeys()
            if message.isEmpty { message = "Settings saved." }; refreshStatus(); return true
        } catch { message = error.localizedDescription; return false }
    }
    func refreshStatus() {
        if config.showMenuIcon || !config.activationEnabled || hotkeyFailed {
            if status == nil { status = NSStatusBar.system.statusItem(withLength:NSStatusItem.squareLength) }
            status?.button?.image = NSImage(systemSymbolName:"rectangle.split.3x3",accessibilityDescription:"OpenTile")
            let menu = NSMenu()
            menu.addItem(withTitle:"Show OpenTile",action:#selector(toggle),keyEquivalent:"").target = self
            menu.addItem(withTitle:"Settings…",action:#selector(showSettings),keyEquivalent:",").target = self
            menu.addItem(.separator())
            menu.addItem(withTitle:"Quit OpenTile",action:#selector(quit),keyEquivalent:"q").target = self
            status?.menu = menu
        } else if let status { NSStatusBar.system.removeStatusItem(status); self.status = nil }
    }
    func registerHotkeys() {
        hotkeys.clear(); hotkeyFailed = false; var failures: [String] = []
        if config.activationEnabled && !hotkeys.register(config.activation,action:{ [weak self] in self?.toggle() }) { failures.append(keyLabel(config.activation)) }
        for shortcut in config.shortcuts where shortcut.enabled && shortcut.global {
            if !hotkeys.register(shortcut.binding,action:{ [weak self] in self?.run(shortcut,global:true) }) { failures.append(keyLabel(shortcut.binding)) }
        }
        if !failures.isEmpty { hotkeyFailed = true; message = "Global shortcuts unavailable: \(failures.joined(separator:", ")). Quit the conflicting app (including Divvy), then click Save to retry."; refreshStatus() }
    }
    @objc func quit() { NSApp.terminate(nil) }
    @objc func showSettings() {
        dismiss(); permission = WindowDriver.trusted
        if settingsWindow == nil {
            let w = NSWindow(contentRect:CGRect(x:0,y:0,width:780,height:740),styleMask:[.titled,.closable,.miniaturizable,.resizable],backing:.buffered,defer:false)
            w.title = "OpenTile Settings"; w.isReleasedWhenClosed = false
            w.contentView = NSHostingView(rootView:SettingsView(app:self)); w.center(); settingsWindow = w
        }
        settingsWindow?.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps:true)
    }
    @objc func toggle() {
        if !panels.isEmpty { dismiss(); return }
        permission = WindowDriver.trusted
        do { try driver.capture() } catch { message = error.localizedDescription; showSettings(); return }
        if config.resetGrid { currentRows = config.rows; currentColumns = config.columns; currentSubdivision = false }
        settingsWindow?.orderOut(nil)
        for screen in NSScreen.screens {
            let width: CGFloat = min(440,screen.visibleFrame.width-40), height: CGFloat = min(400,screen.visibleFrame.height-40)
            let panel = TilePanel(contentRect:CGRect(x:0,y:0,width:width,height:height),styleMask:[.titled,.nonactivatingPanel,.fullSizeContentView],backing:.buffered,defer:false)
            panel.title = "OpenTile — \(driver.target?.app.localizedName ?? "Window")"; panel.titleVisibility = .hidden
            panel.titlebarAppearsTransparent = true; panel.isFloatingPanel = true; panel.level = .floating
            panel.hidesOnDeactivate = false; panel.isReleasedWhenClosed = false
            panel.collectionBehavior = [.canJoinAllSpaces,.fullScreenAuxiliary]
            panel.setFrameOrigin(CGPoint(x:screen.visibleFrame.midX-width/2,y:screen.visibleFrame.midY-height/2))
            let content = NSView(frame:CGRect(x:0,y:0,width:width,height:height)); panel.contentView = content
            let title = NSTextField(labelWithString:driver.target?.app.localizedName ?? "Window")
            title.font = .systemFont(ofSize:20,weight:.semibold); title.frame = CGRect(x:56,y:height-52,width:width-130,height:28); content.addSubview(title)
            if let icon = driver.target?.app.icon {
                let image = NSImageView(frame:CGRect(x:20,y:height-52,width:28,height:28)); image.image = icon; content.addSubview(image)
            }
            let close = NSButton(title:"×",target:self,action:#selector(dismiss)); close.frame = CGRect(x:8,y:height-26,width:26,height:24); content.addSubview(close)
            let gear = NSButton(title:"⚙",target:self,action:#selector(showSettings)); gear.frame = CGRect(x:width-48,y:height-52,width:34,height:28); content.addSubview(gear)
            let grid = GridView(frame:CGRect(x:20,y:42,width:width-40,height:height-110))
            grid.rows = currentRows; grid.columns = currentColumns; grid.subdivided = currentSubdivision
            grid.onPreview = { [weak self,weak screen] selection in if let screen { self?.showPreview(selection,on:screen) } }
            grid.onSelect = { [weak self,weak screen] selection,shift in if let screen { self?.lastShortcut = nil; _ = self?.place(selection,on:screen,shift:shift) } }
            content.addSubview(grid)
            let help = NSTextField(labelWithString:"Drag cells · ⌥ subdivide · ⌘± rows · ⇧⌘± columns")
            help.font = .systemFont(ofSize:11); help.textColor = .secondaryLabelColor; help.frame = CGRect(x:20,y:12,width:width-40,height:20); content.addSubview(help)
            panel.onKey = { [weak self] event in self?.handle(event) ?? false }
            panel.onFlags = { [weak self] event in
                let option = event.modifierFlags.contains(.option)
                if option && !(self?.optionDown ?? false) { self?.grids.forEach { $0.cancel(); $0.subdivided.toggle() }; self?.currentSubdivision = self?.grids.first?.subdivided ?? false }
                self?.optionDown = option
            }
            panels.append(panel); grids.append(grid)
            panel.alphaValue = config.animations ? 0 : 1; panel.orderFrontRegardless()
            if config.animations { NSAnimationContext.runAnimationGroup { context in context.duration = 0.12; panel.animator().alphaValue = 1 } }
        }
        panels.first?.makeKey(); optionDown = false
    }
    var currentRows = 6, currentColumns = 6
    var optionDown = false
    @objc func dismiss() {
        if !panels.isEmpty {
            UserDefaults.standard.set(currentRows,forKey:"sessionRows"); UserDefaults.standard.set(currentColumns,forKey:"sessionColumns"); UserDefaults.standard.set(currentSubdivision,forKey:"sessionSubdivision")
        }
        panels.forEach { $0.orderOut(nil) }; panels = []; grids = []; previews.forEach { $0.orderOut(nil) }; previews = [] }
    func showPreview(_ selection: GridSelection?, on screen: NSScreen) {
        previews.forEach { $0.orderOut(nil) }; previews = []
        guard config.preview, let selection, let frame = Geometry.frame(for:selection,in:WindowDriver.visibleFrame(screen),margins:config.margins) else { return }
        let panel = NSPanel(contentRect:WindowDriver.cocoaFrame(frame),styleMask:[.borderless,.nonactivatingPanel],backing:.buffered,defer:false)
        panel.backgroundColor = .controlAccentColor.withAlphaComponent(0.22); panel.isOpaque = false
        panel.ignoresMouseEvents = true; panel.level = NSWindow.Level(rawValue:NSWindow.Level.floating.rawValue-1)
        panel.collectionBehavior = [.canJoinAllSpaces,.fullScreenAuxiliary]; panel.orderFrontRegardless(); previews = [panel]
    }
    @discardableResult func handle(_ event: NSEvent) -> Bool {
        if event.keyCode == 53 {
            if grids.contains(where: { $0.anchor != nil }) { grids.forEach { $0.cancel() } } else { dismiss() }; return true
        }
        if event.modifierFlags.contains(.command), [24,27,69,78].contains(Int(event.keyCode)) {
            let change = [24,69].contains(Int(event.keyCode)) ? 1 : -1
            if event.modifierFlags.contains(.shift) { currentColumns = max(1,min(10,currentColumns+change)) }
            else { currentRows = max(1,min(10,currentRows+change)) }
            grids.forEach { $0.cancel(); $0.rows = currentRows; $0.columns = currentColumns }; return true
        }
        let key = binding(for:event)
        if let shortcut = config.shortcuts.first(where: { $0.enabled && !$0.global && $0.binding == key }) { run(shortcut,global:false,shift:false); return true }
        return false
    }
    func run(_ shortcut: Shortcut,global:Bool,shift:Bool = false) {
        do {
            try driver.capture()
            guard var screen = driver.screen() else { throw ConfigError.invalid("No display available.") }
            let sameWindow = lastWindow.map { old in driver.target.map { CFEqual(old,$0.element) } ?? false } ?? false
            let sameFrame = driver.frame().flatMap { current in lastAppliedFrame.map { abs(current.minX-$0.minX)<1 && abs(current.minY-$0.minY)<1 && abs(current.width-$0.width)<1 && abs(current.height-$0.height)<1 } } ?? false
            if config.cycleScreens && (global || config.keepOpen), lastShortcut == shortcut.id, sameWindow, sameFrame,
               let i = NSScreen.screens.firstIndex(of:screen), NSScreen.screens.count > 1 { screen = NSScreen.screens[(i+1)%NSScreen.screens.count] }
            if place(shortcut.selection,on:screen,shift:shift) {
                lastShortcut = shortcut.id; lastWindow = driver.target?.element; lastAppliedFrame = driver.frame()
            }
        } catch { message = error.localizedDescription; showSettings() }
    }
    @discardableResult func place(_ selection: GridSelection,on screen:NSScreen,shift:Bool) -> Bool {
        do {
            try driver.capture()
            guard let frame = Geometry.frame(for:selection,in:WindowDriver.visibleFrame(screen),margins:config.margins) else { throw ConfigError.invalid("Margins leave no room for this selection.") }
            let actual = try driver.apply(frame)
            let constrained = abs(actual.minX-frame.minX)>1 || abs(actual.minY-frame.minY)>1 || abs(actual.width-frame.width)>1 || abs(actual.height-frame.height)>1
            message = constrained ? "The application constrained this window’s size or position." : ""
            if config.keepOpen == shift { dismiss() } else { grids.forEach { $0.cancel() } }
            if constrained { refreshStatus() }; return true
        } catch { message = error.localizedDescription; showSettings(); return false }
    }
    func importDivvy() {
        do {
            let path = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Preferences/com.mizage.Divvy.plist")
            let imported = try DivvyImport.configuration(preferences:Data(contentsOf:path))
            message = "Imported \(imported.shortcuts.count) Divvy shortcuts. Divvy preferences were not modified."
            _ = save(imported); currentRows = imported.rows; currentColumns = imported.columns
        } catch { message = "Import failed: \(error.localizedDescription)" }
    }
    func exportConfiguration() {
        let panel = NSSavePanel(); panel.nameFieldStringValue = "OpenTile.json"; panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted,.sortedKeys]; try encoder.encode(config).write(to:url,options:.atomic); message = "Configuration exported." }
        catch { message = error.localizedDescription }
    }
    func importConfiguration() {
        let panel = NSOpenPanel(); panel.allowedContentTypes = [.json,.propertyList]; panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let data = try Data(contentsOf:url)
            let imported: Configuration
            if url.pathExtension == "json" { imported = try JSONDecoder().decode(Configuration.self,from:data).validated() }
            else { imported = try DivvyImport.configuration(preferences:data) }
            message = "Imported configuration."; _ = save(imported)
        } catch { message = error.localizedDescription }
    }
}
