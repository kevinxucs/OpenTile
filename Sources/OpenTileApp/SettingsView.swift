import SwiftUI
import AppKit
import ServiceManagement
import UniformTypeIdentifiers
import OpenTileCore

struct SettingsView: View {
    @ObservedObject var app: AppController
    @State private var draft: Configuration
    @State private var editor: Shortcut?
    @State private var importURL = ""
    @State private var login = SMAppService.mainApp.status == .enabled
    init(app: AppController) { self.app = app; _draft = State(initialValue:app.config) }
    var body: some View {
        VStack(spacing:12) {
            HStack {
                Image(nsImage:NSApp.applicationIconImage).resizable().scaledToFit().frame(width:48,height:48)
                VStack(alignment:.leading) { Text("OpenTile").font(.title.bold()); Text("Native grid window management").foregroundStyle(.secondary) }
                Spacer()
                Text(app.permission ? "Accessibility ready" : "Accessibility required").foregroundStyle(app.permission ? .green : .orange)
            }
            TabView {
                general.tabItem { Text("General") }
                appearance.tabItem { Text("Grid & Margins") }
                shortcuts.tabItem { Text("Shortcuts") }
                migration.tabItem { Text("Import & Export") }
                diagnostics.tabItem { Text("Diagnostics") }
            }
            Text(app.message).font(.callout).foregroundStyle(.secondary).frame(maxWidth:.infinity,alignment:.leading).lineLimit(4).frame(minHeight:45)
            HStack {
                Button("Grant Accessibility…") { WindowDriver.requestPermission(); app.permission = WindowDriver.trusted }
                Button("Refresh permission") { app.permission = WindowDriver.trusted }
                Spacer()
                Button("Quit") { app.quit() }
                Button("Save") { app.message = ""; if app.save(draft) { draft = app.config } }.keyboardShortcut("s",modifiers:.command)
            }
        }.padding(20).frame(minWidth:720,minHeight:660)
        .onChange(of:app.config) { value in draft = value }
        .sheet(item:$editor) { shortcut in ShortcutEditor(shortcut:shortcut) { edited in
            if let index = draft.shortcuts.firstIndex(where: { $0.id == edited.id }) { draft.shortcuts[index] = edited }
            else { draft.shortcuts.append(edited) }
            editor = nil
        } cancel: { editor = nil } }
    }
    var general: some View {
        Form {
            Toggle("Show menu bar icon",isOn:$draft.showMenuIcon)
            Toggle("Keep panel open until dismissed",isOn:$draft.keepOpen)
            Toggle("Cycle screens when repeating a shortcut",isOn:$draft.cycleScreens)
            Toggle("Use global shortcut to display panel",isOn:$draft.activationEnabled)
            HStack { Text("Activation shortcut"); KeyRecorder(value:$draft.activation).frame(width:230,height:30) }
            Toggle("Start OpenTile at login",isOn:$login).onChange(of:login) { enabled in
                do { if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() } }
                catch { app.message = error.localizedDescription; login = SMAppService.mainApp.status == .enabled }
            }
            Text("Quit Divvy before using shared global shortcuts. Local shortcuts run only while the grid is open. Reopen OpenTile to reach its panel when the menu icon is hidden.").font(.callout).foregroundStyle(.secondary)
            Text("OpenTile 0.1.0 · MIT license · Independent of Mizage\nNo telemetry. Updates are manual in this local repository build.").font(.callout).foregroundStyle(.secondary)
        }.formStyle(.grouped)
    }
    var appearance: some View {
        Form {
            Toggle("Animate interface",isOn:$draft.animations)
            Toggle("Show resize preview",isOn:$draft.preview)
            Toggle("Reset grid to these settings on activation",isOn:$draft.resetGrid)
            HStack { Stepper("Rows: \(draft.rows)",value:$draft.rows,in:1...10); Stepper("Columns: \(draft.columns)",value:$draft.columns,in:1...10) }
            Toggle("Enable margins",isOn:$draft.margins.enabled)
            Group {
                HStack { margin("Left",value:$draft.margins.left); margin("Right",value:$draft.margins.right) }
                HStack { margin("Top",value:$draft.margins.top); margin("Bottom",value:$draft.margins.bottom) }
                HStack { margin("Horizontal gap",value:$draft.margins.horizontal); margin("Vertical gap",value:$draft.margins.vertical) }
            }.disabled(!draft.margins.enabled)
            Text("Drag a rectangle on the grid. Option toggles half-cell subdivision. Command ± changes rows; Shift–Command ± changes columns. Hold Shift during a drag to reverse automatic dismissal.").font(.callout).foregroundStyle(.secondary)
        }.formStyle(.grouped)
    }
    func margin(_ name:String,value:Binding<Double>) -> some View {
        HStack { Text(name).frame(width:105,alignment:.leading); TextField(name,value:value,format:.number).frame(width:65); Stepper("",value:value,in:0...300,step:1).labelsHidden() }
    }
    var shortcuts: some View {
        VStack {
            List {
                ForEach(draft.shortcuts) { shortcut in
                    HStack {
                        Toggle("",isOn:Binding(get:{ draft.shortcuts.first(where:{$0.id == shortcut.id})?.enabled ?? false },set:{ value in if let i = draft.shortcuts.firstIndex(where:{$0.id == shortcut.id}) { draft.shortcuts[i].enabled = value } })).labelsHidden()
                        VStack(alignment:.leading) { Text(shortcut.name.isEmpty ? "Untitled" : shortcut.name); Text("\(shortcut.selection.effectiveColumns)×\(shortcut.selection.effectiveRows) · \(shortcut.global ? "Global" : "Panel only")").font(.caption).foregroundStyle(.secondary) }
                        Spacer(); Text(keyLabel(shortcut.binding)).monospaced()
                        Button("Edit") { editor = shortcut }
                        Button(role:.destructive) { draft.shortcuts.removeAll { $0.id == shortcut.id } } label: { Image(systemName:"trash") }
                    }.padding(.vertical,3).onTapGesture(count:2) { editor = shortcut }
                }
            }
            HStack { Button("New Shortcut") { editor = Shortcut(name:"",binding:KeyBinding(keyCode:0),selection:GridSelection(rows:draft.rows,columns:draft.columns,endRow:draft.rows-1,endColumn:draft.columns-1)) }.keyboardShortcut("n",modifiers:.command); Spacer(); Text("\(draft.shortcuts.count) shortcuts · Save applies changes").foregroundStyle(.secondary) }
        }.padding(12)
    }
    var diagnostics: some View {
        Form {
            Text("Live placement checks")
            Text("Open OpenTileFixture.app from the build folder. This empty test window records its frame locally. The acceptance check applies each saved placement through OpenTile’s real window driver, verifies it, and restores the original frame.").font(.callout).foregroundStyle(.secondary)
            Button("Validate placements on test fixture") { app.validateFixture() }
            Text("Compare another window")
            Text("Inspect saves the focused window’s current frame. After a Divvy placement, inspect again to measure the result. Restore returns the first inspected window to its original frame. Reports contain coordinates only.").font(.callout).foregroundStyle(.secondary)
            HStack { Button("Inspect active window") { app.inspectActiveWindow() }; Button("Restore inspected window") { app.restoreObservedWindow() } }
        }.formStyle(.grouped)
    }

    var migration: some View {
        Form {
            Text("Import preserves physical key codes and exact saved cell coordinates, including half-cell subdivisions. Import replaces OpenTile’s saved configuration. Export first to keep a backup.")
            Button("Import local Divvy preferences") { app.importDivvy() }
            HStack { Button("Import file…") { app.importConfiguration() }; Button("Export OpenTile JSON…") { app.exportConfiguration() } }
            TextField("Paste divvy://import/… URL",text:$importURL)
            Button("Import Divvy shortcut URL") {
                do { var c = app.config; c.shortcuts = try DivvyImport.importURL(importURL); app.message = "Imported \(c.shortcuts.count) shortcuts."; _ = app.save(c) }
                catch { app.message = error.localizedDescription }
            }
            Text("Configuration: \(app.configURL.path)").font(.caption).textSelection(.enabled)
            Text("Divvy preferences are read only. No credentials, licensing data, or vendor artwork are imported.").font(.callout).foregroundStyle(.secondary)
        }.formStyle(.grouped)
    }
}

