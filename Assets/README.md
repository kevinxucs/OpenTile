# OpenTile app icon

`AppIcon.png` is the transparent master raster asset. The build generates the standard macOS icon sizes and `OpenTile.icns`, then includes it in both app bundles. The icon remains visible in Finder and app settings while the running app stays out of the Dock.

Created with the built-in image generation tool. Final prompt:

> Use case: logo-brand. Asset type: final macOS application icon for OpenTile, an open-source grid window manager. Create a single polished 1024 by 1024 icon asset, front-facing square composition, not a mockup. A native macOS rounded-square icon tile with a restrained deep blue-gray glass surface. Center a bold, very simple window-tiling symbol: three neatly arranged rounded rectangular window panes, one tall pane on the left and two shorter panes stacked on the right, separated by generous consistent gutters. The left pane is luminous system-accent blue, the other two are pale frosted silver. Subtle beveled edges and soft material lighting, crisp geometry, strong contrast and easy recognition at 16 pixels. Balanced generous padding, symbol fills about 60 percent of icon width. True transparent background outside the rounded-square icon silhouette; tightly controlled shadow. No letters, no words, no text, no watermark, no extra objects, no scene, no hands, no computer hardware. Original icon; do not copy Divvy branding.

The generated master is 1254×1254 with alpha. Build-time resizing uses macOS `sips`; `iconutil` assembles the `.icns` container. The master is kept at its original resolution.
