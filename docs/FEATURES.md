# Divvy compatibility research

Sources, accessed 2026-10-30:
- https://mizage.com/help/divvy/user_guide.html
- https://mizage.com/help/divvy/export_import.html
- https://mizage.com/help/accessibility.html

Documented features: background app; menu/global activation; per-screen centered grids; rectangular mouse selection and preview; Escape cancellation; Shift reverses dismissal; 1–10 rows/columns; Option subdivision to 20; Command +/- changes rows, Shift-Command +/- columns; named enabled local/global shortcuts with independent grids; repeat shortcut screen cycling; login launch; menu visibility; persistent panel; configurable activation; animation; preview; reset grid on activation; four screen margins and horizontal/vertical gaps (0–300).

Proprietary update checking is replaced by repository/release links; no Mizage update service or artwork is copied. Generic AX-compatible windows are supported; app-specific Automation workarounds require separate validation.

Local inspection: installed Divvy 1.5.2 (590), Option–Space, 9×9, animations off, margins off, 20 local shortcuts. Two shortcuts use 18×18 effective coordinates despite base 9×9. Names do not reliably describe geometry, so import preserves archived coordinates verbatim. User preference data stays outside Git.

Archive: NSKeyedArchiver plist root array of Shortcut dictionaries. Inclusive cell endpoints; `subdivided` doubles both dimensions. `keyComboCode` is physical macOS key code; flags are normalized from Cocoa or Carbon masks. Only property list primitives are decoded.

Undocumented items needing live comparison: fractional rounding, usable screen frame, margins arithmetic, app constraints, monitor order and repetition state.