struct ShortcutEditor: View {
    @State var shortcut: Shortcut
    let accept: (Shortcut)->Void
    let cancel: ()->Void
    var body: some View {
        VStack(spacing:16) {
            Text("Shortcut").font(.title2.bold())
            HStack { TextField("Name",text:$shortcut.name); KeyRecorder(value:$shortcut.binding).frame(width:200,height:30) }
            HStack {
                Stepper("Rows: \(shortcut.selection.rows)",value:$shortcut.selection.rows,in:1...10)
                Stepper("Columns: \(shortcut.selection.columns)",value:$shortcut.selection.columns,in:1...10)
                Toggle("Subdivide",isOn:$shortcut.selection.subdivided)
            }
            EditorGrid(selection:$shortcut.selection).frame(height:280)
            Text("Drag to select placement. \(shortcut.selection.startColumn),\(shortcut.selection.startRow) → \(shortcut.selection.endColumn),\(shortcut.selection.endRow) (inclusive)").font(.caption).foregroundStyle(.secondary)
            HStack { Toggle("Enabled",isOn:$shortcut.enabled); Toggle("Global shortcut",isOn:$shortcut.global) }
            if shortcut.global && shortcut.binding.modifiers == 0 { Text("Global shortcuts require a modifier.").foregroundStyle(.red) }
            if !shortcut.selection.isValid { Text("Select cells within the new grid dimensions.").foregroundStyle(.red) }
            HStack { Button("Cancel",action:cancel).keyboardShortcut(.cancelAction); Spacer(); Button("Accept") { accept(shortcut) }.disabled(!shortcut.selection.isValid || (shortcut.global && shortcut.binding.modifiers == 0)) }
        }.padding(24).frame(width:590)
    }
}

