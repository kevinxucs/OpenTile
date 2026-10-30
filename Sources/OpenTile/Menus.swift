import AppKit

func installMenus(_ delegate: AppController) {
    let main = NSMenu()
    let applicationItem = NSMenuItem()
    let applicationMenu = NSMenu(title:"OpenTile")
    let settings = NSMenuItem(title:"Settings…",action:#selector(AppController.showSettings),keyEquivalent:","); settings.target = delegate
    applicationMenu.addItem(settings)
    applicationMenu.addItem(.separator())
    applicationMenu.addItem(withTitle:"Quit",action:#selector(NSApplication.terminate(_:)),keyEquivalent:"q")
    applicationItem.submenu = applicationMenu; main.addItem(applicationItem)
    let edit = NSMenuItem(); let editMenu = NSMenu(title:"Edit")
    editMenu.addItem(withTitle:"Undo",action:Selector(("undo:")),keyEquivalent:"z")
    editMenu.addItem(withTitle:"Redo",action:Selector(("redo:")),keyEquivalent:"Z")
    editMenu.addItem(.separator())
    editMenu.addItem(withTitle:"Cut",action:#selector(NSText.cut(_:)),keyEquivalent:"x")
    editMenu.addItem(withTitle:"Copy",action:#selector(NSText.copy(_:)),keyEquivalent:"c")
    editMenu.addItem(withTitle:"Paste",action:#selector(NSText.paste(_:)),keyEquivalent:"v")
    editMenu.addItem(withTitle:"Select All",action:#selector(NSText.selectAll(_:)),keyEquivalent:"a")
    edit.submenu = editMenu; main.addItem(edit); NSApp.mainMenu = main
}
