# Validation

Environment: macOS 27.2 (26B123), Apple Silicon, Xcode 27.2, Swift 6.4.2. One attached display; usable frame in Accessibility points: x=63, y=33, width=1449, height=949.

## Completed

- `./scripts/test.sh`: 12 XCTest cases passed, zero failures. Coverage includes inclusive cell bounds, 2× subdivisions, odd dimensions, negative monitor origins, edge/gap margins, invalid geometry, all grid sizes 1–10 and their subdivisions, binary archive and URL import, truncated archives, modifier normalization, duplicate keys, preference keys/defaults, JSON round trip and invalid configurations.
- `./scripts/build-app.sh`: release app and validation fixture build successfully.
- `codesign --verify --deep --strict build/OpenTile.app`: passed. Local ad-hoc signature only; no Developer ID notarization.
- `plutil -lint build/OpenTile.app/Contents/Info.plist`: passed.
- Native settings, shortcut list and shortcut editor opened and visually inspected. Recorder Escape cancellation preserves the original key. Cancel leaves the imported selection unchanged.
- The actual local Divvy archive imported all 20 shortcuts. An independent Python comparison verified every physical key code, modifier mask, enabled/global flag, row/column bound and subdivision against the original archive. Activation remains Option–Space.
- Permission denial produces an actionable error rather than silently attempting placement.
- Temporary Divvy changes were restored: margins off, persistent panel off, monitor cycling off, preview on, edge margins 10. No shortcut was altered. Divvy may persist explicit values equal to its previous defaults.

## Live acceptance and parity: pending

These are **not** covered by the passing unit tests:

1. Re-enable Accessibility for the current build. macOS invalidates an ad-hoc signed app's grant when its binary changes. Computer Use cannot control System Settings on this host, so the user must do this step.
2. Open `build/OpenTileFixture.app`. In OpenTile → Diagnostics, run **Validate placements on test fixture**. This uses the production Accessibility driver for all saved placements, records expected/actual frames in `~/Library/Application Support/OpenTile/validation.json`, and restores the fixture frame. It verifies driver acceptance, not Divvy parity.
3. Click the fixture physically and apply Divvy Option–Space then E. The fixture records its own actual frame to ignored `.local/fixture.jsonl`. Compare all 20 Divvy placements against OpenTile. The UI tool's targeted inputs do not reliably change the system's foreground app, so attempts to resize the fixture have not yet yielded a measured Divvy frame.
4. Alternatively, with user approval, use the foreground Finder build-folder window. Diagnostics → Inspect active window saves its original frame and measures subsequent frames; Restore inspected window returns it to that frame.
5. Verify rounding and margins against Divvy, then correct any discrepancies. Current arithmetic is provisional until compared with live Divvy results.
6. Exercise actual global/local shortcut delivery, mouse selection, preview, Option subdivision, Command ±, Shift dismissal, global conflicts, CRUD persistence, login registration and configuration export/import.
7. Validate physical multiple-display cycling, full-screen Spaces, minimum-size constraints and nonstandard apps on suitable systems. No second display or Office-specific Automation compatibility has been validated here.

Do not describe this prerelease as exact-placement compatible or fully validated until these live checks pass.