struct EditorGrid: NSViewRepresentable {
    @Binding var selection: GridSelection
    func makeNSView(context:Context)->GridView { let view = GridView(); updateNSView(view,context:context); return view }
    func updateNSView(_ view:GridView,context:Context) {
        view.rows = selection.rows; view.columns = selection.columns; view.subdivided = selection.subdivided; view.selection = selection
        view.onSelect = { value,_ in selection = value }
    }
}

struct KeyRecorder: NSViewRepresentable {
    @Binding var value: KeyBinding
    func makeNSView(context:Context)->RecorderButton { let button = RecorderButton(); button.target = button; button.action = #selector(RecorderButton.record); return button }
    func updateNSView(_ button:RecorderButton,context:Context) { if !button.recording { button.title = keyLabel(value) }; button.originalTitle = keyLabel(value); button.changed = { value = $0 } }
}
final class RecorderButton: NSButton {
    var recording = false
    var originalTitle = ""
    var changed: ((KeyBinding)->Void)?
    override var acceptsFirstResponder: Bool { true }
    @objc func record() { recording = true; title = "Press shortcut… (Esc cancels)"; window?.makeFirstResponder(self) }
    override func keyDown(with event:NSEvent) {
        guard recording else { super.keyDown(with:event); return }
        recording = false
        if event.keyCode != 53 { let key = binding(for:event); changed?(key); title = keyLabel(key) }
        else { title = originalTitle }
        window?.makeFirstResponder(nil)
    }
    override func resignFirstResponder() -> Bool {
        if recording { recording = false; title = originalTitle }
        return super.resignFirstResponder()
    }
    override func performKeyEquivalent(with event:NSEvent)->Bool { if recording { keyDown(with:event); return true }; return super.performKeyEquivalent(with:event) }
}
