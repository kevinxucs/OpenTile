# Implementation plan

1. Repository scaffold, feature inventory and acceptance criteria.
2. Pure Swift geometry/configuration/import core with deterministic tests. Parse legacy archives without object instantiation; preserve physical keys and subdivisions.
3. Native AppKit application: nonactivating panels on displays, mouse grid, keyboard selection, preview, Accessibility window driver, Carbon global shortcuts, settings and shortcut editor, persistence, login service and import/export.
4. Build an instrumented resizable window fixture. Measure Divvy placements, compare every imported shortcut, and fix geometry discrepancies. Exercise activation, dismissal, settings, migration and error handling.
5. Record tests and live evidence, package a runnable local app, and commit focused chunks.

## Acceptance

- Every local shortcut imports and retains geometry and key binding.
- Geometry covers visible frames, negative origins, subdivision, margins and fractional bounds.
- Move/resize reports denied permission, unavailable/unsupported windows, conflicts and app constraints honestly.
- Build and tests pass; live results identify untested displays/apps explicitly.
- No personal preferences, binaries, proprietary code or artwork in Git.
