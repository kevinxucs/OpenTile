# OpenTile

<img src="Assets/AppIcon.png" alt="OpenTile app icon" width="96" height="96">

A native, open-source macOS grid window manager with Divvy shortcut migration.

**Prerelease:** builds and unit tests pass. Exact placement parity and live system behavior still need validation; see [validation results](docs/VALIDATION.md).

## Features

- Per-display grids, rectangular mouse selection, preview and half-cell subdivision.
- Configurable rows/columns, screen margins and window gaps.
- Named local and global shortcuts, physical key recording, enable/disable and conflict checks.
- Option–Space activation, persistent panels, Shift dismissal reversal and repeated-shortcut screen cycling.
- Local Divvy preference/archive import, Divvy import URLs and JSON import/export.
- Menu visibility, interface animation, saved grid state and login launch.
- Background operation without a Dock icon; activation opens the tile grid directly.
- Accessibility errors, app constraint reporting and a dedicated validation fixture.

macOS 13+, Swift 6, no third-party dependencies. Independent project, not affiliated with Mizage. No Divvy code or artwork is included.

## Build and run

```sh
./scripts/test.sh
./scripts/build-app.sh
open build/OpenTile.app
```

Enable OpenTile in **System Settings → Privacy & Security → Accessibility**. Local ad-hoc rebuilds may require toggling that permission again. Quit Divvy before using overlapping global shortcuts, then open the grid's gear → **Import & Export → Import local Divvy preferences**. Imports replace OpenTile's saved configuration; export first to keep a separate backup. Divvy's preferences are read only.

OpenTile launches in the background. Option–Space opens the tile grid, including when Accessibility permission is missing; a message inside the grid explains how to enable window control. Settings opens through the gear or menu item. For a direct settings launch, use `open build/OpenTile.app --args --settings`. Both OpenTile and its validation fixture stay out of the Dock.

Configuration and its previous-save backup live in `~/Library/Application Support/OpenTile/`. Personal shortcuts, logs and binaries are excluded from Git.

## Controls

| Action | Control |
| --- | --- |
| Show or dismiss grid | Configurable activation shortcut; imported Option–Space is preserved |
| Place window | Drag a rectangular group of cells, or press a saved local shortcut |
| Cancel drag / dismiss | Escape |
| Reverse automatic dismissal | Hold Shift during drag |
| Toggle half-cell subdivision | Option |
| Add/remove rows | Command + / − |
| Add/remove columns | Shift–Command + / − |

Use Settings to create/edit/delete shortcuts and record global combinations. Global combinations require a modifier. Reopen the app to access its panel when the menu icon is hidden.

## Development

```sh
./scripts/test.sh
./scripts/build-app.sh
open build/OpenTileFixture.app
```

The Diagnostics tab runs live placements on the empty fixture and writes a local report. Live tests require Accessibility; unit tests do not. See [research](docs/FEATURES.md), [plan](docs/PLAN.md), [architecture](docs/ARCHITECTURE.md), and [contribution guide](CONTRIBUTING.md).

Source: [kevinxucs/OpenTile](https://github.com/kevinxucs/OpenTile). Updates are manual. Generic Accessibility-compatible windows are the initial target; app-specific Automation workarounds remain unvalidated.

MIT licensed. Divvy is its owner's trademark.
