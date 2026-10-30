import AppKit
import Carbon
import OpenTileCore

func binding(for event: NSEvent) -> KeyBinding {
    KeyBinding(keyCode: UInt32(event.keyCode), modifiers: KeyBinding.normalize(UInt32(event.modifierFlags.rawValue)))
}
func keyLabel(_ key: KeyBinding) -> String {
    let names: [UInt32:String] = [0:"A",1:"S",2:"D",3:"F",4:"H",5:"G",6:"Z",7:"X",8:"C",9:"V",11:"B",12:"Q",13:"W",14:"E",15:"R",16:"Y",17:"T",18:"1",19:"2",20:"3",21:"4",22:"6",23:"5",24:"=",25:"9",26:"7",27:"−",28:"8",29:"0",30:"]",31:"O",32:"U",33:"[",34:"I",35:"P",37:"L",38:"J",39:"'",40:"K",41:";",42:"\\",43:",",44:"/",45:"N",46:"M",47:".",48:"Tab",49:"Space",50:"`",51:"Delete",53:"Esc",123:"←",124:"→",125:"↓",126:"↑"]
    return (key.modifiers & 4096 != 0 ? "⌃" : "") + (key.modifiers & 2048 != 0 ? "⌥" : "") + (key.modifiers & 512 != 0 ? "⇧" : "") + (key.modifiers & 256 != 0 ? "⌘" : "") + (names[key.keyCode] ?? "Key \(key.keyCode)")
}

final class Hotkeys {
    var refs: [EventHotKeyRef] = []
    var handler: EventHandlerRef?
    var actions: [UInt32: () -> Void] = [:]
    init() {
        var type = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
            guard let event, let context else { return OSStatus(eventNotHandledErr) }
            var id = EventHotKeyID()
            guard GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &id) == noErr else { return OSStatus(eventNotHandledErr) }
            let owner = Unmanaged<Hotkeys>.fromOpaque(context).takeUnretainedValue()
            owner.actions[id.id]?(); return noErr
        }, 1, &type, Unmanaged.passUnretained(self).toOpaque(), &handler)
    }
    func clear() { refs.forEach { UnregisterEventHotKey($0) }; refs = []; actions = [:] }
    func register(_ key: KeyBinding, action: @escaping () -> Void) -> Bool {
        let id = UInt32(actions.count+1)
        var ref: EventHotKeyRef?
        let result = RegisterEventHotKey(key.keyCode, key.modifiers, EventHotKeyID(signature: 0x4F54494C, id: id), GetApplicationEventTarget(), 0, &ref)
        guard result == noErr, let ref else { return false }
        refs.append(ref); actions[id] = action; return true
    }
    deinit { clear(); if let handler { RemoveEventHandler(handler) } }
}
