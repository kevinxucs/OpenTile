# Architecture

`OpenTileCore` is independent of AppKit. It holds Codable configuration, grid geometry, modifier normalization and a restricted binary-plist archive parser. Archive class names are treated as data; no NSKeyedUnarchiver application classes are loaded. Input size, reference depth, object visits and field ranges are bounded.

`OpenTileApp` is a testable native UI library, hosted by the `OpenTile` executable. It uses AppKit for nonactivating per-display panels and mouse selection, SwiftUI for settings, Carbon for system hotkeys, Accessibility for window frames, and SMAppService for login launch. Display rectangles are converted from AppKit's bottom-left coordinates into Accessibility's top-left coordinates before applying a grid selection. Resize, move, resize ordering accommodates applications that constrain movement at the previous size.

Both app bundles declare `LSUIElement=true`; accessory activation policy is applied before the event loop and maintained when showing panels or settings. Launch is quiet. Activation always presents the grid; capture and placement errors remain inside the panel. Settings is an explicit gear/menu action, with a `--settings` launch option. The UI tests inject a failing window driver, so the permission/error path is exercised without reading or moving any external window.

`Assets/AppIcon.png` is the generated transparent icon master. The build resizes it into the standard macOS icon set and packages an `.icns` resource in each app. The original generation prompt is recorded in `Assets/README.md`.

Configuration is written atomically to Application Support/OpenTile/config.json. Saving preserves the previous file as config.backup.json. Grid session dimensions are kept in local user defaults. No network service or telemetry is included.

The fixture is a separate app bundle using the same executable. It owns an empty resizable NSWindow and logs its own frame changes; its logs contain coordinates and display bounds, not user window titles or contents. Diagnostics runs production window placement against that fixture only. Other-window inspection requires an explicit button action and retains the original frame for restoration.

Local builds are ad-hoc signed. Distribution should use a stable Developer ID signing identity and notarization; this repository does not contain signing credentials.
